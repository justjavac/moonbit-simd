///|
/// Selects UUID parsing and formatting implementations. All choices have
/// the same accepted input, output, and error semantics.
#derive(Eq, Debug)
pub(all) enum Algorithm {
  /// Uses vectors on linear-memory Wasm and scalar code on other backends.
  Auto
  /// Uses the scalar implementation on every backend.
  Scalar
  /// Uses vectors on native and linear-memory Wasm and scalar fallback elsewhere.
  Simd
}

///|
/// Selects lowercase or uppercase ASCII hexadecimal output.
///
/// Parsing accepts either case independently of this formatting option.
#derive(Eq, Debug)
pub(all) enum AsciiCase {
  /// Writes hexadecimal letters as ASCII `a..f`. This is the default.
  Lower
  /// Writes hexadecimal letters as ASCII `A..F`.
  Upper
}

///|
/// Reports invalid UUID text, binary lengths, or destination buffer ranges.
///
/// Text parsers report a single syntax error for malformed UUIDs. Binary
/// conversion and destination writes provide the lengths involved.
#derive(Eq, Debug)
pub(all) suberror UuidError {
  /// Invalid UUID text length, wrapper, hyphen placement, or hexadecimal digit.
  InvalidUuid
  /// Binary input length in bytes when it differs from the required 16.
  InvalidByteLength(Int32)
  /// The requested byte offset and write size do not fit the destination length.
  /// The write fails before it mutates the destination.
  InvalidBuffer(offset~ : Int32, required~ : Int32, length~ : Int32)
}

///|
/// An immutable UUID stored as two unsigned words in network byte order.
///
/// Equality, ordering, and hashing use all 128 bits. Any bit pattern is accepted;
/// parsing does not enforce a particular UUID version or variant. Representation
/// is private. Assignments safely share immutable state, and constructors retain
/// no mutable buffers or input views. Returned text and bytes are independent
/// immutable values on every backend.
#derive(Eq, Compare, Hash, Debug)
pub struct Uuid {
  priv high : UInt64
  priv low : UInt64
}

///|
/// Constructs a UUID from exactly sixteen bytes in network order.
///
/// The first eight bytes form the high word. Offset views are accepted and no
/// bytes outside the view are read. Raises `InvalidByteLength` otherwise. The
/// input is not mutated or retained; no version or variant bits are rewritten.
pub fn Uuid::from_bytes(input : BytesView) -> Uuid raise UuidError {
  guard input.length() == 16 else { raise InvalidByteLength(input.length()) }
  for i in 0..<8; high = 0UL, low = 0UL {
    continue (high << 8) | input[i].to_uint64(),
      (low << 8) | input[i + 8].to_uint64()
  } nobreak {
    { high, low, }
  }
}

///|
/// Returns the UUID's sixteen bytes in network order.
///
/// The result owns its immutable storage and shares no mutable destination
/// buffer. Windows GUID field endianness is not applied. This method cannot
/// fail and has the same byte order on every backend.
///
/// ```mbt check
/// test {
///   let pattern = b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F"
///   let uuid = @uuid.Uuid::from_bytes(pattern)
///   assert_eq(uuid.to_bytes(), pattern)
///   assert_eq(uuid.format_simple(), "000102030405060708090a0b0c0d0e0f")
/// }
/// ```
pub fn Uuid::to_bytes(self : Uuid) -> Bytes {
  Bytes::makei(16, i => {
    let word = if i < 8 { self.high } else { self.low }
    (word >> (8 * (7 - i % 8))).to_byte()
  })
}

///|
/// Reports whether a SIMD request can use V128 operations on this backend.
///
/// Returns true for native and linear-memory Wasm, false for Wasm GC and
/// JavaScript. This describes the compiled implementation, not optional CPU
/// feature detection or the `Auto` policy.
#cfg(any(target="native", target="wasm"))
pub fn simd_available() -> Bool {
  true
}

///|
/// Reports whether a SIMD request can use V128 operations on this backend.
///
/// Wasm GC and JavaScript use a scalar fallback and return false. This query
/// does not allocate, mutate state, or test optional processor instructions.
#cfg(not(any(target="native", target="wasm")))
pub fn simd_available() -> Bool {
  false
}

///|
/// Resolves an algorithm request to the backend's available implementation.
#cfg(target="wasm")
#inline
fn use_simd(algorithm : Algorithm) -> Bool {
  algorithm != Scalar
}

///|
/// Uses the native scalar default while retaining an explicit measured SIMD path.
#cfg(target="native")
#inline
fn use_simd(algorithm : Algorithm) -> Bool {
  // Whole-operation local measurements favor scalar for native byte parsing
  // and buffer writes; the explicit vector request remains independently tested.
  algorithm == Simd
}

///|
/// Resolves requests to scalar behavior on backends without V128 support.
#cfg(not(any(target="native", target="wasm")))
#inline
fn use_simd(_algorithm : Algorithm) -> Bool {
  false
}
