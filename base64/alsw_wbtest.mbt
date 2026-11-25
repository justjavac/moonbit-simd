///|
/// Maps a byte independently to its RFC 4648 sextet for LUT differential checks.
#cfg(any(target="native", target="wasm"))
fn oracle_sextet(code : Int32, url_safe : Bool) -> Int32? {
  match code {
    'A'..<='Z' => Some(code - 'A')
    'a'..<='z' => Some(code - 'a' + 26)
    '0'..<='9' => Some(code - '0' + 52)
    '+' if !url_safe => Some(62)
    '/' if !url_safe => Some(63)
    '-' if url_safe => Some(62)
    '_' if url_safe => Some(63)
    _ => None
  }
}

///|
#cfg(any(target="native", target="wasm"))
test "derived ALSW values and classification match every byte's independent sextet" {
  for url_safe in [false, true] {
    let tables = if url_safe { url_alsw } else { standard_alsw }
    for code in 0..<256 {
      let bytes = FixedArray::make(16, code.to_byte())
      let vector = @simd.v128_load(bytes, 0)
      match oracle_sextet(code, url_safe) {
        Some(expected) => {
          let decoded = decode_values(vector, tables)
          for lane in 0..<16 {
            assert_eq(
              @simd.i8x16_extract_lane_u(decoded, lane),
              expected.reinterpret_as_uint(),
            )
          }
        }
        None =>
          try decode_values(vector, tables) catch {
            InvalidInput => ()
            _ => fail("Unexpected vector decoding error")
          } noraise {
            _ => fail("ALSW accepted an invalid byte")
          }
      }
    }
  }
}
