///|
/// Parses a WHATWG IPv4 number in decimal, octal, or hexadecimal with checked bounds.
fn ipv4_number(input : BytesView) -> UInt64? {
  let (digits, radix) = if input.length() >= 2 &&
    input[0] == b'0' &&
    (input[1] == b'x' || input[1] == b'X') {
    (input[2:], 16UL)
  } else if input.length() >= 2 && input[0] == b'0' {
    (input[1:], 8UL)
  } else {
    (input, 10UL)
  }
  let mut value = 0UL
  for byte in digits {
    let digit = hex_value(byte)
    if digit < 0 || digit.to_uint64() >= radix {
      return None
    }
    // No component can contribute more than 32 address bits.
    value = value * radix + digit.to_uint64()
    if value > 0xFFFFFFFFUL {
      return None
    }
  }
  Some(value)
}

///|
/// Recognizes hosts whose last label requires the IPv4 parser even when invalid.
fn ends_in_number(domain : String) -> Bool {
  let body = if domain.has_suffix(".") {
    domain[:domain.length() - 1]
  } else {
    domain[:]
  }
  let last = body.rev_split_once(".").map(pair => pair.1).unwrap_or(body)
  if last.is_empty() {
    return false
  }
  let bytes = @utf8.encode(last)
  bytes.iter().all(c => c >= b'0' && c <= b'9') ||
  (bytes.has_prefix(b"0x") && bytes[2:].iter().all(c => hex_value(c) >= 0))
}

///|
/// Canonicalizes one to four WHATWG IPv4 parts into dotted decimal.
fn parse_ipv4(domain : String) -> String raise ParseError {
  let body = if domain.has_suffix(".") {
    domain[:domain.length() - 1]
  } else {
    domain[:]
  }
  let parts = body.split(".").to_array()
  if parts.length() > 4 || parts.is_empty() {
    return invalid("IPv4 part count")
  }
  let numbers : Array[UInt64] = []
  for part in parts {
    if part.is_empty() {
      return invalid("Empty IPv4 part")
    }
    guard ipv4_number(@utf8.encode(part)) is Some(value) else {
      return invalid("Invalid IPv4 number")
    }
    numbers.push(value)
  }
  let last = numbers.length() - 1
  for i in 0..<last {
    if numbers[i] > 255 {
      return invalid("IPv4 octet out of range")
    }
  }
  if numbers[last] >= 1UL << (8 * (5 - numbers.length())) {
    return invalid("IPv4 final part out of range")
  }
  let mut address = numbers[last]
  for i in 0..<last {
    address += numbers[i] << (8 * (3 - i))
  }
  "\{(address >> 24) & 255}.\{(address >> 16) & 255}.\{(address >> 8) & 255}.\{address & 255}"
}
