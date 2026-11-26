///|
/// Maps sign-and-magnitude half bits to signed order, identifying both zeroes.
fn half_order(bits : UInt16) -> Int32 {
  let word = bits.to_int()
  if (word & 0x8000) != 0 {
    -(word & 0x7fff)
  } else {
    word
  }
}

///|
/// Inverts half ordinals during vector reduction, choosing positive zero.
#cfg(any(target="native", target="wasm"))
fn half_bits(ordinal : UInt16) -> UInt16 {
  let value = Int16::reinterpret_from_uint16(ordinal).to_int()
  (if value < 0 { 0x8000 - value } else { value }).to_uint16()
}

///|
/// An immutable IEEE 754 binary16 value preserving all original bits.
/// Construct from a raw `UInt16`; no rounding or implicit conversion occurs.
/// Searches ignore or propagate NaNs as requested and treat signed zeroes as
/// equal. Assignment aliases are safe because this value has no mutable state.
#derive(Debug)
pub struct Float16 {
  priv bits : UInt16
}

///|
/// Constructs a binary16 value from its exact bits, including all NaN payloads.
/// Every bit pattern is accepted on all backends; the result is immutable.
pub fn Float16::from_bits(bits : UInt16) -> Float16 {
  { bits, }
}

///|
/// Returns the exact input bits, including the sign of zero and the original
/// NaN payload. The result can be passed to `from_bits` to reconstruct the value.
pub fn Float16::to_bits(self : Float16) -> UInt16 {
  self.bits
}

///|
/// Reports whether the binary16 exponent is all ones and the fraction is
/// nonzero. This includes signaling NaNs of either sign. Infinity returns false.
pub fn Float16::is_nan(self : Float16) -> Bool {
  (self.bits.to_int() & 0x7fff) > 0x7c00
}

///|
/// Widens binary16 to `Double` exactly for finite values and signed zero.
/// Infinities retain their sign. NaN payload bits are shifted to the binary64
/// fraction; backend floating-point operations may subsequently canonicalize
/// them. The stored bits are never changed and no rounding is required.
///
/// ```mbt check
/// test {
///   assert_eq(@argminmax.Float16::from_bits(0x3E00).to_double(), 1.5)
///   assert_true(@argminmax.Float16::from_bits(0x7C01).is_nan())
/// }
/// ```
pub fn Float16::to_double(self : Float16) -> Double {
  let word = self.bits.to_uint()
  let sign = (word.to_uint64() & 0x8000UL) << 48
  let exponent = (word >> 10) & 31U
  let fraction = word & 1023U
  let raw = if exponent == 31U {
    sign | 0x7ff0000000000000UL | (fraction.to_uint64() << 42)
  } else if exponent != 0U {
    sign |
    ((exponent.to_uint64() + 1008UL) << 52) |
    (fraction.to_uint64() << 42)
  } else if fraction == 0U {
    sign
  } else {
    let top = 31 - fraction.clz()
    sign |
    ((999 + top).to_uint64() << 52) |
    ((fraction ^ (1U << top)).to_uint64() << (52 - top))
  }
  raw.reinterpret_as_double()
}

///|
/// Compares binary16 values for numeric equality. The two zero encodings
/// compare equal. If either operand is NaN, equality returns false.
pub impl Eq for Float16 with fn equal(self, other) {
  !self.is_nan() &&
  !other.is_nan() &&
  half_order(self.bits) == half_order(other.bits)
}

///|
/// Returns a negative, zero, or positive result according to binary16 numeric
/// order for non-NaNs. Both zero encodings compare as zero. NaN bit patterns
/// are ordered outside the infinities by this implementation, and extrema
/// searches apply their own NaN policy before comparing.
pub impl Compare for Float16 with fn compare(self, other) {
  half_order(self.bits).compare(half_order(other.bits))
}

///|
/// An immutable bfloat16 value preserving its sign, exponent, and NaN payload.
/// This uses eight exponent and seven fraction bits. Construct from raw bits;
/// searches implement the same NaN and signed-zero semantics as `Float16`.
/// Shared assignments are safe because there is no mutable state.
#derive(Debug)
pub struct BFloat16 {
  priv bits : UInt16
}

///|
/// Constructs bfloat16 from exact bits, accepting all finite and NaN patterns.
/// The result is immutable and construction works on all backends.
pub fn BFloat16::from_bits(bits : UInt16) -> BFloat16 {
  { bits, }
}

///|
/// Returns the exact input bits, including the sign of zero and the original
/// NaN payload. Use `from_bits` to reconstruct the value.
pub fn BFloat16::to_bits(self : BFloat16) -> UInt16 {
  self.bits
}

///|
/// Reports whether the bfloat16 exponent is all ones and the fraction is
/// nonzero. This includes signaling NaNs of either sign. Infinity returns false.
pub fn BFloat16::is_nan(self : BFloat16) -> Bool {
  (self.bits.to_int() & 0x7fff) > 0x7f80
}

///|
/// Widens bfloat16 exactly through its binary32 bit representation.
/// Finite values, signed zeroes, and infinities are exact. Floating-point
/// operations may canonicalize NaN payloads; the stored bits remain unchanged.
pub fn BFloat16::to_double(self : BFloat16) -> Double {
  Float::reinterpret_from_uint(self.bits.to_uint() << 16).to_double()
}

///|
/// Compares bfloat16 values for numeric equality. The two zero encodings
/// compare equal. If either operand is NaN, equality returns false.
pub impl Eq for BFloat16 with fn equal(self, other) {
  !self.is_nan() &&
  !other.is_nan() &&
  half_order(self.bits) == half_order(other.bits)
}

///|
/// Returns a negative, zero, or positive result according to bfloat16 numeric
/// order for non-NaNs. Both zero encodings compare as zero. NaN bit patterns
/// are ordered outside the infinities by this implementation, and extrema
/// searches apply their own NaN policy before comparing.
pub impl Compare for BFloat16 with fn compare(self, other) {
  half_order(self.bits).compare(half_order(other.bits))
}
