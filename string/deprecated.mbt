///|
/// Legacy name for the built-in `StringView` type.
#deprecated("Use StringView instead.")
pub type View = StringView

///|
/// Constructs an owned string from Unicode scalar values in order.
#deprecated("Use String::from_array instead.")
#doc(hidden)
pub fn from_array(chars : ArrayView[Char]) -> String {
  String::from_array(chars)
}

///|
/// Consumes Unicode scalar values from an iterator to construct a string.
#deprecated("Use String::from_iter instead.")
#doc(hidden)
pub fn from_iter(iter : Iter[Char]) -> String {
  String::from_iter(iter)
}

///|
/// Consumes Unicode scalar values from an iterator to construct a string.
#deprecated("Use String::from_iter instead.")
#doc(hidden)
pub fn from_iterator(iter : Iter[Char]) -> String {
  String::from_iter(iter)
}

///|
/// Returns an empty string.
#deprecated("Use String::default instead.")
#doc(hidden)
pub fn default() -> String {
  ""
}
