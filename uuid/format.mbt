///|
/// Holds the scalar ASCII hexadecimal alphabets outside timed loops.
let lowercase : Bytes = b"0123456789abcdef"

///|
/// Holds the uppercase scalar alphabet outside timed loops.
let uppercase : Bytes = b"0123456789ABCDEF"

///|
/// Formats this UUID as exactly 32 ASCII hexadecimal characters.
///
/// `case` defaults to lowercase. The result owns immutable storage; the UUID
/// is unchanged. Every UUID bit pattern is representable and formatting cannot
/// fail. `Simd` falls back to scalar on Wasm GC and JavaScript. Allocation and
/// conversion of the ASCII output to a MoonBit string are included.
pub fn Uuid::format_simple(
  self : Uuid,
  case~ : AsciiCase = Lower,
  algorithm~ : Algorithm = Auto,
) -> String {
  format_text(self, false, case, algorithm)
}

///|
/// Formats this UUID as exactly 36 ASCII characters in 8-4-4-4-12 form.
///
/// Hexadecimal case defaults to lowercase. Hyphens occur at offsets 8, 13, 18,
/// and 23. The UUID is unchanged and the returned string is independent.
/// Formatting cannot fail. SIMD requests use scalar fallback on GC/JS;
/// allocation and ASCII-to-string conversion are part of this operation.
pub fn Uuid::format_hyphenated(
  self : Uuid,
  case~ : AsciiCase = Lower,
  algorithm~ : Algorithm = Auto,
) -> String {
  format_text(self, true, case, algorithm)
}

///|
/// Writes exactly 32 ASCII hexadecimal bytes into a reusable destination.
///
/// Writes `[offset, offset + 32)` and preserves all other bytes. Case defaults
/// to lowercase. Raises `InvalidBuffer` for negative offsets or insufficient
/// capacity before changing any byte. The UUID is unchanged, no destination
/// is retained, and the operation allocates no output buffer. SIMD requests
/// use scalar fallback on Wasm GC and JavaScript.
pub fn Uuid::write_simple(
  self : Uuid,
  destination : FixedArray[Byte],
  offset~ : Int32 = 0,
  case~ : AsciiCase = Lower,
  algorithm~ : Algorithm = Auto,
) -> Unit raise UuidError {
  check_destination(destination, offset, 32)
  write_unchecked(self, destination, offset, false, case, algorithm)
}

///|
/// Writes exactly 36 ASCII UUID bytes in 8-4-4-4-12 form.
///
/// Writes `[offset, offset + 36)` and preserves all other bytes, including
/// guards immediately outside the range. Raises `InvalidBuffer` before any
/// mutation for negative offsets or insufficient capacity. No buffer is
/// allocated or retained. The UUID is unchanged. Case defaults to lowercase;
/// SIMD requests use scalar fallback on Wasm GC and JavaScript.
pub fn Uuid::write_hyphenated(
  self : Uuid,
  destination : FixedArray[Byte],
  offset~ : Int32 = 0,
  case~ : AsciiCase = Lower,
  algorithm~ : Algorithm = Auto,
) -> Unit raise UuidError {
  check_destination(destination, offset, 36)
  write_unchecked(self, destination, offset, true, case, algorithm)
}

///|
/// Displays a UUID in lowercase hyphenated form.
pub impl Show for Uuid with fn output(self, logger) {
  logger.write_string(self.format_hyphenated())
}

///|
/// Makes the canonical display operation available through ordinary method syntax.
pub extend Uuid with Show::{to_string}

///|
/// Checks buffer bounds without overflowing offset-plus-length arithmetic.
fn check_destination(
  destination : FixedArray[Byte],
  offset : Int32,
  required : Int32,
) -> Unit raise UuidError {
  guard offset >= 0 && offset <= destination.length() - required else {
    raise InvalidBuffer(offset~, required~, length=destination.length())
  }
}

///|
/// Formats proven ASCII output and converts it to an owned MoonBit string.
fn format_text(
  uuid : Uuid,
  hyphenated : Bool,
  case : AsciiCase,
  algorithm : Algorithm,
) -> String {
  let length = if hyphenated { 36 } else { 32 }
  let output : FixedArray[Byte] = FixedArray::make(length, 0)
  write_unchecked(uuid, output, 0, hyphenated, case, algorithm)
  // The writer emits only ASCII digits, letters, and hyphens, so decoding
  // cannot fail; the checked decoder also preserves UTF-16 backend semantics.
  try! @utf8.decode(Bytes::from_array(output))
}

///|
/// Dispatches a checked output range to scalar or vector hexadecimal formatting.
fn write_unchecked(
  uuid : Uuid,
  destination : FixedArray[Byte],
  offset : Int32,
  hyphenated : Bool,
  case : AsciiCase,
  algorithm : Algorithm,
) -> Unit {
  if use_simd(algorithm) {
    write_simd(uuid, destination, offset, hyphenated, case)
  } else {
    write_scalar(uuid, destination, offset, hyphenated, case)
  }
}

///|
/// Writes a UUID with scalar nibble lookups into an already-checked output range.
fn write_scalar(
  uuid : Uuid,
  destination : FixedArray[Byte],
  offset : Int32,
  hyphenated : Bool,
  case : AsciiCase,
) -> Unit {
  let alphabet = if case == Lower { lowercase } else { uppercase }
  for i in 0..<32 {
    let word = if i < 16 { uuid.high } else { uuid.low }
    let nibble = ((word >> (4 * (15 - i % 16))) & 15).to_int()
    destination[offset + digit_position(i, hyphenated)] = alphabet[nibble]
  }
  if hyphenated {
    destination[offset + 8] = b'-'
    destination[offset + 13] = b'-'
    destination[offset + 18] = b'-'
    destination[offset + 23] = b'-'
  }
}

///|
/// Supplies scalar formatting where vector operations are unavailable.
#cfg(not(any(target="native", target="wasm")))
fn write_simd(
  uuid : Uuid,
  destination : FixedArray[Byte],
  offset : Int32,
  hyphenated : Bool,
  case : AsciiCase,
) -> Unit {
  write_scalar(uuid, destination, offset, hyphenated, case)
}
