// Copyright 2018 Ulf Adams. Port copyright 2026 justjavac.
// Derived from Ryu under the Boost Software License 1.0; see LICENSE.

///|
/// Reports precision values that cannot fit the portable output length contract.
#derive(Debug, Eq)
pub(all) suberror FormatError {
  /// The requested fractional digit count is outside 0..2147483336.
  InvalidPrecision(Int32)
}

///|
/// Rejects negative precision and reserves room for the largest binary64 integer.
fn validate_precision(precision : Int32) -> Unit raise FormatError {
  if precision < 0 || precision > 2147483336 {
    raise InvalidPrecision(precision)
  }
}

///|
/// Provides exact ASCII digits without unchecked code-point conversions.
let decimal_digits : FixedArray[Char] = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
]

///|
/// Counts the unpadded digits in one nonzero nine-digit block.
fn decimal_length9(value : UInt32) -> Int32 {
  if value >= 100000000U {
    9
  } else if value >= 10000000U {
    8
  } else if value >= 1000000U {
    7
  } else if value >= 100000U {
    6
  } else if value >= 10000U {
    5
  } else if value >= 1000U {
    4
  } else if value >= 100U {
    3
  } else if value >= 10U {
    2
  } else {
    1
  }
}

///|
/// Appends an exact count of ASCII zeroes to a private result buffer.
fn append_zeroes(output : Array[Char], count : Int32) -> Unit {
  for _ in 0..<count {
    output.push('0')
  }
}

///|
/// Appends a fixed-width integer block, including its significant leading zeroes.
fn append_block(output : Array[Char], digits : UInt32, width : Int32) -> Unit {
  let start = output.length()
  append_zeroes(output, width)
  for i = width - 1, remaining = digits; i >= 0; {
    output[start + i] = decimal_digits[(remaining % 10U).reinterpret_as_int()]
    continue i - 1, remaining / 10U
  }
}

///|
/// Appends the first scientific block and places its decimal point after one digit.
fn append_scientific_block(
  output : Array[Char],
  digits : UInt32,
  width : Int32,
  point : Bool,
) -> Unit {
  let start = output.length()
  append_block(output, digits, width)
  if point {
    output.insert(start + 1, '.')
  }
}

///|
/// Rounds a private decimal buffer and reports a carry beyond its first digit.
fn round_output(output : Array[Char], mode : Int32) -> Bool {
  if mode == 0 {
    return false
  }
  let start = if output[0] == '-' { 1 } else { 0 }
  for i = output.length() - 1, round = mode; i >= start; {
    let c = output[i]
    if c == '.' {
      continue i - 1, round
    }
    if c == '9' {
      output[i] = '0'
      continue i - 1, 1
    }
    if round == 2 && c.to_int() % 2 == 0 {
      return false
    }
    output[i] = decimal_digits[c.to_int() - 48 + 1]
    return false
  }
  true
}

///|
/// Detects an exact decimal half-way remainder using divisibility by two and five.
fn exact_halfway(mantissa : UInt64, exponent : Int32, places : Int64) -> Bool {
  let twos = -exponent.to_int64() - places
  let trailing = twos <= 0L ||
    (twos < 64L && multiple_of_pow2(mantissa, twos.to_int()))
  trailing && (places >= 0L || multiple_of_pow5(mantissa, (-places).to_int()))
}

///|
/// Returns portable Printf special spellings following upstream's non-MSVC branch.
fn printf_special(negative : Bool, mantissa : UInt64) -> String {
  if mantissa != 0UL {
    "nan"
  } else if negative {
    "-Infinity"
  } else {
    "Infinity"
  }
}

///|
/// Returns the finite binary64 significand and unbiased power of two.
fn printf_binary(mantissa : UInt64, exponent : Int32) -> (UInt64, Int32) {
  if exponent == 0 {
    (mantissa, -1074)
  } else {
    ((1UL << 52) | mantissa, exponent - 1075)
  }
}

///|
/// Selects the integer table group and number of nine-digit blocks for an exponent.
fn integer_group(exponent : Int32) -> (Int32, Int32) {
  let index = if exponent < 0 { 0 } else { (exponent + 15) / 16 }
  (index, (log10_pow2(16 * index) + 25) / 9)
}
