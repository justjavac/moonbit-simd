///|
/// An immutable signed eight-bit parsing result in the range -128 through 127.
///
/// MoonBit has no built-in signed eight-bit integer on the validated toolchain.
/// The representation is private and only range-checked parsing constructs it.
/// Shared assignments are safe because this type has no mutable state.
#derive(Debug, Eq)
pub struct Int8 {
  priv value : Int32
}

///|
/// Returns the exact signed value as MoonBit's 32-bit `Int`, without mutation.
/// All possible `Int8` values are representable and this conversion cannot fail.
pub fn Int8::to_int(self : Int8) -> Int32 {
  self.value
}

///|
/// Returns the signed base-ten representation without leading zeroes or `+`.
/// Zero is `"0"`; conversion allocates a string and never mutates the value.
pub fn Int8::to_string(self : Int8) -> String {
  self.value.to_string()
}
