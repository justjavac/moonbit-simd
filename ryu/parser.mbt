// Copyright 2019 Ulf Adams. Port copyright 2026 justjavac.
// Derived from Ryu under the Boost Software License 1.0; see LICENSE.

///|
/// Reports the first syntax or digit-budget error from `s2d` or `s2f`.
/// These errors follow the upstream scan order. A numeric overflow after
/// successful parsing produces signed infinity.
///
/// ```mbt check
/// test {
///   try @ryu.s2d("123456789012345678") catch {
///     error => assert_eq(error, @ryu.InputTooLong)
///   } noraise {
///     _ => fail("expected the binary64 mantissa digit limit")
///   }
/// }
/// ```
#derive(Debug, Eq)
pub(all) suberror ParseError {
  /// The complete input view is empty.
  InputTooShort
  /// The mantissa has more than 17 significant digits for `s2d` or nine
  /// for `s2f`, or the exponent has more than four.
  InputTooLong
  /// The input contains a character outside its allowed position in the
  /// decimal grammar, such as a leading plus or repeated decimal point.
  MalformedInput
}

///|
/// Holds an immutable decimal significand and full-width exponent after scanning.
priv struct ParsedDecimal {
  mantissa : UInt64
  exponent : Int64
  digits : Int32
  negative : Bool
}

///|
/// Scans exactly one input view using the upstream grammar and significant-digit budget.
fn scan_decimal(
  input : StringView,
  budget : Int32,
) -> ParsedDecimal raise ParseError {
  let length = input.length()
  if length == 0 {
    raise InputTooShort
  }
  let negative = input[0] == '-'
  let mut i = if negative { 1 } else { 0 }
  let mut digits = 0
  let mut mantissa = 0UL
  let mut dot = length
  let mut exponent_start = length
  while i < length {
    let c = input[i]
    if c == '.' {
      if dot != length {
        raise MalformedInput
      }
      dot = i
      i += 1
      continue
    }
    if c < '0' || c > '9' {
      break
    }
    if digits >= budget {
      raise InputTooLong
    }
    mantissa = mantissa * 10UL + (c.to_int() - 48).to_uint64()
    if mantissa != 0UL {
      digits += 1
    }
    i += 1
  }
  let mut exponent = 0L
  let mut exponent_negative = false
  if i < length && (input[i] == 'e' || input[i] == 'E') {
    exponent_start = i
    i += 1
    if i < length && (input[i] == '-' || input[i] == '+') {
      exponent_negative = input[i] == '-'
      i += 1
    }
    let mut exponent_digits = 0
    while i < length {
      let c = input[i]
      if c < '0' || c > '9' {
        raise MalformedInput
      }
      if exponent_digits > 3 {
        raise InputTooLong
      }
      exponent = exponent * 10L + (c.to_int() - 48).to_int64()
      if exponent != 0L {
        exponent_digits += 1
      }
      i += 1
    }
  }
  if i < length {
    raise MalformedInput
  }
  if exponent_negative {
    exponent = -exponent
  }
  if dot < exponent_start {
    exponent = exponent - (exponent_start - dot - 1).to_int64()
  }
  { mantissa, exponent, digits, negative, }
}
