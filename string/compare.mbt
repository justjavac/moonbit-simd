///|
/// Reports whether the two views contain the same UTF-16 code units in order.
/// Empty views compare equal regardless of their backing strings.
pub fn equal(text : StringView, other : StringView) -> Bool {
  let len = text.length()
  len == other.length() && equal_range(text, 0, other, len)
}

///|
/// Reports whether `text` begins with the exact code units of `prefix`.
/// An empty prefix always matches.
pub fn has_prefix(text : StringView, prefix : StringView) -> Bool {
  let len = prefix.length()
  len <= text.length() && equal_range(text, 0, prefix, len)
}

///|
/// Reports whether `text` ends with the exact code units of `suffix`.
/// An empty suffix always matches.
pub fn has_suffix(text : StringView, suffix : StringView) -> Bool {
  let len = suffix.length()
  let start = text.length() - len
  start >= 0 && equal_range(text, start, suffix, len)
}

///|
/// Compares two bounded ranges from the original strings without constructing views.
#cfg(not(target="wasm"))
#inline
fn equal_range(
  text : StringView,
  start : Int32,
  other : StringView,
  len : Int32,
) -> Bool {
  let left = text.data()
  let right = other.data()
  let left_start = text.start_offset() + start
  let right_start = other.start_offset()
  (physical_equal(left, right) && left_start == right_start) ||
  compare_code_units(left, left_start, right, right_start, len)
}

///|
/// Compares bounded UTF-16 ranges with core's backend-specific primitive.
#cfg(not(any(target="wasm", target="js")))
#inline
fn compare_code_units(
  left : String,
  left_start : Int32,
  right : String,
  right_start : Int32,
  len : Int32,
) -> Bool {
  left.unsafe_range_equal(
    right,
    start=left_start,
    other_start=right_start,
    len~,
  )
}

///|
/// Uses JavaScript string equality after comparing a short prefix of a long range.
#cfg(target="js")
#inline
fn compare_code_units(
  left : String,
  left_start : Int32,
  right : String,
  right_start : Int32,
  len : Int32,
) -> Bool {
  if len < 32 {
    return left.unsafe_range_equal(
      right,
      start=left_start,
      other_start=right_start,
      len~,
    )
  }
  // The callers bound both ranges. JavaScript substrings retain raw code units
  // even when the range starts or ends inside a surrogate pair.
  left.unsafe_range_equal(
    right,
    start=left_start,
    other_start=right_start,
    len=4,
  ) &&
  left.unsafe_substring(start=left_start, end=left_start + len) ==
  right.unsafe_substring(start=right_start, end=right_start + len)
}
