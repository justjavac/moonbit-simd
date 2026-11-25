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
/// Returns the original binary16 bits without normalization or mutation.
pub fn Float16::to_bits(self : Float16) -> UInt16 {
  self.bits
}

///|
/// Detects binary16 NaNs, including signaling NaNs and either sign.
pub fn Float16::is_nan(self : Float16) -> Bool {
  (self.bits.to_int() & 0x7fff) > 0x7c00
}

///|
/// Widens binary16 to `Double` exactly for finite values and signed zero.
/// Infinities retain their sign. NaN payload bits are shifted to the binary64
/// fraction; backend floating-point operations may subsequently canonicalize
/// them. The stored bits are never changed and no rounding is required.
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
/// Implements numeric equality, with signed zero equal and every NaN unequal.
pub impl Eq for Float16 with fn equal(self, other) {
  !self.is_nan() &&
  !other.is_nan() &&
  half_order(self.bits) == half_order(other.bits)
}

///|
/// Compares ordered binary16 values via their exact signed ordinal bits.
/// NaNs lie outside the infinity ordinals; searches classify them separately.
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
/// Returns the original bfloat16 bits without normalization or mutation.
pub fn BFloat16::to_bits(self : BFloat16) -> UInt16 {
  self.bits
}

///|
/// Detects bfloat16 NaNs of either sign, including signaling encodings.
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
/// Implements numeric equality, identifying signed zero and rejecting NaN ties.
pub impl Eq for BFloat16 with fn equal(self, other) {
  !self.is_nan() &&
  !other.is_nan() &&
  half_order(self.bits) == half_order(other.bits)
}

///|
/// Compares bfloat16 values through their signed ordinal bit representation.
/// Searches classify NaNs before comparing their otherwise unordered values.
pub impl Compare for BFloat16 with fn compare(self, other) {
  half_order(self.bits).compare(half_order(other.bits))
}
