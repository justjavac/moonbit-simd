///|
/// Counts occurrences of `needle` in the given byte view.
///
/// `data` may be a whole byte buffer or an unaligned subview. Each byte equal
/// to `needle` contributes one, including zero and bytes above ASCII. The
/// result is between zero and `data.length()` inclusive. The scan reads only
/// the view and creates no copy.
///
/// Native and linear-memory Wasm use vectors from 128 bytes. Shorter inputs
/// and Wasm GC use scalar word operations with a byte tail. JavaScript uses
/// scalar words from 128 bytes and a byte loop for shorter views.
///
/// ```mbt check
/// test {
///   let data = b"|one two three|"
///   assert_eq(@bytecount.count(data[1:14], b' '), 2)
/// }
/// ```
pub fn count(data : BytesView, needle : Byte) -> Int32 {
  count_fast(data, needle)
}

///|
/// Counts bytes outside the UTF-8 continuation-byte range `0x80..0xBF`.
///
/// For well-formed UTF-8, the result is the number of Unicode code points,
/// including a leading BOM and each combining mark. The same rule applies
/// byte by byte to malformed or truncated data. For example, a partial view
/// starting with a continuation byte skips that byte, and a truncated lead
/// byte at the end of a view still contributes one. Empty views return zero.
///
/// The scan borrows the input and produces only an integer. Native and
/// linear-memory Wasm use vectors from 128 bytes, Wasm GC uses scalar words,
/// and JavaScript uses a byte loop.
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
/// The input is the half-open range represented by `data`, and all 256
/// values of `needle` are accepted. Empty views return zero. This scalar
/// reference loop performs one comparison per byte on every backend,
/// with constant auxiliary space and borrowed input.
pub fn naive_count(data : BytesView, needle : Byte) -> Int32 {
  let start = data.start_offset()
  count_bytes(data.data(), start, start + data.length(), needle)
}

///|
/// Counts occurrences of `needle` with the same 32-bit loop as `naive_count`.
///
/// This is the upstream compatibility spelling of `naive_count`. It uses
/// an `Int32` accumulator, which represents every possible count in a
/// MoonBit `BytesView`. It accepts arbitrary bytes, reads only the view,
/// and returns zero for empty input on every backend.
pub fn naive_count_32(data : BytesView, needle : Byte) -> Int32 {
  naive_count(data, needle)
}

///|
/// Counts non-continuation bytes one byte at a time.
///
/// A byte contributes one exactly when its top two bits differ from `10`.
/// This gives the code point count for valid UTF-8 and the same byte
/// classification as `num_chars` for arbitrary input. The loop examines each
/// byte of `data` once on every backend and returns zero for an empty view.
pub fn naive_num_chars(data : BytesView) -> Int32 {
  let start = data.start_offset()
  count_chars(data.data(), start, start + data.length())
}
