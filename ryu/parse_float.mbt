// Copyright 2019 Ulf Adams. Port copyright 2026 justjavac.
// Derived from Ryu under the Boost Software License 1.0; see LICENSE.

///|
/// Converts an already-scanned bounded decimal directly to rounded binary32 bits.
fn parsed_float(input : ParsedDecimal) -> Float {
  let sign = if input.negative { 1U << 31 } else { 0U }
  let order = input.digits.to_int64() + input.exponent
  if input.mantissa == 0UL || order <= -46L {
    return Float::reinterpret_from_uint(sign)
  }
  if order >= 40L {
    return Float::reinterpret_from_uint(sign | 0x7F800000U)
  }
  let e10 = input.exponent.to_int()
  let m10 = input.mantissa.to_uint()
  let (e2, m2, exact) = if e10 >= 0 {
    let e2 = 31 - m10.clz() + e10 + pow5_bits(e10) - 1 - 24
    let shift = e2 - e10 - pow5_bits(e10) + 61
    let m2 = mul_pow5_32(m10, e10, shift)
    (e2, m2, e2 < e10 || multiple_of_pow2(m10.to_uint64(), e2 - e10))
  } else {
    let e2 = 31 - m10.clz() + e10 - pow5_bits(-e10) - 24
    let shift = e2 - e10 + pow5_bits(-e10) - 1 + 61
    let m2 = mul_pow5_inverse32(m10, -e10, shift)
    (
      e2,
      m2,
      (e2 < e10 || multiple_of_pow2(m10.to_uint64(), e2 - e10)) &&
      multiple_of_pow5(m10.to_uint64(), -e10),
    )
  }
  let mut exponent = Int32::max(0, e2 + 127 + 31 - m2.clz())
  if exponent > 254 {
    return Float::reinterpret_from_uint(sign | 0x7F800000U)
  }
  let shift = Int32::max(1, exponent) - e2 - 127 - 23
  let rounded = if shift == 0 {
    m2
  } else {
    let last_bit = (m2 >> (shift - 1)) & 1U
    let trailing = exact && multiple_of_pow2(m2.to_uint64(), shift - 1)
    (m2 >> shift) +
    (if last_bit != 0U && (!trailing || ((m2 >> shift) & 1U) != 0U) {
      1U
    } else {
      0U
    })
  }
  let mantissa = rounded & 0x007FFFFFU
  if mantissa == 0U && rounded != m2 >> shift {
    exponent += 1
  }
  Float::reinterpret_from_uint(
    sign | (exponent.reinterpret_as_uint() << 23) | mantissa,
  )
}

///|
/// Parses an entire ASCII decimal view directly to a binary32 Float.
///
/// The mantissa budget is nine significant digits; the exponent budget is four.
/// Grammar, scan-order errors, accepted missing-digit forms, rounding, signed
/// underflow, infinity on overflow, input ownership, and view bounds follow
/// `s2d`. Direct binary32 rounding avoids a Double-to-Float double-rounding step.
///
/// ```mbt check
/// test {
///   assert_eq(@ryu.s2f("0.3").reinterpret_as_uint(), 0x3E99999AU)
/// }
/// ```
pub fn s2f(input : StringView) -> Float raise ParseError {
  parsed_float(scan_decimal(input, 9))
}
