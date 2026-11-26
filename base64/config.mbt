///|
/// An immutable RFC 4648 alphabet and padding policy.
///
/// Use `standard`, `standard_no_pad`, `url_safe`, or `url_safe_no_pad`, or
/// construct the same policies with `Base64::new`. Assignments safely share
/// the configuration; operations retain no input and have no mutable state.
/// The measured default requests vectors on Wasm and scalar processing on
/// native, Wasm GC, and JS. An explicit simd argument overrides that choice.
#derive(Eq, Debug)
struct Base64 {
  url_safe : Bool
  padding : Bool
}

///|
/// Reusable RFC 4648 standard configuration with alphabet
/// `A-Z a-z 0-9 + /`. A final one- or two-byte input group is encoded with
/// the required terminal `=` padding, and strict decoding requires it.
pub let standard : Base64 = { url_safe: false, padding: true, }

///|
/// Reusable configuration with the standard `+` and `/` alphabet.
/// Encoding omits terminal padding, and strict decoding rejects every
/// `=` while still checking the unused bits of the final symbol.
pub let standard_no_pad : Base64 = { url_safe: false, padding: false, }

///|
/// Reusable RFC 4648 URL-safe configuration. The symbols for sextets 62
/// and 63 are `-` and `_`. Encoding and strict decoding use the same
/// terminal padding rules as `standard`.
pub let url_safe : Base64 = { url_safe: true, padding: true, }

///|
/// Reusable configuration for unpadded Base64url. Encoding uses `-` and
/// `_` without terminal `=`. Strict decoding expects that alphabet and
/// validates the final symbol's unused bits.
pub let url_safe_no_pad : Base64 = { url_safe: true, padding: false, }

///|
/// Invalid Base64 or insufficient caller-provided output storage.
///
/// `InvalidInput` covers length, alphabet, padding, and nonzero unused bits.
/// `OutputTooSmall` also covers an output offset outside the destination.
/// Allocating operations expose no partial output. Buffer operations can
/// change an output prefix before a later `InvalidInput`; see their docs.
#derive(Eq, Debug)
pub suberror Base64Error {
  /// Input violates the operation's alphabet, padding, length, or tail rules.
  InvalidInput
  /// The destination offset is out of range or capacity is insufficient.
  /// The destination is untouched when this error is raised.
  OutputTooSmall
}

///|
/// Selects the RFC 4648 alphabet and padding policy.
///
/// `url_safe=true` uses `-` and `_`; `padding=false` omits `=` on encoding
/// and forbids it on decoding. Defaults select the standard padded policy.
pub fn Base64::new(url_safe~ : Bool = false, padding~ : Bool = true) -> Base64 {
  { url_safe, padding, }
}

///|
/// Returns the configuration's immutable 64-byte alphabet.
///
/// Byte at index `i` is the ASCII symbol for sextet `i`, from zero through
/// 63. The view borrows shared immutable alphabet storage and can be retained
/// independently of the configuration.
pub fn Base64::charset(self : Base64) -> BytesView {
  if self.url_safe {
    url_alphabet[:]
  } else {
    standard_alphabet[:]
  }
}

///|
/// Calculates the exact encoded byte length, including configured padding.
///
/// Panics for negative `length` or an output exceeding `Int::max_value`.
/// This checks multiplication before allocation; empty input needs zero bytes.
pub fn Base64::encoded_length(self : Base64, length : Int32) -> Int32 {
  guard length >= 0 else { abort("Negative Base64 input length") }
  let tail = length % 3
  let extra = if tail == 0 { 0 } else if self.padding { 4 } else { tail + 1 }
  let groups = length / 3
  guard groups <= (0x7fffffff - extra) / 4 else {
    abort("Base64 output length overflow")
  }
  groups * 4 + extra
}

///|
/// Returns an allocation upper bound for decoding `length` encoded bytes.
///
/// Rounds the encoded byte count up to complete quartets and reserves three
/// bytes per quartet. This estimate is independent of alphabet and padding
/// policy. It returns zero for zero, and panics for negative `length`.
pub fn Base64::estimated_decoded_length(
  _self : Base64,
  length : Int32,
) -> Int32 {
  guard length >= 0 else { abort("Negative Base64 input length") }
  (length / 4 + (if length % 4 == 0 { 0 } else { 1 })) * 3
}

///|
/// Calculates the decoded size after checking length and terminal padding.
///
/// As in upstream `decoded_length`, this is a partial validation: invalid
/// alphabet bytes, interior `=`, and unused tail bits can still pass. Use
/// `check` for full validation. Raises `InvalidInput` for impossible lengths.
/// Neither the configuration nor `input` is changed.
pub fn Base64::decoded_length(
  self : Base64,
  input : BytesView,
) -> Int32 raise Base64Error {
  let (_, length) = decoded_shape(Raw(input), self.padding, false)
  length
}

///|
/// The RFC 4648 standard alphabet, shared by all scalar operations.
let standard_alphabet : Bytes = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

///|
/// The RFC 4648 URL- and filename-safe alphabet.
let url_alphabet : Bytes = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

///|
/// Maps each byte to a sextet or `255` without allocating in hot loops.
fn make_decode_table(alphabet : Bytes) -> FixedArray[Byte] {
  let table = FixedArray::make(256, b'\xff')
  for i in 0..<64 {
    table[alphabet[i].to_int()] = i.to_byte()
  }
  table
}

///|
/// The reusable scalar lookup for standard Base64.
let standard_decode_table : FixedArray[Byte] = make_decode_table(
  standard_alphabet,
)

///|
/// The reusable scalar lookup for URL-safe Base64.
let url_decode_table : FixedArray[Byte] = make_decode_table(url_alphabet)

///|
/// Selects the shared scalar lookup for one configuration.
fn Base64::decode_table(self : Base64) -> FixedArray[Byte] {
  if self.url_safe {
    url_decode_table
  } else {
    standard_decode_table
  }
}

///|
/// Requests Wasm vectors by default on the validated toolchain.
#cfg(target="wasm")
let default_simd : Bool = true

///|
/// Defaults to scalar processing where V128 is slower or requires a fallback.
#cfg(not(target="wasm"))
let default_simd : Bool = false
