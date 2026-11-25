///|
/// An invalid or incomplete UTF-8 sequence, with Rust-compatible byte offsets.
/// The representation is private; inspect it with `valid_up_to()` and
/// `error_len()`. Offsets are relative to the supplied view, not its backing
/// buffer. An incomplete suffix has no error length.
#derive(Eq, Debug)
suberror Utf8Error {
  Utf8Error(valid_up_to~ : Int32, error_len~ : Int32?)
}

///|
/// Returns the number of valid bytes before the first malformed sequence.
/// The offset identifies its leading byte, or the unexpected continuation byte.
/// It counts bytes rather than Unicode scalars or UTF-16 code units.
pub fn Utf8Error::valid_up_to(self : Utf8Error) -> Int32 {
  let Utf8Error(valid_up_to~, ..) = self
  valid_up_to
}

///|
/// Returns the malformed sequence's length, excluding the byte that interrupted
/// a valid prefix of a multibyte sequence. The result is `Some(1)`, `Some(2)`, or
/// `Some(3)` for invalid input and `None` for a potentially valid truncated
/// suffix. This matches `std::str::Utf8Error::error_len()` in Rust.
pub fn Utf8Error::error_len(self : Utf8Error) -> Int32? {
  let Utf8Error(error_len~, ..) = self
  error_len
}

///|
/// Displays the same invalid-versus-incomplete distinction as simdutf8 compat.
pub impl Show for Utf8Error with fn output(self, logger) {
  let Utf8Error(valid_up_to~, error_len~) = self
  match error_len {
    Some(length) =>
      logger.write_string(
        "invalid utf-8 sequence of \{length} bytes from index \{valid_up_to}",
      )
    None =>
      logger.write_string(
        "incomplete utf-8 byte sequence from index \{valid_up_to}",
      )
  }
}
