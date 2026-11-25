///|
/// An immutable signed eight-bit value stored in two's-complement form.
/// MoonBit has no built-in `Int8`; construction checks -128 through 127.
/// Shared assignments are safe and searches never mutate this value.
#derive(Eq, Debug)
pub struct Int8 {
  priv bits : Byte
}

///|
/// Constructs an `Int8` from `value`, returning `None` outside -128 through 127.
/// No truncation, wrapping, or mutation occurs; this works on all backends.
pub fn Int8::from_int(value : Int32) -> Int8? {
  if value >= -128 && value <= 127 {
    Some({ bits: value.to_byte(), })
  } else {
    None
  }
}

///|
/// Interprets all eight bits of `bits` as a signed two's-complement integer.
/// Every input is valid; the result is immutable and backend-independent.
pub fn Int8::from_bits(bits : Byte) -> Int8 {
  { bits, }
}

///|
/// Returns the original two's-complement bits without conversion or mutation.
pub fn Int8::to_bits(self : Int8) -> Byte {
  self.bits
}

///|
/// Returns this value as an exact signed `Int` in -128 through 127.
pub fn Int8::to_int(self : Int8) -> Int32 {
  let value = self.bits.to_int()
  if value >= 128 {
    value - 256
  } else {
    value
  }
}

///|
/// Compares signed eight-bit values using their numeric order.
pub impl Compare for Int8 with fn compare(self, other) {
  self.to_int().compare(other.to_int())
}

///|
/// An immutable unsigned 128-bit integer represented by two exact 64-bit words.
/// `high` is the most significant word; no machine endianness is assumed.
/// Shared assignments are safe. Searches use exact scalar comparisons on every
/// backend, including JavaScript, and never convert these values to `Double`.
#derive(Eq, Debug)
pub struct UInt128 {
  priv high_word : UInt64
  priv low_word : UInt64
}

///|
/// Constructs an exact unsigned value `high * 2^64 + low` on all backends.
/// Every word pair is valid; the returned value is immutable.
pub fn UInt128::from_words(high~ : UInt64, low~ : UInt64) -> UInt128 {
  { high_word: high, low_word: low, }
}

///|
/// Widens `value` exactly to 128 bits with a zero high word.
pub fn UInt128::from_uint64(value : UInt64) -> UInt128 {
  UInt128::from_words(high=0UL, low=value)
}

///|
/// Returns the most significant 64 bits without changing this value.
pub fn UInt128::high(self : UInt128) -> UInt64 {
  self.high_word
}

///|
/// Returns the least significant 64 bits without changing this value.
pub fn UInt128::low(self : UInt128) -> UInt64 {
  self.low_word
}

///|
/// Orders unsigned 128-bit integers lexicographically by high and low words.
pub impl Compare for UInt128 with fn compare(self, other) {
  let high = self.high_word.compare(other.high_word)
  if high == 0 {
    self.low_word.compare(other.low_word)
  } else {
    high
  }
}

///|
/// An immutable signed 128-bit two's-complement integer with exact 64-bit words.
/// The high word is signed and the low word is unsigned. Shared assignments
/// are safe. Searches use scalar comparisons on every backend and preserve all
/// 128 bits, including in JavaScript; no floating-point conversion is used.
#derive(Eq, Debug)
pub struct Int128 {
  priv high_word : Int64
  priv low_word : UInt64
}

///|
/// Constructs the signed value `high * 2^64 + low` exactly on every backend.
/// Every word pair is valid and the result is immutable; the high word carries
/// the sign. This representation includes -2^127 and 2^127 - 1.
pub fn Int128::from_words(high~ : Int64, low~ : UInt64) -> Int128 {
  { high_word: high, low_word: low, }
}

///|
/// Sign-extends `value` exactly to an immutable 128-bit integer.
pub fn Int128::from_int64(value : Int64) -> Int128 {
  Int128::from_words(
    high=if value < 0L { -1L } else { 0L },
    low=value.reinterpret_as_uint64(),
  )
}

///|
/// Returns the signed most significant word without changing this value.
pub fn Int128::high(self : Int128) -> Int64 {
  self.high_word
}

///|
/// Returns the unsigned least significant word without changing this value.
pub fn Int128::low(self : Int128) -> UInt64 {
  self.low_word
}

///|
/// Compares signed high words first, then unsigned low words when equal.
pub impl Compare for Int128 with fn compare(self, other) {
  let high = self.high_word.compare(other.high_word)
  if high == 0 {
    self.low_word.compare(other.low_word)
  } else {
    high
  }
}

///|
/// Uses the default exact scalar search for unsigned 128-bit elements.
pub impl Element for UInt128

///|
/// Uses the default exact scalar search for signed 128-bit elements.
pub impl Element for Int128
