///|
/// An immutable unsigned 128-bit result, represented privately by two words.
///
/// Values range from zero to 340282366920938463463374607431768211455.
/// Word access and decimal formatting are exact on all four supported backends;
/// assignments share only immutable state and require no independent copy.
#derive(Debug, Eq)
pub struct UInt128 {
  priv high : UInt64
  priv low : UInt64
}

///|
/// Constructs the exact unsigned value `high * 2^64 + low` from two words.
/// Every word pair is valid. The new value is immutable and owns no byte view.
pub fn UInt128::from_words(high~ : UInt64, low~ : UInt64) -> UInt128 {
  { high, low, }
}

///|
/// Returns `(high, low)` in decreasing significance, without changing the value.
/// This exposes exact bits rather than a lossy floating-point conversion.
pub fn UInt128::to_words(self : UInt128) -> (UInt64, UInt64) {
  (self.high, self.low)
}

///|
/// Returns the exact unsigned decimal representation without leading zeroes.
/// Zero is `"0"`. Formatting allocates strings but does not mutate this value;
/// no arbitrary-precision dependency or backend-specific representation is used.
pub fn UInt128::to_string(self : UInt128) -> String {
  if self.high == 0 {
    return self.low.to_string()
  }
  let digits = "0123456789"
  for value = self, text = ""; value.high != 0 || value.low != 0; {
    let (quotient, remainder) = value.divide_small(10UL)
    let index = remainder.to_int()
    continue quotient, digits[index:index + 1].to_owned() + text
  } nobreak {
    text
  }
}

///|
/// An immutable signed 128-bit result stored privately in two's complement.
///
/// Values range from -170141183460469231731687303715884105728 to
/// 170141183460469231731687303715884105727. Assignments are safe snapshots of
/// immutable state; parsing supports the minimum value without signed overflow.
#derive(Debug, Eq)
pub struct Int128 {
  priv bits : UInt128
}

///|
/// Interprets all 128 bits as a signed two's-complement value, without mutation.
/// Every bit pattern is valid; the top bit of the high word is the sign bit.
pub fn Int128::from_bits(bits : UInt128) -> Int128 {
  { bits, }
}

///|
/// Returns the exact two's-complement bit pattern as an immutable `UInt128`.
/// Negative values retain their sign bit; this is not an absolute magnitude.
pub fn Int128::to_bits(self : Int128) -> UInt128 {
  self.bits
}

///|
/// Reports whether the value is strictly negative, without mutation or failure.
/// Zero has a clear sign bit and returns false.
pub fn Int128::is_negative(self : Int128) -> Bool {
  self.bits.high >> 63 != 0
}

///|
/// Returns the exact signed decimal representation, including the minimum value.
/// Positive values have no `+`; zero is `"0"`. Formatting allocates a string
/// and never changes the value or narrows it to a 64-bit or floating-point type.
pub fn Int128::to_string(self : Int128) -> String {
  if self.is_negative() {
    "-" + self.bits.negated_bits().to_string()
  } else {
    self.bits.to_string()
  }
}

///|
/// Compares two unsigned word pairs by their high word before their low word.
#inline
fn UInt128::greater_than(self : UInt128, other : UInt128) -> Bool {
  self.high > other.high || (self.high == other.high && self.low > other.low)
}

///|
/// Divides four base-2^32 limbs by a nonzero small divisor without losing bits.
fn UInt128::divide_small(self : UInt128, divisor : UInt64) -> (UInt128, UInt64) {
  let first = self.high >> 32
  let second = ((first % divisor) << 32) | (self.high & 0xFFFFFFFFUL)
  let third = ((second % divisor) << 32) | (self.low >> 32)
  let fourth = ((third % divisor) << 32) | (self.low & 0xFFFFFFFFUL)
  (
    {
      high: ((first / divisor) << 32) | (second / divisor),
      low: ((third / divisor) << 32) | (fourth / divisor),
    },
    fourth % divisor,
  )
}

///|
/// Appends at most eight digits using base-2^32 carries and checks 128-bit overflow.
fn UInt128::append_small(
  self : UInt128,
  multiplier : UInt64,
  addition : UInt64,
  input : BytesView,
) -> UInt128 raise ParseError {
  let first = (self.low & 0xFFFFFFFFUL) * multiplier + addition
  let second = (self.low >> 32) * multiplier + (first >> 32)
  let third = (self.high & 0xFFFFFFFFUL) * multiplier + (second >> 32)
  let fourth = (self.high >> 32) * multiplier + (third >> 32)
  guard fourth <= 0xFFFFFFFFUL else { raise Overflow(input) }
  {
    high: (fourth << 32) | (third & 0xFFFFFFFFUL),
    low: (second << 32) | (first & 0xFFFFFFFFUL),
  }
}

///|
/// Computes modular two's-complement negation, including the signed minimum.
fn UInt128::negated_bits(self : UInt128) -> UInt128 {
  {
    high: 0UL - self.high - (if self.low == 0 { 0UL } else { 1UL }),
    low: 0UL - self.low,
  }
}
