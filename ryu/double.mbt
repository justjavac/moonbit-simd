// Copyright 2018 Ulf Adams. Port copyright 2026 justjavac.
// Derived from Ryu under the Boost Software License 1.0; see LICENSE.

///|
/// Finds the shortest rounded decimal inside a nonzero binary64 rounding interval.
fn double_decimal(mantissa : UInt64, exponent : Int32) -> (UInt64, Int32) {
  let (e2, m2) = if exponent == 0 {
    (-1076, mantissa)
  } else {
    (exponent - 1077, (1UL << 52) | mantissa)
  }
  let accept_bounds = (m2 & 1UL) == 0UL
  let value = 4UL * m2
  let lower_shift = increment(mantissa != 0UL || exponent <= 1)
  let mut lower_zeroes = false
  let mut value_zeroes = false
  let mut vr = 0UL
  let mut vp = 0UL
  let mut vm = 0UL
  let e10 = if e2 >= 0 {
    let q = log10_pow2(e2) - (if e2 > 3 { 1 } else { 0 })
    let shift = -e2 + q + 125 + pow5_bits(q) - 1
    vr = mul_shift64(value, double_pow5_inverse, q, shift)
    vp = mul_shift64(value + 2UL, double_pow5_inverse, q, shift)
    vm = mul_shift64(value - 1UL - lower_shift, double_pow5_inverse, q, shift)
    if q <= 21 {
      if value % 5UL == 0UL {
        value_zeroes = multiple_of_pow5(value, q)
      } else if accept_bounds {
        lower_zeroes = multiple_of_pow5(value - 1UL - lower_shift, q)
      } else {
        vp = vp - increment(multiple_of_pow5(value + 2UL, q))
      }
    }
    q
  } else {
    let q = log10_pow5(-e2) - (if -e2 > 1 { 1 } else { 0 })
    let i = -e2 - q
    let shift = q - (pow5_bits(i) - 125)
    vr = mul_shift64(value, double_pow5, i, shift)
    vp = mul_shift64(value + 2UL, double_pow5, i, shift)
    vm = mul_shift64(value - 1UL - lower_shift, double_pow5, i, shift)
    if q <= 1 {
      value_zeroes = true
      if accept_bounds {
        lower_zeroes = lower_shift == 1UL
      } else {
        vp = vp - 1UL
      }
    } else if q < 63 {
      value_zeroes = multiple_of_pow2(value, q)
    }
    q + e2
  }
  let mut removed = 0
  let mut last_digit = 0UL
  let output = if lower_zeroes || value_zeroes {
    while vp / 10UL > vm / 10UL {
      lower_zeroes = lower_zeroes && vm % 10UL == 0UL
      value_zeroes = value_zeroes && last_digit == 0UL
      last_digit = vr % 10UL
      vr = vr / 10UL
      vp = vp / 10UL
      vm = vm / 10UL
      removed += 1
    }
    if lower_zeroes {
      while vm % 10UL == 0UL {
        value_zeroes = value_zeroes && last_digit == 0UL
        last_digit = vr % 10UL
        vr = vr / 10UL
        vp = vp / 10UL
        vm = vm / 10UL
        removed += 1
      }
    }
    // Exact half-way decimals round to an even final digit.
    if value_zeroes && last_digit == 5UL && vr % 2UL == 0UL {
      last_digit = 4UL
    }
    vr +
    increment(
      (vr == vm && (!accept_bounds || !lower_zeroes)) || last_digit >= 5UL,
    )
  } else {
    let mut round_up = false
    if vp / 100UL > vm / 100UL {
      round_up = vr % 100UL >= 50UL
      vr = vr / 100UL
      vp = vp / 100UL
      vm = vm / 100UL
      removed += 2
    }
    while vp / 10UL > vm / 10UL {
      round_up = vr % 10UL >= 5UL
      vr = vr / 10UL
      vp = vp / 10UL
      vm = vm / 10UL
      removed += 1
    }
    vr + increment(vr == vm || round_up)
  }
  (output, e10 + removed)
}

///|
/// Converts an IEEE 754 binary64 value to Ryu's shortest round-trip-safe decimal.
///
/// The returned immutable ASCII string uses uppercase `E`, one digit before the
/// optional decimal point, and an unpadded exponent without a positive sign.
/// Rounding is to nearest with ties to even in the original binary64 precision.
/// Negative zero is `-0E0`, infinities are `Infinity`/`-Infinity`, and every NaN
/// is `NaN`, regardless of sign or payload. The input is unchanged. This pure
/// MoonBit implementation has identical output on all four supported backends.
///
/// ```mbt check
/// test {
///   assert_eq(@ryu.d2s(0.3), "3E-1")
///   assert_eq(@ryu.d2s(-0.0), "-0E0")
/// }
/// ```
pub fn d2s(value : Double) -> String {
  let bits = value.reinterpret_as_uint64()
  let negative = bits >> 63 != 0UL
  let mantissa = bits & 0x000FFFFFFFFFFFFFUL
  let exponent = ((bits >> 52) & 2047UL).to_int()
  if exponent == 2047 {
    if mantissa != 0UL {
      return "NaN"
    }
    return if negative { "-Infinity" } else { "Infinity" }
  }
  if exponent == 0 && mantissa == 0UL {
    return if negative { "-0E0" } else { "0E0" }
  }
  let e2 = exponent - 1075
  let m2 = (1UL << 52) | mantissa
  let (digits, decimal_exponent) = if e2 <= 0 &&
    e2 >= -52 &&
    multiple_of_pow2(m2, -e2) {
    // Integers in [1, 2^53) bypass interval multiplication.
    for digits = m2 >> -e2, power = 0; digits % 10UL == 0UL; {
      continue digits / 10UL, power + 1
    } nobreak {
      (digits, power)
    }
  } else {
    double_decimal(mantissa, exponent)
  }
  shortest_string(digits, decimal_exponent, negative)
}
