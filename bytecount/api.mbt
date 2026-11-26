///|
/// Counts occurrences of `needle` in the given byte view.
///
/// The input is borrowed and can include any byte values. The result is zero
/// for an empty view and at most the view length. The implementation selects
/// a vector or scalar kernel according to the backend and length.
///
/// ```mbt check
/// test {
///   assert_eq(@bytecount.count(b"one two three", b' '), 2)
/// }
/// ```
pub fn count(data : BytesView, needle : Byte) -> Int32 {
  count_fast(data, needle)
}

///|
/// Counts bytes outside the UTF-8 continuation-byte range `0x80..0xBF`.
///
/// For well-formed UTF-8, the result is the number of Unicode code points,
/// including a BOM if present. The function reads the view as-is without
/// validation, decoding, or copying. A malformed input still returns the
/// exact number of non-continuation bytes. An empty view returns zero.
///
/// ```mbt check
/// test {
///   assert_eq(@bytecount.num_chars(b"A\xC3\xA9\xF0\x9F\x98\x80"), 3)
/// }
/// ```
pub fn num_chars(data : BytesView) -> Int32 {
  num_chars_fast(data)
}

///|
/// Counts occurrences of `needle` in a byte view one byte at a time.
///
/// Accepts arbitrary bytes, borrows the view, and returns zero for empty input.
pub fn naive_count(data : BytesView, needle : Byte) -> Int32 {
  let start = data.start_offset()
  count_bytes(data.data(), start, start + data.length(), needle)
}

///|
/// Counts occurrences of `needle` with the same 32-bit loop as `naive_count`.
///
/// MoonBit view lengths fit in `Int32`, so the count is exact for every view.
/// The name corresponds to the upstream `naive_count_32` entry point.
pub fn naive_count_32(data : BytesView, needle : Byte) -> Int32 {
  naive_count(data, needle)
}

///|
/// Counts non-continuation bytes one byte at a time.
///
/// Like `num_chars`, this works on arbitrary byte views, returns zero for
/// empty input, and counts code points on well-formed UTF-8.
pub fn naive_num_chars(data : BytesView) -> Int32 {
  let start = data.start_offset()
  count_chars(data.data(), start, start + data.length())
}
