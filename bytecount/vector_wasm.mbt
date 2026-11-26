///|
/// Uses population counts on short Wasm inputs and lane batches on larger ones.
fn count_vectors(
  buffer : Bytes,
  start : Int32,
  end : Int32,
  mask : V128,
  needle : V128,
) -> Int32 {
  if end - start > 256 {
    return count_vector_batches(buffer, start, end, mask, needle)
  }
  for i = start, total = 0; i <= end - 32; {
    let a = @simd.i8x16_bitmask(matching_lanes(buffer, i, mask, needle))
    let b = @simd.i8x16_bitmask(matching_lanes(buffer, i + 16, mask, needle))
    continue i + 32, total + (a | (b << 16)).popcnt()
  } nobreak {
    if i == end {
      total
    } else {
      total +
      @simd.i8x16_bitmask(matching_lanes(buffer, i, mask, needle)).popcnt()
    }
  }
}
