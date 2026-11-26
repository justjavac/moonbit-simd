///|
/// Parses an unsigned eight-bit value from zero through 255.
/// Follows the sign and prefix rules in `Parse::parse_decimal`. Leading
/// zeroes count toward consumption and are accepted in either zero mode.
pub impl Parse for Byte with fn parse_decimal(
  data : BytesView,
  positive_only~ : Bool,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  skip_plus~ : Bool,
  simd~ : Bool,
) -> (Byte, Int32) raise ParseError {
  let mode = if positive_only { Positive } else { Automatic }
  let (value, consumed) = parse_word(
    data,
    mode,
    255UL,
    0UL,
    0,
    prefix~,
    skip_zeroes~,
    skip_plus~,
    simd~,
  )
  (value.to_byte(), consumed)
}

///|
/// Parses a signed eight-bit value from -128 through 127.
/// Follows the sign and prefix rules in `Parse::parse_decimal`. The full
/// digit prefix must fit the signed range before the result is narrowed.
pub impl Parse for Int8 with fn parse_decimal(
  data : BytesView,
  positive_only~ : Bool,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  skip_plus~ : Bool,
  simd~ : Bool,
) -> (Int8, Int32) raise ParseError {
  let mode = if positive_only { Positive } else { Automatic }
  let (value, consumed) = parse_word(
    data,
    mode,
    127UL,
    128UL,
    0,
    prefix~,
    skip_zeroes~,
    skip_plus~,
    simd~,
  )
  ({ value: value.reinterpret_as_int64().to_int(), }, consumed)
}

///|
/// Parses sign-free digits as a value from -128 through zero.
/// With `prefix=true`, consumption ends at the first non-digit. Leading
/// zeroes are accepted, and a magnitude above 128 raises `Overflow`.
pub impl ParseNeg for Int8 with fn parse_negative_decimal(
  data : BytesView,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  simd~ : Bool,
) -> (Int8, Int32) raise ParseError {
  let (value, consumed) = parse_word(
    data,
    Negative,
    127UL,
    128UL,
    0,
    prefix~,
    skip_zeroes~,
    skip_plus=false,
    simd~,
  )
  ({ value: value.reinterpret_as_int64().to_int(), }, consumed)
}

///|
/// Parses an unsigned sixteen-bit value from zero through 65535.
/// Follows the sign and prefix rules in `Parse::parse_decimal`. Leading
/// zeroes count toward consumption and are accepted in either zero mode.
pub impl Parse for UInt16 with fn parse_decimal(
  data : BytesView,
  positive_only~ : Bool,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  skip_plus~ : Bool,
  simd~ : Bool,
) -> (UInt16, Int32) raise ParseError {
  let mode = if positive_only { Positive } else { Automatic }
  let (value, consumed) = parse_word(
    data,
    mode,
    65535UL,
    0UL,
    0,
    prefix~,
    skip_zeroes~,
    skip_plus~,
    simd~,
  )
  (value.to_uint16(), consumed)
}

///|
/// Parses a signed sixteen-bit value from -32768 through 32767.
/// Follows the sign and prefix rules in `Parse::parse_decimal`. The full
/// digit prefix must fit the signed range before the result is narrowed.
pub impl Parse for Int16 with fn parse_decimal(
  data : BytesView,
  positive_only~ : Bool,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  skip_plus~ : Bool,
  simd~ : Bool,
) -> (Int16, Int32) raise ParseError {
  let mode = if positive_only { Positive } else { Automatic }
  let (value, consumed) = parse_word(
    data,
    mode,
    32767UL,
    32768UL,
    0,
    prefix~,
    skip_zeroes~,
    skip_plus~,
    simd~,
  )
  (Int16::from_int64(value.reinterpret_as_int64()), consumed)
}

///|
/// Parses sign-free digits as a value from -32768 through zero.
/// With `prefix=true`, consumption ends at the first non-digit. Leading
/// zeroes are accepted, and a magnitude above 32768 raises `Overflow`.
pub impl ParseNeg for Int16 with fn parse_negative_decimal(
  data : BytesView,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  simd~ : Bool,
) -> (Int16, Int32) raise ParseError {
  let (value, consumed) = parse_word(
    data,
    Negative,
    32767UL,
    32768UL,
    0,
    prefix~,
    skip_zeroes~,
    skip_plus=false,
    simd~,
  )
  (Int16::from_int64(value.reinterpret_as_int64()), consumed)
}

///|
/// Parses an unsigned thirty-two-bit value from zero through 4294967295.
/// Follows the sign and prefix rules in `Parse::parse_decimal`. Leading
/// zeroes count toward consumption and are accepted in either zero mode.
pub impl Parse for UInt32 with fn parse_decimal(
  data : BytesView,
  positive_only~ : Bool,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  skip_plus~ : Bool,
  simd~ : Bool,
) -> (UInt32, Int32) raise ParseError {
  let mode = if positive_only { Positive } else { Automatic }
  let (value, consumed) = parse_word(
    data,
    mode,
    4294967295UL,
    0UL,
    0,
    prefix~,
    skip_zeroes~,
    skip_plus~,
    simd~,
  )
  (value.to_uint(), consumed)
}

///|
/// Parses a signed thirty-two-bit value from -2147483648 through 2147483647.
/// Follows the sign and prefix rules in `Parse::parse_decimal`. The full
/// digit prefix must fit the signed range before the result is narrowed.
pub impl Parse for Int32 with fn parse_decimal(
  data : BytesView,
  positive_only~ : Bool,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  skip_plus~ : Bool,
  simd~ : Bool,
) -> (Int32, Int32) raise ParseError {
  let mode = if positive_only { Positive } else { Automatic }
  let (value, consumed) = parse_word(
    data,
    mode,
    2147483647UL,
    2147483648UL,
    0,
    prefix~,
    skip_zeroes~,
    skip_plus~,
    simd~,
  )
  (value.reinterpret_as_int64().to_int(), consumed)
}

///|
/// Parses sign-free digits as a value from -2147483648 through zero.
/// With `prefix=true`, consumption ends at the first non-digit. Leading
/// zeroes are accepted, and larger magnitudes raise `Overflow`.
pub impl ParseNeg for Int32 with fn parse_negative_decimal(
  data : BytesView,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  simd~ : Bool,
) -> (Int32, Int32) raise ParseError {
  let (value, consumed) = parse_word(
    data,
    Negative,
    2147483647UL,
    2147483648UL,
    0,
    prefix~,
    skip_zeroes~,
    skip_plus=false,
    simd~,
  )
  (value.reinterpret_as_int64().to_int(), consumed)
}
