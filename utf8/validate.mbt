///|
/// Checks strict UTF-8 without constructing a string or reporting error details.
/// Empty input, embedded NUL, and a UTF-8 BOM are valid. Overlong encodings,
/// surrogate encodings, values above U+10FFFF, and incomplete suffixes are invalid.
/// Only `data` is read; unaligned views are supported and input is never mutated.
///
/// `simd=true` requests native vector range checks or the Wasm lookup3 algorithm
/// for inputs of at least 64 bytes. Shorter inputs, Wasm GC, and JavaScript
/// use scalar validation. The vector path aggregates errors over the full input,
/// like simdutf8's basic flavor; the scalar fallback may stop at the first error.
///
/// ```mbt check
/// test {
///   assert_true(@utf8.is_valid(b"\xE2\x9D\xA4"))
///   assert_true(!@utf8.is_valid(b"\xED\xA0\x80"))
/// }
/// ```
pub fn is_valid(data : BytesView, simd~ : Bool = true) -> Bool {
  if simd && data.length() >= 64 {
    scan_simd(data, early=false) == -1
  } else {
    scalar_error(data) is None
  }
}

///|
/// Validates strict UTF-8 and raises the first Rust-compatible `Utf8Error`.
/// The error's offset is relative to `data`; `error_len=None` identifies an
/// incomplete final sequence. Validation neither allocates a string nor mutates
/// input. Empty input, embedded NUL, and BOM bytes are accepted.
///
/// With `simd=true`, native/Wasm inputs of at least 64 bytes use vector
/// validation and check errors after each block. A scalar scan around the first
/// failing block recovers the exact offset and length. Other cases use scalar
/// validation, preserving identical errors on all backends.
///
/// ```mbt check
/// test {
///   try @utf8.validate(b"a\xF0\x9Fa") catch {
///     error => {
///       assert_eq(error.valid_up_to(), 1)
///       assert_eq(error.error_len(), Some(2))
///     }
///   } noraise {
///     _ => fail("expected invalid UTF-8")
///   }
/// }
/// ```
pub fn validate(data : BytesView, simd~ : Bool = true) -> Unit raise Utf8Error {
  let start = if simd && data.length() >= 64 {
    let boundary = scan_simd(data, early=true)
    if boundary == -1 {
      return
    }
    pending_suffix_start(data[:boundary])
  } else {
    0
  }
  if scalar_error(data[start:]) is Some(Utf8Error(valid_up_to~, error_len~)) {
    raise Utf8Error(valid_up_to=start + valid_up_to, error_len~)
  }
}

///|
/// Validates UTF-8 and decodes it into an immutable MoonBit UTF-16 string.
/// Unlike Rust's borrowed `str`, the returned string owns decoded storage and
/// does not alias the byte buffer. Embedded NUL and a leading BOM are preserved.
/// Invalid input raises the same precise `Utf8Error` as `validate`.
///
/// `simd` controls validation only, with the same short-input and backend
/// fallbacks as `validate`. Decoding uses the installed core UTF-8 decoder after
/// successful validation and is an additional cost.
pub fn from_utf8(
  data : BytesView,
  simd~ : Bool = true,
) -> String raise Utf8Error {
  validate(data, simd~)
  @encoding.decode_lossy(data, ignore_bom=false)
}
