///|
/// Returns the first byte offset of `needle` in `haystack`, or `None` if absent.
/// Empty input has no match. Offsets are relative to the supplied view; arbitrary
/// bytes, NUL, and unaligned views are supported without mutation or decoding.
/// `simd=true` uses complete sixteen-byte vectors on native/linear-memory Wasm;
/// shorter input and Wasm GC use SWAR/tails; JavaScript uses byte comparisons.
///
/// ```mbt check
/// test {
///   assert_eq(@memchr.memchr(b'o', b"foo bar"), Some(1))
///   assert_eq(@memchr.memchr(b'x', b"foo bar"), None)
/// }
/// ```
pub fn memchr(
  needle : Byte,
  haystack : BytesView,
  simd~ : Bool = true,
) -> Int32? {
  search_bytes(One(needle), haystack, reverse=false, simd~)
}

///|
/// Returns the last byte offset of `needle` in `haystack`, or `None` if absent.
/// Empty input has no match. Input is read without mutation, decoding, or view
/// overreads. `simd` requests the same bounded vectors and fallbacks as `memchr`.
pub fn memrchr(
  needle : Byte,
  haystack : BytesView,
  simd~ : Bool = true,
) -> Int32? {
  search_bytes(One(needle), haystack, reverse=true, simd~)
}

///|
/// Returns the first offset matching either byte, or `None` for absent/empty input.
/// Needle order and duplicates do not affect results. Offsets are relative to
/// `haystack`; input is never mutated. `simd` has the same meaning as in `memchr`.
pub fn memchr2(
  needle1 : Byte,
  needle2 : Byte,
  haystack : BytesView,
  simd~ : Bool = true,
) -> Int32? {
  search_bytes(Two(needle1, needle2), haystack, reverse=false, simd~)
}

///|
/// Returns the last offset matching either byte, or `None` for absent/empty input.
/// Duplicates are accepted. Only the supplied view is read and offsets are byte
/// offsets within it. `simd` selects the same vectors/fallbacks as `memchr`.
pub fn memrchr2(
  needle1 : Byte,
  needle2 : Byte,
  haystack : BytesView,
  simd~ : Bool = true,
) -> Int32? {
  search_bytes(Two(needle1, needle2), haystack, reverse=true, simd~)
}

///|
/// Returns the first offset matching any of three bytes, or `None` if absent.
/// Empty input has no match; duplicates and arbitrary byte values are accepted.
/// Input is read without mutation or overreads. `simd` follows `memchr` dispatch.
pub fn memchr3(
  needle1 : Byte,
  needle2 : Byte,
  needle3 : Byte,
  haystack : BytesView,
  simd~ : Bool = true,
) -> Int32? {
  search_bytes(Three(needle1, needle2, needle3), haystack, reverse=false, simd~)
}

///|
/// Returns the last offset matching any of three bytes, or `None` if absent.
/// Empty input has no match. Duplicate needles produce one match per byte.
/// Offsets are view-relative bytes; `simd` follows the bounded `memchr` dispatch.
pub fn memrchr3(
  needle1 : Byte,
  needle2 : Byte,
  needle3 : Byte,
  haystack : BytesView,
  simd~ : Bool = true,
) -> Int32? {
  search_bytes(Three(needle1, needle2, needle3), haystack, reverse=true, simd~)
}
