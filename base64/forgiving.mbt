///|
/// Recognizes exactly WHATWG Infra's five ASCII whitespace bytes.
fn ascii_whitespace(code : Int32) -> Bool {
  match code {
    9 | 10 | 12 | 13 | 32 => true
    _ => false
  }
}

///|
/// Removes ASCII whitespace only when present, preserving non-ASCII rejection.
fn forgiving_input(input : Input) -> Input raise Base64Error {
  let mut count = 0
  for i in 0..<input.length() {
    if !ascii_whitespace(input.at(i)) {
      count += 1
    }
  }
  if count == input.length() {
    return input
  }
  let cleaned = FixedArray::make(count, b'\x00')
  for i in 0..<input.length(); j = 0 {
    let code = input.at(i)
    if ascii_whitespace(code) {
      continue j
    } else {
      guard code < 128 else { raise InvalidInput }
      cleaned[j] = code.to_byte()
      continue j + 1
    }
  }
  Raw(Bytes::from_array(cleaned[:])[:])
}

///|
/// Decodes standard Base64 using WHATWG Infra's forgiving-base64 algorithm.
///
/// Removes ASCII TAB, LF, FF, CR, and SPACE, accepts correctly placed optional
/// padding, and ignores unused tail bits. Vertical tab, non-ASCII, URL-safe
/// characters, interior padding, and impossible lengths raise `InvalidInput`.
/// Input is unchanged; the result is independent. Whitespace needs a temporary
/// normalized allocation. SIMD and fallback behavior match strict `decode`.
pub fn forgiving_decode(
  input : BytesView,
  simd~ : Bool = default_simd,
) -> Bytes raise Base64Error {
  decode_allocated(forgiving_input(Raw(input)), standard, true, simd)
}

///|
/// Applies forgiving-base64 to an ASCII StringView without UTF-8 conversion.
///
/// Whitespace, tail-bit, padding, failure, and SIMD rules match
/// `forgiving_decode`. Every non-ASCII UTF-16 code unit is rejected, and the
/// input and retained views are unchanged. Empty or all-whitespace input
/// returns empty bytes.
pub fn forgiving_decode_string(
  input : StringView,
  simd~ : Bool = default_simd,
) -> Bytes raise Base64Error {
  decode_allocated(forgiving_input(Text(input)), standard, true, simd)
}

///|
/// Writes forgiving-decoded bytes at `offset` and returns the number written.
///
/// Normalizes whitespace into temporary storage when present. Capacity is
/// checked against the exact decoded size, relaxing upstream's requirement
/// that the destination hold the entire encoded input. `OutputTooSmall` occurs
/// before writes. Later `InvalidInput` can leave a partially written prefix;
/// on success, bytes outside the written range are unchanged. Input is immutable.
pub fn forgiving_decode_into(
  input : BytesView,
  output : FixedArray[Byte],
  offset~ : Int32 = 0,
  simd~ : Bool = default_simd,
) -> Int32 raise Base64Error {
  let source = forgiving_input(Raw(input))
  let (n, length) = decoded_shape(source, false, true)
  output_range(output, offset, length)
  decode_dispatch(source, n, output, offset, standard, true, true, simd)
  length
}

///|
/// Compacts whitespace then forgiving-decodes a mutable array prefix in place.
///
/// `length` defaults to the array capacity and must be within it. No input
/// copy is allocated. Returns decoded prefix size; the unused suffix is
/// unspecified because whitespace compaction can change it. Array aliases
/// observe writes. As upstream does, whitespace compaction and partial
/// decoding can occur before `InvalidInput`. Uses the same SIMD policy as
/// `forgiving_decode`; only standard Base64 is accepted.
pub fn forgiving_decode_inplace(
  data : FixedArray[Byte],
  length? : Int32,
  simd~ : Bool = default_simd,
) -> Int32 raise Base64Error {
  let source = inplace_input(data, length)
  let compacted = for i in 0..<source.length(); j = 0 {
    let code = data[i]
    if ascii_whitespace(code.to_int()) {
      continue j
    } else {
      data[j] = code
      continue j + 1
    }
  } nobreak {
    j
  }
  let source = Inplace(data, compacted)
  let (n, decoded) = decoded_shape(source, false, true)
  decode_dispatch(source, n, data, 0, standard, true, true, simd)
  decoded
}
