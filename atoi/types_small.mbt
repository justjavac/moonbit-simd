///|
/// Implements range-checked decimal parsing for Byte.
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
/// Implements range-checked decimal parsing for Int8.
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
/// Implements sign-free negative decimal parsing for Int8.
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
/// Implements range-checked decimal parsing for UInt16.
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
/// Implements range-checked decimal parsing for Int16.
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
/// Implements sign-free negative decimal parsing for Int16.
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
/// Implements range-checked decimal parsing for UInt.
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
/// Implements range-checked decimal parsing for Int.
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
/// Implements sign-free negative decimal parsing for Int.
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
