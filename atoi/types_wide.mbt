///|
/// Parses a value from zero through `2^128 - 1` using exact word arithmetic.
/// Uses the thirty-nine-digit budget. Accepted signs, leading zeroes, and
/// consumed bytes follow `Parse::parse_decimal`.
pub impl Parse for UInt128 with fn parse_decimal(
  data : BytesView,
  positive_only~ : Bool,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  skip_plus~ : Bool,
  simd~ : Bool,
) -> (UInt128, Int32) raise ParseError {
  let mode = if positive_only { Positive } else { Automatic }
  parse_wide(data, mode, signed=false, prefix~, skip_zeroes~, skip_plus~, simd~)
}

///|
/// Parses a value from `-2^127` through `2^127 - 1` in two's complement.
/// Uses the thirty-nine-digit budget and the bound selected by the sign.
/// Prefix and leading-zero handling follow `Parse::parse_decimal`.
pub impl Parse for Int128 with fn parse_decimal(
  data : BytesView,
  positive_only~ : Bool,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  skip_plus~ : Bool,
  simd~ : Bool,
) -> (Int128, Int32) raise ParseError {
  let mode = if positive_only { Positive } else { Automatic }
  let (bits, consumed) = parse_wide(
    data,
    mode,
    signed=true,
    prefix~,
    skip_zeroes~,
    skip_plus~,
    simd~,
  )
  (Int128::from_bits(bits), consumed)
}

///|
/// Parses sign-free digits as a value from `-2^127` through zero.
/// Uses the thirty-nine-digit budget, with `skip_zeroes` controlling whether
/// leading zeroes count toward it. Consumption follows `ParseNeg`.
pub impl ParseNeg for Int128 with fn parse_negative_decimal(
  data : BytesView,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  simd~ : Bool,
) -> (Int128, Int32) raise ParseError {
  let (bits, consumed) = parse_wide(
    data,
    Negative,
    signed=true,
    prefix~,
    skip_zeroes~,
    skip_plus=false,
    simd~,
  )
  (Int128::from_bits(bits), consumed)
}
