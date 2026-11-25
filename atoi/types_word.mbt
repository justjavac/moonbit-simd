///|
/// Implements range-checked decimal parsing for UInt64.
pub impl Parse for UInt64 with fn parse_decimal(
  data : BytesView,
  positive_only~ : Bool,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  skip_plus~ : Bool,
  simd~ : Bool,
) -> (UInt64, Int32) raise ParseError {
  let mode = if positive_only { Positive } else { Automatic }
  let (value, consumed) = parse_word(
    data,
    mode,
    18446744073709551615UL,
    0UL,
    20,
    prefix~,
    skip_zeroes~,
    skip_plus~,
    simd~,
  )
  (value, consumed)
}

///|
/// Implements range-checked decimal parsing for Int64.
pub impl Parse for Int64 with fn parse_decimal(
  data : BytesView,
  positive_only~ : Bool,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  skip_plus~ : Bool,
  simd~ : Bool,
) -> (Int64, Int32) raise ParseError {
  let mode = if positive_only { Positive } else { Automatic }
  let (value, consumed) = parse_word(
    data,
    mode,
    9223372036854775807UL,
    9223372036854775808UL,
    19,
    prefix~,
    skip_zeroes~,
    skip_plus~,
    simd~,
  )
  (value.reinterpret_as_int64(), consumed)
}

///|
/// Implements sign-free negative decimal parsing for Int64.
pub impl ParseNeg for Int64 with fn parse_negative_decimal(
  data : BytesView,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  simd~ : Bool,
) -> (Int64, Int32) raise ParseError {
  let (value, consumed) = parse_word(
    data,
    Negative,
    9223372036854775807UL,
    9223372036854775808UL,
    19,
    prefix~,
    skip_zeroes~,
    skip_plus=false,
    simd~,
  )
  (value.reinterpret_as_int64(), consumed)
}
