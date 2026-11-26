///|
/// Encodes `input` into a newly allocated ASCII byte sequence.
///
/// Empty input returns empty bytes. Input views are read within their bounds.
/// `simd=true` requests V128 on native/Wasm, with a scalar short-input path
/// and scalar fallback on Wasm GC/JS. Panics if the encoded length overflows.
/// The input and configuration are unchanged; the returned bytes are independent.
pub fn Base64::encode(
  self : Base64,
  input : BytesView,
  simd~ : Bool = default_simd,
) -> Bytes {
  let output = FixedArray::make(self.encoded_length(input.length()), b'\x00')
  encode_dispatch(input, output, 0, self, simd)
  // The result owns this fresh array, with no mutable alias retained.
  output.unsafe_reinterpret_as_bytes()
}

///|
/// Encodes arbitrary bytes into a newly allocated ASCII String.
///
/// Uses the same padding, bounds, overflow, and SIMD policy as `encode`.
/// Binary input is never interpreted as text. The output is safe to retain.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @base64.standard.encode_to_string(b"hello world"),
///     "aGVsbG8gd29ybGQ=",
///   )
/// }
/// ```
pub fn Base64::encode_to_string(
  self : Base64,
  input : BytesView,
  simd~ : Bool = default_simd,
) -> String {
  try! @utf8.decode(self.encode(input, simd~))
}

///|
/// Writes encoded bytes at `offset` and returns the number of bytes written.
///
/// The default offset is zero. Raises `OutputTooSmall` for an invalid offset
/// or insufficient capacity, before changing the destination. Panics on size
/// overflow as `encoded_length` does. Bytes outside the written range remain
/// unchanged. Immutable `BytesView` input is independent of the mutable array.
/// Uses the same SIMD and fallback policy as `encode`.
pub fn Base64::encode_into(
  self : Base64,
  input : BytesView,
  output : FixedArray[Byte],
  offset~ : Int32 = 0,
  simd~ : Bool = default_simd,
) -> Int32 raise Base64Error {
  let length = self.encoded_length(input.length())
  output_range(output, offset, length)
  encode_dispatch(input, output, offset, self, simd)
  length
}

///|
/// Fully validates byte input without allocating decoded output or mutating input.
///
/// Raises `InvalidInput` for the wrong alphabet, any whitespace, malformed
/// padding, impossible length, or nonzero unused bits. Padded policies require
/// exact RFC 4648 padding; no-pad policies reject `=`. Empty input is valid.
/// Uses V128 with `simd=true` on native/Wasm and scalar fallback elsewhere.
pub fn Base64::check(
  self : Base64,
  input : BytesView,
  simd~ : Bool = default_simd,
) -> Unit raise Base64Error {
  let source = Raw(input)
  let (n, _) = decoded_shape(source, self.padding, false)
  decode_dispatch(source, n, empty_output, 0, self, false, false, simd)
}

///|
/// Decodes strictly validated Base64 bytes into an independent byte sequence.
///
/// The alphabet, padding, and error rules match `check`. No whitespace is
/// accepted. Raises `InvalidInput` without exposing partial output; input is
/// unchanged. SIMD processes full 16-character blocks on native/Wasm, with
/// scalar tails and fallback on Wasm GC/JS. Empty input returns empty bytes.
pub fn Base64::decode(
  self : Base64,
  input : BytesView,
  simd~ : Bool = default_simd,
) -> Bytes raise Base64Error {
  decode_allocated(Raw(input), self, false, simd)
}

///|
/// Decodes an ASCII StringView using the same strict rules as `decode`.
///
/// Reads UTF-16 code units directly, including a view's starting offset;
/// no UTF-8 materialization is needed. Every non-ASCII code unit is rejected.
/// Inputs and retained views remain unchanged. Raises `InvalidInput` without
/// exposing partial output; vector requests fall back on Wasm GC/JS.
///
/// ```mbt check
/// test {
///   assert_eq(@base64.url_safe_no_pad.decode_string("-_8"), b"\xfb\xff")
/// }
/// ```
pub fn Base64::decode_string(
  self : Base64,
  input : StringView,
  simd~ : Bool = default_simd,
) -> Bytes raise Base64Error {
  decode_allocated(Text(input), self, false, simd)
}

///|
/// Decodes bytes into `output` at `offset`, returning the number written.
///
/// The alphabet and strict validation match `decode`. An invalid structural
/// length or insufficient capacity raises before writing. A later alphabet
/// or tail-bit error can leave an already decoded prefix; its contents are
/// unspecified on error. On success, bytes outside the output range stay
/// unchanged. The input is immutable. Uses the same SIMD policy as `decode`.
pub fn Base64::decode_into(
  self : Base64,
  input : BytesView,
  output : FixedArray[Byte],
  offset~ : Int32 = 0,
  simd~ : Bool = default_simd,
) -> Int32 raise Base64Error {
  let source = Raw(input)
  let (n, length) = decoded_shape(source, self.padding, false)
  output_range(output, offset, length)
  decode_dispatch(source, n, output, offset, self, false, true, simd)
  length
}

///|
/// Decodes the first `length` bytes of `data` into its prefix, returning its size.
///
/// `length` defaults to the full array and must lie within its capacity.
/// The configuration's strict rules apply. Reads precede their overlapping
/// writes; no input copy is made. Only the returned prefix represents decoded
/// data; the unused suffix is unchanged on success. An `InvalidInput` can leave
/// a partially overwritten prefix. Array aliases observe writes. Uses the
/// same vector/tail/fallback policy as `decode`.
pub fn Base64::decode_inplace(
  self : Base64,
  data : FixedArray[Byte],
  length? : Int32,
  simd~ : Bool = default_simd,
) -> Int32 raise Base64Error {
  let source = inplace_input(data, length)
  let (n, decoded) = decoded_shape(source, self.padding, false)
  decode_dispatch(source, n, data, 0, self, false, true, simd)
  decoded
}

///|
/// Appends an encoded ASCII String to `output`, preserving its existing prefix.
///
/// Input is unchanged. The temporary encoded allocation and padding/overflow
/// and SIMD behavior are the same as `encode_to_string`. Builder aliases
/// observe the append; the configuration retains no builder reference.
pub fn Base64::encode_append(
  self : Base64,
  input : BytesView,
  output : StringBuilder,
  simd~ : Bool = default_simd,
) -> Unit {
  output.write_string(self.encode_to_string(input, simd~))
}

///|
/// Appends decoded bytes to `output` after validating all input.
///
/// Raises `InvalidInput` with the buffer unchanged. A temporary independent
/// byte sequence is allocated by `decode`; its strict and SIMD policies apply.
/// Buffer aliases observe a successful append; input remains unchanged.
pub fn Base64::decode_append(
  self : Base64,
  input : BytesView,
  output : @buffer.Buffer,
  simd~ : Bool = default_simd,
) -> Unit raise Base64Error {
  output.write_bytesview(self.decode(input, simd~))
}

///|
/// Provides a shared zero-sized destination for allocation-free validation.
let empty_output : FixedArray[Byte] = []

///|
/// Allocates exact decoded storage after the partial structural validation.
fn decode_allocated(
  input : Input,
  config : Base64,
  forgiving : Bool,
  simd : Bool,
) -> Bytes raise Base64Error {
  let (n, length) = decoded_shape(
    input,
    config.padding && !forgiving,
    forgiving,
  )
  let output = FixedArray::make(length, b'\x00')
  decode_dispatch(input, n, output, 0, config, forgiving, true, simd)
  // The result owns this fresh array, with no mutable alias retained.
  output.unsafe_reinterpret_as_bytes()
}
