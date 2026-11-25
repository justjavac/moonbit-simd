///|
/// Maps each byte to its hexadecimal nibble or the invalid sentinel -1.
let decode_table : FixedArray[Int32] = FixedArray::makei(256, value => {
  match value {
    '0'..<='9' => value - '0'
    'a'..<='f' => value - 'a' + 10
    'A'..<='F' => value - 'A' + 10
    _ => -1
  }
})

///|
/// Locates a hexadecimal digit in compact or 8-4-4-4-12 text.
#inline
fn digit_position(digit : Int32, hyphenated : Bool) -> Int32 {
  if !hyphenated {
    digit
  } else {
    digit +
    (if digit >= 8 { 1 } else { 0 }) +
    (if digit >= 12 { 1 } else { 0 }) +
    (if digit >= 16 { 1 } else { 0 }) +
    (if digit >= 20 { 1 } else { 0 })
  }
}

///|
/// Decodes a UTF-16 code unit without truncating non-ASCII values to bytes.
#inline
fn text_nibble(value : UInt16) -> Int32 {
  if value < 256 {
    decode_table[value.to_int()]
  } else {
    -1
  }
}

///|
/// Decodes a checked text body into immutable words using scalar table lookups.
fn parse_text_scalar(
  input : StringView,
  hyphenated : Bool,
) -> Uuid raise UuidError {
  for i in 0..<16; high = 0UL, low = 0UL, flag = 0 {
    let a = text_nibble(input[digit_position(i, hyphenated)])
    let b = text_nibble(input[digit_position(i + 16, hyphenated)])
    continue (high << 4) | a.to_uint64(),
      (low << 4) | b.to_uint64(),
      flag | a | b
  } nobreak {
    guard flag >= 0 else { raise InvalidUuid }
    { high, low, }
  }
}

///|
/// Decodes a checked byte body without allocating a text conversion.
fn parse_bytes_scalar(
  input : BytesView,
  hyphenated : Bool,
) -> Uuid raise UuidError {
  for i in 0..<16; high = 0UL, low = 0UL, flag = 0 {
    let a = decode_table[input[digit_position(i, hyphenated)].to_int()]
    let b = decode_table[input[digit_position(i + 16, hyphenated)].to_int()]
    continue (high << 4) | a.to_uint64(),
      (low << 4) | b.to_uint64(),
      flag | a | b
  } nobreak {
    guard flag >= 0 else { raise InvalidUuid }
    { high, low, }
  }
}
