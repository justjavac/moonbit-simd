///|
/// Parses a strict dotted-decimal IPv4 tail embedded in an IPv6 address.
fn ipv6_ipv4_tail(input : BytesView) -> (Int32, Int32) raise ParseError {
  let parts = @utf8.decode_lossy(input, ignore_bom=true).split(".").to_array()
  if parts.length() != 4 {
    return invalid("IPv6 IPv4 tail part count")
  }
  let octets : Array[Int32] = []
  for part in parts {
    if part.is_empty() ||
      part.length() > 3 ||
      (part.length() > 1 && part[0] == 48) {
      return invalid("Invalid IPv6 IPv4 tail")
    }
    let mut value = 0
    for c in part.code_units() {
      if c < 48 || c > 57 {
        return invalid("Invalid IPv6 IPv4 digit")
      }
      value = value * 10 + c.to_int() - 48
    }
    if value > 255 {
      return invalid("IPv6 IPv4 octet out of range")
    }
    octets.push(value)
  }
  ((octets[0] << 8) | octets[1], (octets[2] << 8) | octets[3])
}

///|
/// Parses IPv6 with one optional compression run and an optional decimal IPv4 tail.
fn parse_ipv6(input : BytesView) -> String raise ParseError {
  let pieces : Array[Int32] = []
  let mut compressed : Int32? = None
  let mut i = 0
  if !input.is_empty() && input[0] == b':' {
    if input.length() < 2 || input[1] != b':' {
      return invalid("Invalid IPv6 leading colon")
    }
    compressed = Some(0)
    i = 2
  }
  while i < input.length() {
    if pieces.length() == 8 {
      return invalid("Too many IPv6 pieces")
    }
    if input[i] == b':' {
      if compressed is Some(_) {
        return invalid("Multiple IPv6 compression runs")
      }
      compressed = Some(pieces.length())
      i += 1
      continue
    }
    let start = i
    let mut value = 0
    let mut count = 0
    while i < input.length() && hex_value(input[i]) >= 0 && count < 4 {
      value = (value << 4) | hex_value(input[i])
      i += 1
      count += 1
    }
    if i < input.length() && input[i] == b'.' {
      if count == 0 || pieces.length() > 6 {
        return invalid("Invalid IPv6 IPv4 tail position")
      }
      let (a, b) = ipv6_ipv4_tail(input[start:])
      pieces.push(a)
      pieces.push(b)
      i = input.length()
      break
    }
    if count == 0 {
      return invalid("Missing IPv6 hex piece")
    }
    pieces.push(value)
    if i < input.length() {
      if input[i] != b':' {
        return invalid("Invalid IPv6 separator")
      }
      i += 1
      if i == input.length() {
        return invalid("Trailing IPv6 colon")
      }
    }
  }
  let address : Array[Int32] = []
  if compressed is Some(at) {
    if pieces.length() >= 8 {
      return invalid("IPv6 compression must omit a piece")
    }
    for j in 0..<at {
      address.push(pieces[j])
    }
    for _ in 0..<(8 - pieces.length()) {
      address.push(0)
    }
    for j in at..<pieces.length() {
      address.push(pieces[j])
    }
  } else {
    if pieces.length() != 8 {
      return invalid("Too few IPv6 pieces")
    }
    for piece in pieces {
      address.push(piece)
    }
  }
  serialize_ipv6(address)
}

///|
/// Serializes IPv6 by compressing the first longest run of at least two zero pieces.
fn serialize_ipv6(address : Array[Int32]) -> String {
  let mut best_start = -1
  let mut best_length = 1
  let mut i = 0
  while i < 8 {
    if address[i] != 0 {
      i += 1
      continue
    }
    let start = i
    while i < 8 && address[i] == 0 {
      i += 1
    }
    if i - start > best_length {
      best_start = start
      best_length = i - start
    }
  }
  let output = StringBuilder()
  output.write_string("[")
  i = 0
  while i < 8 {
    if i == best_start {
      output.write_string("::")
      i += best_length
    } else {
      if i != 0 && i != best_start + best_length {
        output.write_string(":")
      }
      output.write_string(address[i].to_string(radix=16))
      i += 1
    }
  }
  output.write_string("]")
  output.to_string()
}
