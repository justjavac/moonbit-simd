///|
/// Decimal validation failures, retaining immutable snapshots of input views.
///
/// `Empty` means no digit follows the optional sign, including an invalid first
/// byte. `Size(length, input)` reports the observed digit prefix when it first
/// exceeds a 64/128-bit digit budget; `length` includes skipped zeroes.
/// `Overflow(input)` means a permitted-length prefix exceeds the result range.
/// `Invalid64(magnitude, index, input)` and `Invalid128(...)` report a non-digit
/// suffix in a complete parse, retaining the unsigned prefix magnitude.
///
/// Stored input excludes an accepted sign and preserves its original byte view
/// even when zeroes were skipped. `index` is relative to that stored view, not
/// its backing buffer. Error precedence is size, overflow, then invalid suffix.
/// No error mutates the input; retaining an error may retain its backing bytes.
#derive(Debug, Eq)
pub(all) suberror ParseError {
  /// No digit was found at the start of the digit view.
  Empty
  /// Carries the observed digit prefix length and the original sign-free view.
  /// The length includes accepted leading zeroes.
  Size(Int32, BytesView)
  /// Carries the sign-free view of a value outside the requested integer range.
  Overflow(BytesView)
  /// Carries the valid prefix's unsigned magnitude, the index of the first
  /// non-digit, and the sign-free input view for results up to 64 bits.
  Invalid64(UInt64, Int32, BytesView)
  /// Carries the corresponding magnitude, byte index, and view for 128-bit
  /// results. The magnitude is exact even when it exceeds 64 bits.
  Invalid128(UInt128, Int32, BytesView)
}
