///|
/// Parses and normalizes a WHATWG URL, optionally resolving it against `base`.
///
/// Input is a MoonBit UTF-16 string view and is converted to UTF-8 using scalar
/// replacement for unpaired surrogates. Leading/trailing C0 space and embedded
/// tabs/newlines follow WHATWG preprocessing. Hosts, ports, dot segments, and
/// percent encoding are normalized; invalid hosts, ports, or missing bases raise
/// ParseError. The base is never modified. `simd=true` requests checked vector
/// character scans on native/Wasm with identical scalar fallbacks elsewhere.
///
/// ```mbt check
/// test {
///   let url = @url.parse("HTTPS://Example.COM:443/a/../b?q=hello world")
///   assert_eq(url.href(), "https://example.com/b?q=hello%20world")
///   let next = @url.parse("../c", base=url)
///   assert_eq(next.href(), "https://example.com/c")
/// }
/// ```
pub fn parse(
  input : StringView,
  base? : Url,
  simd~ : Bool = true,
) -> Url raise ParseError {
  if parse_simple_absolute(input, simd) is Some(value) {
    return value
  }
  freeze(parse_record(prepare_input(input, simd), base, simd))
}

///|
/// Returns a normalized URL or None when parsing fails, without changing `base`.
/// Uses the same preprocessing and backend selection as `parse`; no validation
/// diagnostics escape. Empty input requires a non-opaque base URL.
pub fn try_parse(input : StringView, base? : Url, simd~ : Bool = true) -> Url? {
  Some(parse(input, base?, simd~)) catch {
    _ => None
  }
}

///|
/// Reports whether input parses successfully with the supplied optional base.
/// This is a validation convenience and currently performs full normalization.
/// The base is not mutated, and all ParseError failures become false.
pub fn can_parse(input : StringView, base? : Url, simd~ : Bool = true) -> Bool {
  try_parse(input, base?, simd~) is Some(_)
}

///|
/// Parses a preprocessed UTF-8 view into independently editable components.
fn parse_record(
  input : BytesView,
  base : Url?,
  simd : Bool,
) -> Record raise ParseError {
  let hash = input.find(b"#")
  let body = if hash is Some(at) { input[:at] } else { input }
  let fragment = hash.map(at => encode_bytes(input[at + 1:], Fragment))
  let record = if scheme_end(body) is Some(at) {
    let scheme = lower_ascii(body[:at])
    let rest = body[at + 1:]
    if scheme == "file" {
      parse_file(rest, base, simd)
    } else if is_special_scheme(scheme) {
      if base is Some(previous) && previous.scheme == scheme {
        parse_relative(rest, previous, simd)
      } else {
        let record = Record::new(scheme)
        parse_special_authority(rest, record, simd)
        record
      }
    } else {
      let record = Record::new(scheme)
      if rest.has_prefix(b"//") {
        parse_authority_suffix(rest[2:], record, simd)
      } else if rest.has_prefix(b"/") {
        parse_suffix(rest, record, true)
      } else {
        record.opaque_path = true
        let question = rest.find(b"?")
        let path = if question is Some(at) { rest[:at] } else { rest }
        record.path = encode_bytes(path, Control)
        // The current WHATWG opaque-path state encodes its final space.
        if record.path.has_suffix(" ") {
          record.path = record.path[:record.path.length() - 1].to_owned() +
            "%20"
        }
        record.query = question.map(at => encode_bytes(rest[at + 1:], Query))
      }
      record
    }
  } else {
    guard base is Some(previous) else {
      return invalid("Relative URL requires a base")
    }
    if previous.opaque_path {
      if !body.is_empty() || fragment is None {
        return invalid("Opaque base only permits fragments")
      }
      previous.record()
    } else if previous.scheme == "file" {
      parse_file(body, base, simd)
    } else {
      parse_relative(body, previous, simd)
    }
  }
  record.fragment = fragment
  record
}

///|
/// Parses a special URL's authority after ignoring optional slash/backslash prefixes.
fn parse_special_authority(
  input : BytesView,
  record : Record,
  simd : Bool,
) -> Unit raise ParseError {
  let mut i = 0
  while i < input.length() && (input[i] == b'/' || input[i] == b'\\') {
    i += 1
  }
  parse_authority_suffix(input[i:], record, simd)
}

///|
/// Parses an authority and its remaining path/query without copying the input spans.
fn parse_authority_suffix(
  input : BytesView,
  record : Record,
  simd : Bool,
) -> Unit raise ParseError {
  let at = authority_end(input, is_special_scheme(record.scheme), simd)
  parse_authority(input[:at], record)
  let rest = input[at:]
  if !is_special_scheme(record.scheme) && (rest.is_empty() || rest[0] == b'?') {
    record.path = ""
    record.query = if rest.is_empty() {
      None
    } else {
      Some(encode_bytes(rest[1:], Query))
    }
  } else {
    parse_suffix(rest, record, true)
  }
}

///|
/// Parses user information, host, and port according to special/opaque host rules.
fn parse_authority(input : BytesView, record : Record) -> Unit raise ParseError {
  let special = is_special_scheme(record.scheme)
  let mut host_input = input
  if input.rev_find(b"@") is Some(at) {
    let userinfo = input[:at]
    if userinfo.find(b":") is Some(colon) {
      record.username = encode_bytes(userinfo[:colon], Userinfo)
      record.password = encode_bytes(userinfo[colon + 1:], Userinfo)
    } else {
      record.username = encode_bytes(userinfo, Userinfo)
    }
    host_input = input[at + 1:]
    if host_input.is_empty() {
      return invalid("Missing host after credentials")
    }
  }
  let colon = if host_input.has_prefix(b"[") {
    guard host_input.find(b"]") is Some(end) else {
      return invalid("Unclosed IPv6 host")
    }
    if end + 1 < host_input.length() {
      if host_input[end + 1] != b':' {
        return invalid("Invalid suffix after IPv6 host")
      }
      Some(end + 1)
    } else {
      None
    }
  } else {
    host_input.find(b":")
  }
  let host = if colon is Some(at) { host_input[:at] } else { host_input }
  if host.is_empty() && (special || colon is Some(_)) {
    return invalid("Missing host")
  }
  record.host = Some(
    if host.is_empty() {
      ""
    } else {
      parse_host(host, special)
    },
  )
  record.port = if colon is Some(at) {
    parse_port(host_input[at + 1:], record.scheme, false)
  } else {
    None
  }
}

///|
/// Resolves a non-file relative reference while keeping the base record independent.
fn parse_relative(
  input : BytesView,
  base : Url,
  simd : Bool,
) -> Record raise ParseError {
  let special = base.is_special()
  let slash = !input.is_empty() &&
    (input[0] == b'/' || (special && input[0] == b'\\'))
  if slash &&
    input.length() > 1 &&
    (input[1] == b'/' || (special && input[1] == b'\\')) {
    let record = Record::new(base.scheme)
    if special {
      parse_special_authority(input, record, simd)
    } else {
      parse_authority_suffix(input[2:], record, simd)
    }
    return record
  }
  let record = base.record()
  record.fragment = None
  if input.is_empty() {
    return record
  }
  if input[0] == b'?' {
    record.query = Some(
      encode_bytes(input[1:], if special { SpecialQuery } else { Query }),
    )
  } else {
    if !slash {
      record.path = shorten(record.path, false)
    }
    parse_suffix(input, record, slash)
  }
  record
}

///|
/// Parses file URLs and relative file references with Windows drive-letter handling.
fn parse_file(
  input : BytesView,
  base : Url?,
  simd : Bool,
) -> Record raise ParseError {
  let record = Record::new("file")
  record.host = Some("")
  let file_base = base.filter(previous => previous.scheme == "file")
  let slash = !input.is_empty() && (input[0] == b'/' || input[0] == b'\\')
  if slash && input.length() > 1 && (input[1] == b'/' || input[1] == b'\\') {
    let rest = input[2:]
    let at = authority_end(rest, true, simd)
    let host = rest[:at]
    if host.length() == 2 &&
      is_alpha(host[0]) &&
      (host[1] == b':' || host[1] == b'|') {
      parse_suffix(rest, record, true)
    } else {
      if !host.is_empty() {
        let parsed = parse_host(host, true)
        record.host = Some(if parsed == "localhost" { "" } else { parsed })
      }
      parse_suffix(rest[at:], record, true)
    }
  } else if slash {
    if file_base is Some(previous) {
      record.host = Some(previous.hostname().to_owned())
      if !starts_drive(input[1:]) &&
        first_drive(previous.pathname().to_owned()) is Some(drive) {
        record.path = "/" + drive
        parse_suffix(input, record, false)
      } else {
        parse_suffix(input, record, true)
      }
    } else {
      parse_suffix(input, record, true)
    }
  } else if file_base is Some(previous) {
    record.host = Some(previous.hostname().to_owned())
    record.path = previous.pathname().to_owned()
    record.query = previous.query().map(view => view.to_owned())
    if !input.is_empty() && input[0] == b'?' {
      record.query = Some(encode_bytes(input[1:], SpecialQuery))
    } else if !input.is_empty() {
      if starts_drive(input) {
        record.path = ""
      } else {
        record.path = shorten(record.path, true)
      }
      parse_suffix(input, record, false)
    }
  } else {
    parse_suffix(input, record, true)
  }
  record
}
