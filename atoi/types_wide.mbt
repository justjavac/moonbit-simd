///|
/// Implements unsigned 128-bit decimal parsing without narrowing the result.
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
/// Implements signed 128-bit decimal parsing using exact two's-complement bits.
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
/// Implements sign-free negative 128-bit parsing, including the signed minimum.
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
