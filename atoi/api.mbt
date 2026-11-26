///|
/// A fixed-width decimal result supported by the generic parsing functions.
///
/// Implemented for `Byte`, `Int8`, `UInt16`, `Int16`, `UInt`, `Int`, `UInt64`,
/// `Int64`, `UInt128`, and `Int128`. Type annotations select the result type.
/// Implementations must enforce their integer range before returning a value.
pub(open) trait Parse {
  /// Parses `data` without mutation and returns the value and consumed bytes.
  /// `positive_only` rejects both signs; otherwise signed types accept `-` and
  /// `skip_plus` permits one `+`. `prefix` permits a non-digit suffix.
  /// `skip_zeroes` removes leading zeroes from the 64/128-bit size budget;
  /// narrower types accept arbitrarily many leading zeroes in either mode.
  /// `simd` requests checked sixteen-byte digit vectors on native and
  /// linear-memory Wasm. Leading-zero removal, short inputs, and other
  /// backends use scalar or SWAR processing.
  /// Failures raise `ParseError` and leave the input unchanged.
  fn parse_decimal(
    BytesView,
    positive_only~ : Bool,
    prefix~ : Bool,
    skip_zeroes~ : Bool,
    skip_plus~ : Bool,
    simd~ : Bool,
  ) -> (Self, Int32) raise ParseError
}

///|
/// A signed decimal result supported by the sign-free negative parsers.
///
/// Implemented only for `Int8`, `Int16`, `Int`, `Int64`, and `Int128`, so an
/// unsigned result cannot be requested from `parse_neg` or `parse_prefix_neg`.
pub(open) trait ParseNeg {
  /// Parses sign-free ASCII digits as a negative value, including the minimum
  /// representable integer. `prefix` permits a non-digit suffix; `skip_zeroes`
  /// and `simd` have the same meaning as in `Parse::parse_decimal`.
  /// Returns the value and consumed bytes, including skipped zeroes. Empty
  /// digit prefixes, size violations, overflow, and forbidden suffixes raise
  /// `ParseError`. The input is never mutated or copied.
  fn parse_negative_decimal(
    BytesView,
    prefix~ : Bool,
    skip_zeroes~ : Bool,
    simd~ : Bool,
  ) -> (Self, Int32) raise ParseError
}

///|
/// Parses all of `data` as a decimal integer of the annotated result type.
///
/// Signed types accept one leading `-`; unsigned types reject it, including
/// `-0`. `skip_plus=true` permits one leading `+`. Only ASCII `0` through `9`
/// are digits: whitespace, separators, radix prefixes, and Unicode digits are
/// rejected. By default both skip options are false. With
/// `skip_zeroes=true`, the leading zeroes of a 64- or 128-bit result are
/// excluded from the digit budget. The budgets are 19 for `Int64`, 20 for
/// `UInt64`, and 39 for both 128-bit types. Narrower types always permit
/// arbitrarily many leading zeroes and check overflow against their range.
///
/// Raises `ParseError` for an empty digit prefix, excessive size, overflow, or
/// a non-digit suffix. Error indices are relative to the stored input view,
/// which excludes an accepted sign. The immutable view is never materialized.
/// `simd=true` requests vectors for complete sixteen-byte blocks on native and
/// linear-memory Wasm; short inputs, Wasm GC, and JavaScript use scalar/SWAR.
/// Leading-zero removal uses scalar/SWAR even when vectors are requested.
///
/// ```mbt check
/// test {
///   let value : Int64 = @atoi.parse(b"-9223372036854775808")
///   assert_eq(value, -9223372036854775808L)
/// }
/// ```
pub fn[T : Parse] parse(
  data : BytesView,
  skip_zeroes~ : Bool = false,
  skip_plus~ : Bool = false,
  simd~ : Bool = true,
) -> T raise ParseError {
  let (value, _) = T::parse_decimal(
    data,
    positive_only=false,
    prefix=false,
    skip_zeroes~,
    skip_plus~,
    simd~,
  )
  value
}

///|
/// Parses all of `data` as a nonnegative decimal integer, rejecting both signs.
///
/// The annotated result may be signed or unsigned. Digits, range checks,
/// leading-zero budgets, failures, view ownership, and SIMD fallback match
/// `parse`. `skip_zeroes` permits unlimited leading zeroes for 64/128-bit types.
/// No whitespace, sign, radix prefix, or suffix is accepted; failure raises
/// `ParseError` without changing the input.
pub fn[T : Parse] parse_pos(
  data : BytesView,
  skip_zeroes~ : Bool = false,
  simd~ : Bool = true,
) -> T raise ParseError {
  let (value, _) = T::parse_decimal(
    data,
    positive_only=true,
    prefix=false,
    skip_zeroes~,
    skip_plus=false,
    simd~,
  )
  value
}

///|
/// Parses sign-free ASCII digits as a negative integer of a signed result type.
///
/// A leading `-` or `+` is rejected. Zero returns zero; the minimum signed
/// value is accepted without first converting its magnitude to a signed type.
/// `skip_zeroes`, range/size failures, immutable views, and SIMD fallbacks match
/// `parse`. The entire view must be digits; otherwise `ParseError` is raised.
///
/// ```mbt check
/// test {
///   let value : @atoi.Int8 = @atoi.parse_neg(b"128")
///   assert_eq(value.to_int(), -128)
/// }
/// ```
pub fn[T : ParseNeg] parse_neg(
  data : BytesView,
  skip_zeroes~ : Bool = false,
  simd~ : Bool = true,
) -> T raise ParseError {
  let (value, _) = T::parse_negative_decimal(
    data,
    prefix=false,
    skip_zeroes~,
    simd~,
  )
  value
}

///|
/// Parses a decimal prefix and returns its value and consumed byte count.
///
/// Sign handling, leading-zero budgets, range checks, and SIMD fallback match
/// `parse`. Consumption includes an accepted sign and every leading zero;
/// the first non-digit and remaining suffix are excluded. At least one digit
/// is required. The complete digit prefix is checked: overflow or excessive
/// size raises `ParseError` rather than returning a truncated integer.
/// No input is mutated or materialized, and indices are byte offsets.
///
/// ```mbt check
/// test {
///   let result : (UInt64, Int32) = @atoi.parse_prefix(b"+123rest", skip_plus=true)
///   assert_eq(result, (123UL, 4))
/// }
/// ```
pub fn[T : Parse] parse_prefix(
  data : BytesView,
  skip_zeroes~ : Bool = false,
  skip_plus~ : Bool = false,
  simd~ : Bool = true,
) -> (T, Int32) raise ParseError {
  T::parse_decimal(
    data,
    positive_only=false,
    prefix=true,
    skip_zeroes~,
    skip_plus~,
    simd~,
  )
}

///|
/// Parses a sign-free nonnegative decimal prefix and returns consumed bytes.
///
/// Both signs are rejected, including `+` and `-0`. The first non-digit ends
/// the prefix, but an empty digit prefix, overflow, or excessive size raises
/// `ParseError`. Consumption includes skipped zeroes. `skip_zeroes`, result
/// ranges, immutable view ownership, and SIMD fallback match `parse_prefix`.
pub fn[T : Parse] parse_prefix_pos(
  data : BytesView,
  skip_zeroes~ : Bool = false,
  simd~ : Bool = true,
) -> (T, Int32) raise ParseError {
  T::parse_decimal(
    data,
    positive_only=true,
    prefix=true,
    skip_zeroes~,
    skip_plus=false,
    simd~,
  )
}

///|
/// Parses sign-free digits as a negative prefix and returns consumed bytes.
///
/// The result type must be signed; both literal signs are rejected. Zero and
/// the minimum signed value are accepted. Consumption includes skipped zeroes
/// and excludes the first non-digit. An empty prefix, overflow, or excessive
/// size raises `ParseError`. `skip_zeroes`, immutable view ownership, and SIMD
/// fallback match `parse_prefix`; the entire digit prefix is range checked.
pub fn[T : ParseNeg] parse_prefix_neg(
  data : BytesView,
  skip_zeroes~ : Bool = false,
  simd~ : Bool = true,
) -> (T, Int32) raise ParseError {
  T::parse_negative_decimal(data, prefix=true, skip_zeroes~, simd~)
}
