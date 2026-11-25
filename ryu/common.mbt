// Copyright 2018-2019 Ulf Adams. Port copyright 2026 justjavac.
// Derived from Ryu under the Boost Software License 1.0; see LICENSE.

///|
/// Returns an integer increment for a Boolean rounding or carry condition.
fn increment(condition : Bool) -> UInt64 {
  if condition {
    1UL
  } else {
    0UL
  }
}

///|
/// Computes Ryu's bit length of 5^e, with exponent zero returning one.
fn pow5_bits(exponent : Int32) -> Int32 {
  ((exponent.reinterpret_as_uint() * 1217359U) >> 19).reinterpret_as_int() + 1
}

///|
/// Computes floor(log10(2^e)) exactly for Ryu's exponent range.
fn log10_pow2(exponent : Int32) -> Int32 {
  ((exponent.reinterpret_as_uint() * 78913U) >> 18).reinterpret_as_int()
}

///|
/// Computes floor(log10(5^e)) exactly for Ryu's exponent range.
fn log10_pow5(exponent : Int32) -> Int32 {
  ((exponent.reinterpret_as_uint() * 732923U) >> 20).reinterpret_as_int()
}

///|
/// Tests divisibility by a power of five for a nonzero fixed-width significand.
fn multiple_of_pow5(value : UInt64, exponent : Int32) -> Bool {
  for remaining = value, count = 0; count < exponent; {
    if remaining % 5UL != 0UL {
      return false
    }
    continue remaining / 5UL, count + 1
  }
  true
}

///|
/// Tests divisibility by a power of two without shifts outside a 64-bit word.
fn multiple_of_pow2(value : UInt64, exponent : Int32) -> Bool {
  exponent <= 0 || (exponent < 64 && (value & ((1UL << exponent) - 1UL)) == 0UL)
}

///|
/// Computes all 128 product bits from four bounded 32-bit limb products.
fn multiply128(a : UInt64, b : UInt64) -> (UInt64, UInt64) {
  let a_low = a & 0xFFFFFFFFUL
  let a_high = a >> 32
  let b_low = b & 0xFFFFFFFFUL
  let b_high = b >> 32
  let low_product = a_low * b_low
  let middle1 = a_high * b_low + (low_product >> 32)
  let middle2 = a_low * b_high + (middle1 & 0xFFFFFFFFUL)
  let high = a_high * b_high + (middle1 >> 32) + (middle2 >> 32)
  let low = (middle2 << 32) | (low_product & 0xFFFFFFFFUL)
  (low, high)
}

///|
/// Selects a 64-bit window from a 128-bit word, including a zero shift.
fn shift128(low : UInt64, high : UInt64, distance : Int32) -> UInt64 {
  if distance == 0 {
    low
  } else {
    (high << (64 - distance)) | (low >> distance)
  }
}

///|
/// Multiplies a significand by a table's 125-bit factor and keeps the shifted word.
fn mul_shift64(
  value : UInt64,
  table : FixedArray[UInt64],
  index : Int32,
  shift : Int32,
) -> UInt64 {
  // Table indices come from the bounded IEEE/decimal exponents; limbs are adjacent.
  let (_, high0) = multiply128(value, table[2 * index])
  let (low1, high1) = multiply128(value, table[2 * index + 1])
  let middle = low1 + high0
  let high = high1 + increment(middle < low1)
  shift128(middle, high, shift - 64)
}

///|
/// Multiplies a 32-bit significand by the shared double table's upper factor.
fn mul_shift32(value : UInt32, factor : UInt64, shift : Int32) -> UInt32 {
  let low = value.to_uint64() * (factor & 0xFFFFFFFFUL)
  let high = value.to_uint64() * (factor >> 32)
  ((high + (low >> 32)) >> (shift - 32)).to_uint()
}

///|
/// Applies the rounded inverse power of five used by the 32-bit conversion.
fn mul_pow5_inverse32(value : UInt32, index : Int32, shift : Int32) -> UInt32 {
  mul_shift32(value, double_pow5_inverse[2 * index + 1] + 1UL, shift)
}

///|
/// Applies a direct power of five using the shared table's upper 61 bits.
fn mul_pow5_32(value : UInt32, index : Int32, shift : Int32) -> UInt32 {
  mul_shift32(value, double_pow5[2 * index + 1], shift)
}

///|
/// Extracts a nine-digit block from a 256-bit product with portable limb arithmetic.
fn mul_shift_mod1e9(
  value : UInt64,
  table : FixedArray[UInt64],
  index : Int32,
  shift : Int32,
) -> UInt32 {
  let (_, high0) = multiply128(value, table[3 * index])
  let (low1, high1) = multiply128(value, table[3 * index + 1])
  let (low2, high2) = multiply128(value, table[3 * index + 2])
  let middle = low1 + high0
  let low = low2 + high1 + increment(middle < low1)
  let high = high2 + increment(low < low2)
  // shift is 128..180; reducing complete 32-bit limbs before the final shift
  // preserves the quotient modulo 10^9 because its modulus is multiplied by 2^32.
  if shift < 160 {
    let r0 = high % 1000000000UL
    let r1 = ((r0 << 32) | (low >> 32)) % 1000000000UL
    ((((r1 << 32) | (low & 0xFFFFFFFFUL)) >> (shift - 128)) % 1000000000UL).to_uint()
  } else {
    let r0 = high % 1000000000UL
    ((((r0 << 32) | (low >> 32)) >> (shift - 160)) % 1000000000UL).to_uint()
  }
}

///|
/// Renders one shortest significand in upstream's uppercase scientific notation.
fn shortest_string(
  mantissa : UInt64,
  exponent : Int32,
  negative : Bool,
) -> String {
  let digits = mantissa.to_string()
  let builder = StringBuilder(capacity=25)
  if negative {
    builder.write_char('-')
  }
  builder.write_stringview(digits[:1])
  if digits.length() > 1 {
    builder.write_char('.')
    builder.write_stringview(digits[1:])
  }
  builder.write_char('E')
  builder.write_string((exponent + digits.length() - 1).to_string())
  builder.to_string()
}
