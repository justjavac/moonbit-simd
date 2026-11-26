///|
/// Parses an unsigned sixty-four-bit value from zero through `2^64 - 1`.
/// Uses the twenty-digit budget before checking the value range. Accepted
/// signs, leading zeroes, and consumed-byte counts follow `Parse::parse_decimal`.
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
/// Parses a signed sixty-four-bit value from `-2^63` through `2^63 - 1`.
/// Uses the nineteen-digit budget and checks the sign-specific bound.
/// Accepted signs and consumed bytes follow `Parse::parse_decimal`.
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
/// Parses sign-free digits as a value from `-2^63` through zero.
/// Uses the nineteen-digit budget, with `skip_zeroes` controlling whether
/// leading zeroes count toward it. Consumption follows `ParseNeg`.
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
