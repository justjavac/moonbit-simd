///|
/// Parses the four UUID spellings accepted by uuid-simd 0.8.0.
///
/// Accepts 32 hexadecimal digits, 8-4-4-4-12 hyphenated text, that hyphenated
/// text enclosed in one pair of braces, or prefixed by the exact lowercase
/// `urn:uuid:`. Hexadecimal digits may use mixed case. Whitespace, misplaced
/// hyphens, non-ASCII code units, and other wrappers raise `InvalidUuid`.
/// The input view is neither mutated nor retained. No version or variant
/// validation is performed. `Simd` falls back on Wasm GC and JavaScript.
pub fn parse(
  input : StringView,
  algorithm~ : Algorithm = Auto,
) -> Uuid raise UuidError {
  match input.length() {
    32 => parse_text_body(input, false, algorithm)
    36 => parse_text_body(input, true, algorithm)
    38 => {
      guard input[0] == '{' && input[37] == '}' else { raise InvalidUuid }
      parse_text_body(input[1:37], true, algorithm)
    }
    45 => {
      guard input[:9] == "urn:uuid:" else { raise InvalidUuid }
      parse_text_body(input[9:], true, algorithm)
    }
    _ => raise InvalidUuid
  }
}

///|
/// Parses exactly 32 ASCII hexadecimal code units, accepting mixed case.
///
/// Hyphens, braces, prefixes, whitespace, and non-ASCII values raise
/// `InvalidUuid`. Input views are read within their bounds and not retained.
/// All UUID bit patterns are accepted. `algorithm` controls the implementation;
/// SIMD requests use a scalar fallback on Wasm GC and JavaScript.
pub fn parse_simple(
  input : StringView,
  algorithm~ : Algorithm = Auto,
) -> Uuid raise UuidError {
  guard input.length() == 32 else { raise InvalidUuid }
  parse_text_body(input, false, algorithm)
}

///|
/// Parses exactly the 36-code-unit 8-4-4-4-12 ASCII UUID spelling.
///
/// Mixed-case hexadecimal digits are accepted; hyphens are required at offsets
/// 8, 13, 18, and 23. Invalid length, characters, or syntax raise `InvalidUuid`.
/// This method does not accept wrappers or enforce version/variant bits. It
/// neither mutates nor retains its input. SIMD requests fall back on GC/JS.
pub fn parse_hyphenated(
  input : StringView,
  algorithm~ : Algorithm = Auto,
) -> Uuid raise UuidError {
  guard input.length() == 36 else { raise InvalidUuid }
  parse_text_body(input, true, algorithm)
}

///|
/// Parses arbitrary bytes in the same four spellings as `parse`.
///
/// Requires ASCII hexadecimal text with exact lengths and wrapper spelling.
/// Invalid bytes, including high-bit bytes or embedded NUL, raise `InvalidUuid`.
/// No UTF-8 conversion is required; offsets count bytes and all loads stay
/// inside the supplied view. The input is not mutated or retained. SIMD
/// requests fall back on Wasm GC and JavaScript.
pub fn parse_bytes(
  input : BytesView,
  algorithm~ : Algorithm = Auto,
) -> Uuid raise UuidError {
  match input.length() {
    32 => parse_byte_body(input, false, algorithm)
    36 => parse_byte_body(input, true, algorithm)
    38 => {
      guard input[0] == b'{' && input[37] == b'}' else { raise InvalidUuid }
      parse_byte_body(input[1:37], true, algorithm)
    }
    45 => {
      guard input[:9] == b"urn:uuid:" else { raise InvalidUuid }
      parse_byte_body(input[9:], true, algorithm)
    }
    _ => raise InvalidUuid
  }
}

///|
/// Checks the hyphens before dispatching a length-checked UTF-16 body.
fn parse_text_body(
  input : StringView,
  hyphenated : Bool,
  algorithm : Algorithm,
) -> Uuid raise UuidError {
  if hyphenated {
    guard input[8] == '-' &&
      input[13] == '-' &&
      input[18] == '-' &&
      input[23] == '-' else {
      raise InvalidUuid
    }
  }
  if use_simd(algorithm) {
    parse_text_simd(input, hyphenated)
  } else {
    parse_text_scalar(input, hyphenated)
  }
}

///|
/// Checks the hyphens before dispatching a length-checked ASCII byte body.
fn parse_byte_body(
  input : BytesView,
  hyphenated : Bool,
  algorithm : Algorithm,
) -> Uuid raise UuidError {
  if hyphenated {
    guard input[8] == b'-' &&
      input[13] == b'-' &&
      input[18] == b'-' &&
      input[23] == b'-' else {
      raise InvalidUuid
    }
  }
  if use_simd(algorithm) {
    parse_bytes_simd(input, hyphenated)
  } else {
    parse_bytes_scalar(input, hyphenated)
  }
}

///|
/// Provides the scalar implementation for the unavailable text SIMD backend.
#cfg(not(any(target="native", target="wasm")))
fn parse_text_simd(
  input : StringView,
  hyphenated : Bool,
) -> Uuid raise UuidError {
  parse_text_scalar(input, hyphenated)
}

///|
/// Provides the scalar implementation for the unavailable byte SIMD backend.
#cfg(not(any(target="native", target="wasm")))
fn parse_bytes_simd(
  input : BytesView,
  hyphenated : Bool,
) -> Uuid raise UuidError {
  parse_bytes_scalar(input, hyphenated)
}
