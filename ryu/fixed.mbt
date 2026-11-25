// Copyright 2018 Ulf Adams. Port copyright 2026 justjavac.
// Derived from Ryu under the Boost Software License 1.0; see LICENSE.

///|
/// Formats a binary64 value with exactly `precision` digits after the decimal point.
///
/// This ports Ryu Printf's `%f` operation, rounding the exact binary value to
/// nearest with ties to even. Precision zero omits the decimal point. The sign
/// of negative zero and values rounded to zero is preserved. Infinities use
/// `Infinity`/`-Infinity`; all NaNs use `nan` on every backend, following the
/// upstream non-MSVC spelling. Input is unchanged and the result is immutable.
///
/// `precision` must be in 0..2147483336; otherwise this raises `InvalidPrecision`
/// before allocation, including for special values. Output storage grows with
/// the requested precision and integer length. Float inputs may be widened
/// exactly to Double for this operation. All supported backends use pure MoonBit.
///
/// ```mbt check
/// test {
///   assert_eq(@ryu.d2fixed(2.5, precision=0), "2")
///   assert_eq(@ryu.d2fixed(0.1, precision=20), "0.10000000000000000555")
/// }
/// ```
pub fn d2fixed(value : Double, precision~ : Int32) -> String raise FormatError {
  validate_precision(precision)
  let bits = value.reinterpret_as_uint64()
  let negative = bits >> 63 != 0UL
  let mantissa = bits & 0x000FFFFFFFFFFFFFUL
  let exponent = ((bits >> 52) & 2047UL).to_int()
  if exponent == 2047 {
    return printf_special(negative, mantissa)
  }
  let output : Array[Char] = Array(capacity=precision + 32)
  if negative {
    output.push('-')
  }
  if exponent == 0 && mantissa == 0UL {
    output.push('0')
    if precision > 0 {
      output.push('.')
      append_zeroes(output, precision)
    }
    return String::from_array(output)
  }
  let (m2, e2) = printf_binary(mantissa, exponent)
  let mut nonzero = false
  if e2 >= -52 {
    let (group, length) = integer_group(e2)
    let shift = 16 * group + 120 - e2 + 8
    for i = length - 1; i >= 0; i = i - 1 {
      let digits = mul_shift_mod1e9(
        m2 << 8,
        pow10_multipliers,
        pow10_offsets[group] + i,
        shift,
      )
      if nonzero {
        append_block(output, digits, 9)
      } else if digits != 0U {
        append_block(output, digits, decimal_length9(digits))
        nonzero = true
      }
    }
  }
  if !nonzero {
    output.push('0')
  }
  if precision > 0 {
    output.push('.')
  }
  if e2 >= 0 {
    append_zeroes(output, precision)
    return String::from_array(output)
  }
  let group = -e2 / 16
  let blocks = precision / 9 + 1
  let minimum = minimum_fractional_blocks[group]
  let mut mode = 0
  if blocks <= minimum {
    append_zeroes(output, precision)
  } else {
    append_zeroes(output, 9 * minimum)
    for i = minimum; i < blocks; i = i + 1 {
      let offset = fractional_offsets[group] + i - minimum
      if offset >= fractional_offsets[group + 1] {
        append_zeroes(output, precision - 9 * i)
        break
      }
      let shift = 120 + (-e2 - 16 * group) + 8
      let mut digits = mul_shift_mod1e9(
        m2 << 8,
        fractional_multipliers,
        offset,
        shift,
      )
      if i < blocks - 1 {
        append_block(output, digits, 9)
      } else {
        let width = precision - 9 * i
        let mut last = 0U
        for _ in 0..<(9 - width) {
          last = digits % 10U
          digits = digits / 10U
        }
        mode = if last != 5U {
          if last > 5U {
            1
          } else {
            0
          }
        } else if exact_halfway(m2, e2, precision.to_int64() + 1L) {
          2
        } else {
          1
        }
        if width > 0 {
          append_block(output, digits, width)
        }
        break
      }
    }
  }
  if round_output(output, mode) {
    output.insert(if negative { 1 } else { 0 }, '1')
  }
  String::from_array(output)
}
