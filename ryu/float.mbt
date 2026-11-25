// Copyright 2018 Ulf Adams. Port copyright 2026 justjavac.
// Derived from Ryu under the Boost Software License 1.0; see LICENSE.

///|
/// Finds a shortest decimal using binary32 intervals rather than widened precision.
fn float_decimal(mantissa : UInt32, exponent : Int32) -> (UInt64, Int32) {
  let (e2, m2) = if exponent == 0 {
    (-151, mantissa)
  } else {
    (exponent - 152, (1U << 23) | mantissa)
  }
  let accept_bounds = (m2 & 1U) == 0U
  let value = 4U * m2
  let upper = value + 2U
  let lower_shift = if mantissa != 0U || exponent <= 1 { 1U } else { 0U }
  let lower = value - 1U - lower_shift
  let mut lower_zeroes = false
  let mut value_zeroes = false
  let mut last_digit = 0U
  let mut vr = 0U
  let mut vp = 0U
  let mut vm = 0U
  let e10 = if e2 >= 0 {
    let q = log10_pow2(e2)
    let shift = -e2 + q + 61 + pow5_bits(q) - 1
    vr = mul_pow5_inverse32(value, q, shift)
    vp = mul_pow5_inverse32(upper, q, shift)
    vm = mul_pow5_inverse32(lower, q, shift)
    if q != 0 && (vp - 1U) / 10U <= vm / 10U {
      let shift = -e2 + q - 1 + 61 + pow5_bits(q - 1) - 1
      last_digit = mul_pow5_inverse32(value, q - 1, shift) % 10U
    }
    if q <= 9 {
      if value % 5U == 0U {
        value_zeroes = multiple_of_pow5(value.to_uint64(), q)
      } else if accept_bounds {
        lower_zeroes = multiple_of_pow5(lower.to_uint64(), q)
      } else {
        vp = vp - (if multiple_of_pow5(upper.to_uint64(), q) { 1U } else { 0U })
      }
    }
    q
  } else {
    let q = log10_pow5(-e2)
    let i = -e2 - q
    let shift = q - (pow5_bits(i) - 61)
    vr = mul_pow5_32(value, i, shift)
    vp = mul_pow5_32(upper, i, shift)
    vm = mul_pow5_32(lower, i, shift)
    if q != 0 && (vp - 1U) / 10U <= vm / 10U {
      let shift = q - 1 - (pow5_bits(i + 1) - 61)
      last_digit = mul_pow5_32(value, i + 1, shift) % 10U
    }
    if q <= 1 {
      value_zeroes = true
      if accept_bounds {
        lower_zeroes = lower_shift == 1U
      } else {
        vp = vp - 1U
      }
    } else if q < 31 {
      value_zeroes = multiple_of_pow2(value.to_uint64(), q - 1)
    }
    q + e2
  }
  let mut removed = 0
  let output = if lower_zeroes || value_zeroes {
    while vp / 10U > vm / 10U {
      lower_zeroes = lower_zeroes && vm % 10U == 0U
      value_zeroes = value_zeroes && last_digit == 0U
      last_digit = vr % 10U
      vr = vr / 10U
      vp = vp / 10U
      vm = vm / 10U
      removed += 1
    }
    if lower_zeroes {
      while vm % 10U == 0U {
        value_zeroes = value_zeroes && last_digit == 0U
        last_digit = vr % 10U
        vr = vr / 10U
        vp = vp / 10U
        vm = vm / 10U
        removed += 1
      }
    }
    if value_zeroes && last_digit == 5U && vr % 2U == 0U {
      last_digit = 4U
    }
    vr +
    (if (vr == vm && (!accept_bounds || !lower_zeroes)) || last_digit >= 5U {
      1U
    } else {
      0U
    })
  } else {
    while vp / 10U > vm / 10U {
      last_digit = vr % 10U
      vr = vr / 10U
      vp = vp / 10U
      vm = vm / 10U
      removed += 1
    }
    vr + (if vr == vm || last_digit >= 5U { 1U } else { 0U })
  }
  (output.to_uint64(), e10 + removed)
}

///|
/// Converts an IEEE 754 binary32 value to its shortest round-trip-safe decimal.
///
/// This uses the input's original Float precision; widening to Double before
/// calling `d2s` can produce different digits. Formatting, ties-to-even rounding,
/// negative zero, infinities, and NaN spellings follow `d2s`. The immutable ASCII
/// result and input are independent, and output is the same on every backend.
///
/// ```mbt check
/// test {
///   assert_eq(@ryu.f2s(Float::from_double(0.3)), "3E-1")
/// }
/// ```
pub fn f2s(value : Float) -> String {
  let bits = value.reinterpret_as_uint()
  let negative = bits >> 31 != 0U
  let mantissa = bits & 0x007FFFFFU
  let exponent = ((bits >> 23) & 255U).reinterpret_as_int()
  if exponent == 255 {
    if mantissa != 0U {
      return "NaN"
    }
    return if negative { "-Infinity" } else { "Infinity" }
  }
  if exponent == 0 && mantissa == 0U {
    return if negative { "-0E0" } else { "0E0" }
  }
  let (digits, decimal_exponent) = float_decimal(mantissa, exponent)
  shortest_string(digits, decimal_exponent, negative)
}
