// Copyright 2018 Ulf Adams. Port copyright 2026 justjavac.
// Derived from Ryu under the Boost Software License 1.0; see LICENSE.

///|
/// Formats a binary64 value in scientific notation with an exact fractional width.
///
/// This ports Ryu Printf's `%e` operation: one digit precedes the decimal point,
/// `precision` digits follow it, and lowercase `e` precedes an explicit sign and
/// an exponent padded to at least two digits. Precision zero omits the point.
/// Rounding uses the exact binary value with ties to even and can carry into
/// the exponent. Negative zero, non-finite values, precision validation, input
/// ownership, allocation, and backend guarantees are the same as `d2fixed`.
///
/// ```mbt check
/// test {
///   assert_eq(@ryu.d2exp(9.99, precision=1), "1.0e+01")
///   assert_eq(@ryu.d2exp(-0.0, precision=2), "-0.00e+00")
/// }
/// ```
pub fn d2exp(value : Double, precision~ : Int32) -> String raise FormatError {
  validate_precision(precision)
  let bits = value.reinterpret_as_uint64()
  let negative = bits >> 63 != 0UL
  let mantissa = bits & 0x000FFFFFFFFFFFFFUL
  let exponent = ((bits >> 52) & 2047UL).to_int()
  if exponent == 2047 {
    return printf_special(negative, mantissa)
  }
  let output : Array[Char] = Array(capacity=precision + 8)
  if negative {
    output.push('-')
  }
  if exponent == 0 && mantissa == 0UL {
    output.push('0')
    if precision > 0 {
      output.push('.')
      append_zeroes(output, precision)
    }
    for c in "e+00" {
      output.push(c)
    }
    return String::from_array(output)
  }
  let (m2, e2) = printf_binary(mantissa, exponent)
  let total = precision + 1
  let point = precision > 0
  let mut digits = 0U
  let mut printed = 0
  let mut available = 0
  let mut exp = 0
  if e2 >= -52 {
    let (group, length) = integer_group(e2)
    let shift = 16 * group + 120 - e2 + 8
    for i = length - 1; i >= 0; i = i - 1 {
      digits = mul_shift_mod1e9(
        m2 << 8,
        pow10_multipliers,
        pow10_offsets[group] + i,
        shift,
      )
      if printed != 0 {
        if printed + 9 > total {
          available = 9
          break
        }
        append_block(output, digits, 9)
        printed += 9
      } else if digits != 0U {
        available = decimal_length9(digits)
        exp = i * 9 + available - 1
        if available > total {
          break
        }
        append_scientific_block(output, digits, available, point)
        printed = available
        available = 0
      }
    }
  }
  if e2 < 0 && available == 0 {
    let group = -e2 / 16
    let minimum = minimum_fractional_blocks[group]
    let end = minimum +
      fractional_offsets[group + 1] -
      fractional_offsets[group]
    let shift = 120 + (-e2 - 16 * group) + 8
    // After the last stored block the exact fraction is zero, so padding can
    // handle any precision without scanning hundreds of unnecessary blocks.
    for i in minimum..<end {
      let offset = fractional_offsets[group] + i - minimum
      digits = mul_shift_mod1e9(m2 << 8, fractional_multipliers, offset, shift)
      if printed != 0 {
        if printed + 9 > total {
          available = 9
          break
        }
        append_block(output, digits, 9)
        printed += 9
      } else if digits != 0U {
        available = decimal_length9(digits)
        exp = -(i + 1) * 9 + available - 1
        if available > total {
          break
        }
        append_scientific_block(output, digits, available, point)
        printed = available
        available = 0
      }
    }
  }
  let width = total - printed
  if available == 0 {
    digits = 0U
  }
  let mut last = 0U
  if available > width {
    for _ in 0..<(available - width) {
      last = digits % 10U
      digits = digits / 10U
    }
  }
  let mode = if last != 5U {
    if last > 5U {
      1
    } else {
      0
    }
  } else if exact_halfway(m2, e2, total.to_int64() - exp.to_int64()) {
    2
  } else {
    1
  }
  if printed != 0 {
    if digits == 0U {
      append_zeroes(output, width)
    } else {
      append_block(output, digits, width)
    }
  } else {
    append_scientific_block(output, digits, width, point)
  }
  if round_output(output, mode) {
    output[if negative { 1 } else { 0 }] = '1'
    exp += 1
  }
  output.push('e')
  output.push(if exp < 0 { '-' } else { '+' })
  let absolute = if exp < 0 { -exp } else { exp }
  if absolute < 10 {
    output.push('0')
  }
  for c in absolute.to_string() {
    output.push(c)
  }
  String::from_array(output)
}
