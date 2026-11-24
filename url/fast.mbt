///|
/// Holds the conservative fast-path punctuation exclusions, allocated once.
#cfg(any(target="native", target="wasm"))
let simple_rejected : Array[UInt16] = [34, 39, 60, 62, 92, 94, 96, 123, 125]

///|
/// Rejects characters requiring normalization before attempting the canonical URL fast path.
fn simple_ascii(input : StringView, simd : Bool) -> Bool {
  // Windows measurements favor the scalar guard on 20/60-character URLs;
  // vector setup amortizes on the longer buffers. Keep short requests scalar.
  if simd && input.length() >= 64 {
    simple_ascii_wide(input)
  } else {
    simple_ascii_scalar(input)
  }
}

///|
/// Checks the fast path's conservative ASCII allowlist one UTF-16 code unit at a time.
fn simple_ascii_scalar(input : StringView) -> Bool {
  input
  .code_units()
  .iter()
  .all(c => {
    c > 32 &&
    c < 127 &&
    c != 34 &&
    c != 39 &&
    c != 60 &&
    c != 62 &&
    c != 92 &&
    c != 94 &&
    c != 96 &&
    c != 123 &&
    c != 125
  })
}

///|
/// Checks eight UTF-16 code units in each length-validated V128 string load.
#cfg(any(target="native", target="wasm"))
fn simple_ascii_wide(input : StringView) -> Bool {
  let mut i = 0
  while i + 7 < input.length() {
    // The checked length stays inside this StringView even when its start
    // offset is unaligned or its backing string contains bytes after the view.
    let word = @simd.v128_load_i16x8(input.data(), input.start_offset() + i)
    let mut bad = @simd.v128_or_(
      @simd.i16x8_le_u(word, @simd.i16x8_splat(32)),
      @simd.i16x8_ge_u(word, @simd.i16x8_splat(127)),
    )
    for c in simple_rejected {
      bad = @simd.v128_or_(bad, @simd.i16x8_eq(word, @simd.i16x8_splat(c)))
    }
    if @simd.i16x8_bitmask(bad) != 0 {
      return false
    }
    i += 8
  }
  simple_ascii_scalar(input[i:])
}

///|
/// Retains the scalar ASCII guard where V128 lowering is not supported.
#cfg(any(target="wasm-gc", target="js"))
fn simple_ascii_wide(input : StringView) -> Bool {
  simple_ascii_scalar(input)
}

///|
/// Builds a compact URL directly for Ada's already-canonical special-scheme subset.
fn parse_simple_absolute(input : StringView, simd : Bool) -> Url? {
  let (scheme, start) = if input.has_prefix("https://") {
    ("https", 8)
  } else if input.has_prefix("http://") {
    ("http", 7)
  } else if input.has_prefix("wss://") {
    ("wss", 6)
  } else if input.has_prefix("ws://") {
    ("ws", 5)
  } else if input.has_prefix("ftp://") {
    ("ftp", 6)
  } else {
    return None
  }
  if !simple_ascii(input, simd) || start >= input.length() {
    return None
  }
  let mut host_end = start
  while host_end < input.length() {
    let c = input[host_end]
    if c == 47 || c == 63 || c == 35 {
      break
    }
    if !((c >= 97 && c <= 122) ||
      (c >= 48 && c <= 57) ||
      c == 46 ||
      c == 45 ||
      c == 95) {
      return None
    }
    host_end += 1
  }
  if host_end == start {
    return None
  }
  let host = input[start:host_end]
  let body = host.strip_suffix(".").unwrap_or(host)
  let last = body.rev_split_once(".").map(pair => pair.1).unwrap_or(body)
  // Numeric final labels need IPv4 interpretation, including overflowing hex.
  if !last.is_empty() && last[0] >= 48 && last[0] <= 57 {
    return None
  }
  let hash_at = input[host_end:]
    .find("#")
    .map(at => host_end + at)
    .unwrap_or(input.length())
  let question = input[host_end:hash_at].find("?").map(at => host_end + at)
  let path_end = question.unwrap_or(hash_at)
  let mut segment = host_end + 1
  for i in (host_end + 1)..<=path_end {
    if i < path_end && input[i] == 37 {
      return None
    }
    if i == path_end || input[i] == 47 {
      let length = i - segment
      if (length == 1 && input[segment] == 46) ||
        (length == 2 && input[segment] == 46 && input[segment + 1] == 46) {
        return None
      }
      segment = i + 1
    }
  }
  let missing_slash = path_end == host_end
  let shift = if missing_slash { 1 } else { 0 }
  let text = if missing_slash {
    input[:host_end].to_owned() + "/" + input[host_end:].to_owned()
  } else {
    input.to_owned()
  }
  Some({
    text,
    positions: {
      protocol_end: start - 2,
      username_start: start,
      username_end: start,
      password_start: start,
      password_end: start,
      hostname_start: start,
      hostname_end: host_end,
      port_start: host_end,
      path_start: host_end,
      path_end: path_end + shift,
      query_start: question.map(at => at + 1).unwrap_or(path_end) + shift,
      query_end: hash_at + shift,
      fragment_start: if hash_at < input.length() {
        hash_at + 1 + shift
      } else {
        text.length()
      },
    },
    scheme,
    opaque_path: false,
    port_number: None,
    host_present: true,
    query_present: question is Some(_),
    fragment_present: hash_at < input.length(),
  })
}
