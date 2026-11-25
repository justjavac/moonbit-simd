// Copyright 2019 Ulf Adams. Port copyright 2026 justjavac.
// Derived from Ryu under the Boost Software License 1.0; see LICENSE.

///|
/// Converts an already-scanned bounded decimal directly to rounded binary64 bits.
fn parsed_double(input : ParsedDecimal) -> Double {
  let sign = if input.negative { 1UL << 63 } else { 0UL }
  let order = input.digits.to_int64() + input.exponent
  if input.mantissa == 0UL || order <= -324L {
    return sign.reinterpret_as_double()
  }
  if order >= 310L {
    return (sign | 0x7FF0000000000000UL).reinterpret_as_double()
  }
  let e10 = input.exponent.to_int()
  let m10 = input.mantissa
  let (e2, m2, exact) = if e10 >= 0 {
    let e2 = 63 - m10.clz() + e10 + pow5_bits(e10) - 1 - 53
    let shift = e2 - e10 - pow5_bits(e10) + 125
    let m2 = mul_shift64(m10, double_pow5, e10, shift)
    (e2, m2, e2 < e10 || multiple_of_pow2(m10, e2 - e10))
  } else {
    let e2 = 63 - m10.clz() + e10 - pow5_bits(-e10) - 53
    let shift = e2 - e10 + pow5_bits(-e10) - 1 + 125
    let m2 = mul_shift64(m10, double_pow5_inverse, -e10, shift)
    (e2, m2, multiple_of_pow5(m10, -e10))
  }
  let mut exponent = Int32::max(0, e2 + 1023 + 63 - m2.clz())
  if exponent > 2046 {
    return (sign | 0x7FF0000000000000UL).reinterpret_as_double()
  }
  let shift = Int32::max(1, exponent) - e2 - 1023 - 52
  let rounded = if shift == 0 {
    m2
  } else {
    let last_bit = (m2 >> (shift - 1)) & 1UL
    let trailing = exact && multiple_of_pow2(m2, shift - 1)
    (m2 >> shift) +
    increment(last_bit != 0UL && (!trailing || ((m2 >> shift) & 1UL) != 0UL))
  }
  let mantissa = rounded & 0x000FFFFFFFFFFFFFUL
  if mantissa == 0UL && rounded != m2 >> shift {
    exponent += 1
  }
  (sign | (exponent.to_uint64() << 52) | mantissa).reinterpret_as_double()
}

///|
/// Parses an entire ASCII decimal view using upstream's experimental binary64 parser.
///
/// Up to 17 significant mantissa digits and four significant exponent digits are
/// accepted; initial zeroes do not consume either budget, while all digits after
/// the first nonzero do. ASCII `-`, one decimal point, and `e`/`E` with an optional
/// exponent sign are supported. Initial `+`, whitespace, non-ASCII characters,
/// NUL, Infinity, and NaN spellings are rejected. Empty input raises
/// `InputTooShort`; excess digits raise `InputTooLong`; other rejected syntax
/// raises `MalformedInput`, in upstream scan order.
///
/// For compatibility this accepts missing mantissa/exponent digits: `-`, `.`,
/// and `e` parse as signed/unsigned zero, and `1e+` parses as one. This is not a
/// general language or JSON number validator. Numeric rounding is to nearest,
/// ties to even; underflow preserves signed zero and overflow yields infinity.
/// Only the actual view is read, with no mutation, and all backends agree.
///
/// ```mbt check
/// test {
///   assert_eq(@ryu.s2d("1.25e2"), 125.0)
///   assert_eq(@ryu.s2d("-0").reinterpret_as_uint64(), 0x8000000000000000UL)
/// }
/// ```
pub fn s2d(input : StringView) -> Double raise ParseError {
  parsed_double(scan_decimal(input, 17))
}
