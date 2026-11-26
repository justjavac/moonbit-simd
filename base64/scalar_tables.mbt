// Packed lookups adapt aklomp/base64's generic 32-bit codec. See LICENSE-BSD.

///|
/// Marks an invalid quartet outside the three packed output bytes.
const INVALID_WORD : UInt32 = 0x80000000U

///|
/// Generates one little-endian ASCII pair for each possible twelve-bit index.
fn make_encode_pairs(alphabet : Bytes) -> FixedArray[UInt16] {
  FixedArray::makei(4096, index => {
    alphabet[index >> 6].to_uint16() | (alphabet[index & 63].to_uint16() << 8)
  })
}

///|
/// Caches the standard alphabet's packed ASCII pairs.
let standard_encode_pairs : FixedArray[UInt16] = make_encode_pairs(
  standard_alphabet,
)

///|
/// Caches the URL-safe alphabet's packed ASCII pairs.
let url_encode_pairs : FixedArray[UInt16] = make_encode_pairs(url_alphabet)

///|
/// Generates one 256-entry table per quartet position in a single array.
fn make_decode_words(alphabet : Bytes) -> FixedArray[UInt32] {
  let table = FixedArray::make(4 * 256, INVALID_WORD)
  for sextet in 0..<64 {
    let index = alphabet[sextet].to_int()
    let value = sextet.reinterpret_as_uint()
    // Each entry contributes only its sextet's bits to the three output bytes.
    // Invalid entries set bit 31, outside the 24-bit little-endian result.
    table[index] = value << 2
    table[256 + index] = (value >> 4) | ((value & 15) << 12)
    table[512 + index] = (value >> 2 << 8) | ((value & 3) << 22)
    table[768 + index] = value << 16
  }
  table
}

///|
/// Caches the standard alphabet's packed output and validation entries.
let standard_decode_words : FixedArray[UInt32] = make_decode_words(
  standard_alphabet,
)

///|
/// Caches the URL-safe alphabet's packed output and validation entries.
let url_decode_words : FixedArray[UInt32] = make_decode_words(url_alphabet)
