///|
/// Finds the first exact occurrence of `needle` in `text`. The result is a
/// view-relative UTF-16 code-unit offset, or `None` on a miss. An empty needle
/// matches at zero. Long views can use SIMD on native and linear-memory Wasm.
pub fn find(text : StringView, needle : StringView) -> Int32? {
  match needle.length() {
    0 => Some(0)
    1 => find_code_unit(text, needle.unsafe_get(0))
    2 => find_pair(text, needle, reverse=false)
    len =>
      if text.length() - len < 15 {
        text.find(needle)
      } else {
        find_substring(text, needle, reverse=false)
      }
  }
}

///|
/// Finds the last exact occurrence of `needle` in `text`. The result is a
/// view-relative UTF-16 code-unit offset, or `None` on a miss. An empty needle
/// matches at the view length. Overlapping occurrences are eligible.
pub fn rev_find(text : StringView, needle : StringView) -> Int32? {
  match needle.length() {
    0 => Some(text.length())
    1 => rev_find_code_unit(text, needle.unsafe_get(0))
    2 => find_pair(text, needle, reverse=true)
    len =>
      if text.length() - len < 15 {
        text.rev_find(needle)
      } else {
        find_substring(text, needle, reverse=true)
      }
  }
}

///|
/// Returns the first view-relative offset of `code`, or `None` on a miss.
/// A code unit can be either half of a surrogate pair.
pub fn find_code_unit(text : StringView, code : UInt16) -> Int32? {
  scan_code_unit(text, code, reverse=false)
}

///|
/// Returns the last view-relative offset of `code`, or `None` on a miss.
/// A code unit can be either half of a surrogate pair.
pub fn rev_find_code_unit(text : StringView, code : UInt16) -> Int32? {
  scan_code_unit(text, code, reverse=true)
}

///|
/// Reports whether `needle` occurs in `text` as an exact UTF-16 code-unit
/// sequence. An empty needle is always present.
pub fn contains(text : StringView, needle : StringView) -> Bool {
  find(text, needle) is Some(_)
}

///|
/// Searches with the backend's core implementation when no local V128 kernel is available.
#cfg(not(any(target="native", target="wasm")))
fn scan_code_unit(text : StringView, code : UInt16, reverse~ : Bool) -> Int32? {
  if reverse {
    text.rev_find_code_unit(code)
  } else {
    text.find_code_unit(code)
  }
}

///|
/// Uses core's search when no local V128 kernel is available.
#cfg(not(any(target="native", target="wasm")))
fn find_substring(
  text : StringView,
  needle : StringView,
  reverse~ : Bool,
) -> Int32? {
  if reverse {
    text.rev_find(needle)
  } else {
    text.find(needle)
  }
}

///|
/// Uses core's pair search on backends without a local vector kernel.
#cfg(not(any(target="native", target="wasm")))
#inline
fn find_pair(text : StringView, needle : StringView, reverse~ : Bool) -> Int32? {
  if reverse {
    text.rev_find(needle)
  } else {
    text.find(needle)
  }
}
