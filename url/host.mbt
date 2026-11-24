///|
/// Tests a byte against the WHATWG forbidden host or forbidden domain code points.
fn forbidden_host(byte : Byte, domain : Bool) -> Bool {
  let c = byte.to_int()
  c == 0 ||
  c == 9 ||
  c == 10 ||
  c == 13 ||
  c == 32 ||
  c == 35 ||
  c == 47 ||
  c == 58 ||
  c == 60 ||
  c == 62 ||
  c == 63 ||
  c == 64 ||
  c == 91 ||
  c == 92 ||
  c == 93 ||
  c == 94 ||
  c == 124 ||
  (domain && (c <= 32 || c == 37 || c == 127 || c > 127))
}

///|
/// Converts a decoded domain using nontransitional UTS #46 with WHATWG flags.
fn ascii_domain(input : BytesView) -> String raise ParseError {
  let ascii = input.iter().all(byte => byte < 128)
  let lowered = if ascii {
    lower_ascii(input)
  } else {
    @utf8.decode_lossy(input, ignore_bom=true)
  }
  // WHATWG beStrict=false returns an ASCII domain lowercased even when an
  // existing ACE label would fail Unicode ToASCII; Ada has this same fast path.
  if ascii {
    if input.iter().any(byte => forbidden_host(byte, true)) {
      return invalid("Forbidden domain code point")
    }
    if lowered.is_empty() {
      return invalid("Empty domain")
    }
    return lowered
  }
  let (prepared, empty_labels) = idna_empty_labels(lowered)
  let output = @idna.to_ascii(
    prepared,
    use_std3_ascii_rules=false,
    check_hyphens=false,
    check_bidi=true,
    check_joiners=true,
    verify_dns_length=false,
  ) catch {
    @idna.EmptyLabel => {
      // Ignored Unicode characters can turn a nonempty raw label into an
      // empty mapped label. Adapt only this uncommon failure, then rerun the
      // whole-domain Bidi check with valid placeholders in those positions.
      let labels = prepared.split(".").map(view => view.to_owned()).to_array()
      for i in 0..<labels.length() {
        try
          @idna.to_ascii(
            labels[i],
            use_std3_ascii_rules=false,
            check_hyphens=false,
            check_bidi=false,
            check_joiners=true,
            verify_dns_length=false,
          )
        catch {
          @idna.EmptyLabel => {
            labels[i] = "a"
            empty_labels.push(i)
          }
          _ => ()
        } noraise {
          _ => ()
        }
      }
      @idna.to_ascii(
        labels.join("."),
        use_std3_ascii_rules=false,
        check_hyphens=false,
        check_bidi=true,
        check_joiners=true,
        verify_dns_length=false,
      ) catch {
        _ => return invalid("IDNA domain-to-ASCII failure")
      }
    }
    _ => return invalid("IDNA domain-to-ASCII failure")
  }
  let output = if empty_labels.is_empty() {
    output
  } else {
    let labels = output.split(".").map(view => view.to_owned()).to_array()
    for at in empty_labels {
      labels[at] = ""
    }
    labels.join(".")
  }
  if output.is_empty() ||
    @utf8.encode(output).iter().any(byte => forbidden_host(byte, true)) {
    return invalid("Forbidden mapped domain code point")
  }
  output
}

///|
/// Adapts WHATWG's allowed empty labels to an IDNA dependency with stricter label syntax.
fn idna_empty_labels(domain : String) -> (String, Array[Int32]) {
  let normalized = domain
    .replace_all(old="\u3002", new=".")
    .replace_all(old="\uFF0E", new=".")
    .replace_all(old="\uFF61", new=".")
  let labels = normalized.split(".").map(view => view.to_owned()).to_array()
  let empty : Array[Int32] = []
  for i in 0..<labels.length() {
    if labels[i].is_empty() {
      labels[i] = "a"
      empty.push(i)
    }
  }
  (labels.join("."), empty)
}

///|
/// Parses a bracketed IP, special domain, or opaque host without reading outside its view.
fn parse_host(input : BytesView, special : Bool) -> String raise ParseError {
  if !input.is_empty() && input[0] == b'[' {
    if input.length() < 2 || input[input.length() - 1] != b']' {
      return invalid("Unclosed IPv6 host")
    }
    return parse_ipv6(input[1:input.length() - 1])
  }
  if !special {
    if input.iter().any(byte => forbidden_host(byte, false)) {
      return invalid("Forbidden opaque host code point")
    }
    return encode_bytes(input, Control)
  }
  let decoded = decode_bytes(input, false)
  let domain = ascii_domain(decoded)
  if ends_in_number(domain) {
    parse_ipv4(domain)
  } else {
    domain
  }
}

///|
/// Parses a decimal port, optionally permitting a trailing nondigit in setter mode.
fn parse_port(
  input : BytesView,
  scheme : String,
  setter : Bool,
) -> Int32? raise ParseError {
  if input.is_empty() {
    return None
  }
  let mut value = 0
  let mut i = 0
  while i < input.length() && input[i] >= b'0' && input[i] <= b'9' {
    value = value * 10 + input[i].to_int() - 48
    if value > 65535 {
      return invalid("Port out of range")
    }
    i += 1
  }
  if i == 0 || (!setter && i != input.length()) {
    return invalid("Invalid port")
  }
  if default_port(scheme) == Some(value) {
    None
  } else {
    Some(value)
  }
}
