///|
/// Extends a checksum with sixteen-byte vector loads, scalar table folding, and a short tail.
#cfg(any(target="native", target="wasm"))
fn update_simd(initial : UInt32, data : BytesView) -> UInt32 {
  let buffer = data.data()
  let start = data.start_offset()
  // Round the view's length down so each load stays within the view,
  // regardless of any prefix or suffix in the backing buffer.
  let block_end = data.length() / 16 * 16
  for offset = 0, crc = initial ^ xor_mask; offset < block_end; {
    let block = buffer.unsafe_extract_v128_aligned(start + offset)
    // Extract each word once; portable SIMD has no table gather.
    let first = @simd.i32x4_extract_lane(block, 0) ^ crc
    let second = @simd.i32x4_extract_lane(block, 1)
    let third = @simd.i32x4_extract_lane(block, 2)
    let fourth = @simd.i32x4_extract_lane(block, 3)
    // Slice 15..0 encodes the remaining bytes after each source byte.
    // Byte masking bounds every index to the 4096-entry immutable table.
    let next = slicing_table.unsafe_get(
        15 * 256 + (first & 0xFF).reinterpret_as_int(),
      ) ^
      slicing_table.unsafe_get(
        14 * 256 + ((first >> 8) & 0xFF).reinterpret_as_int(),
      ) ^
      slicing_table.unsafe_get(
        13 * 256 + ((first >> 16) & 0xFF).reinterpret_as_int(),
      ) ^
      slicing_table.unsafe_get(12 * 256 + (first >> 24).reinterpret_as_int()) ^
      slicing_table.unsafe_get(11 * 256 + (second & 0xFF).reinterpret_as_int()) ^
      slicing_table.unsafe_get(
        10 * 256 + ((second >> 8) & 0xFF).reinterpret_as_int(),
      ) ^
      slicing_table.unsafe_get(
        9 * 256 + ((second >> 16) & 0xFF).reinterpret_as_int(),
      ) ^
      slicing_table.unsafe_get(8 * 256 + (second >> 24).reinterpret_as_int()) ^
      slicing_table.unsafe_get(7 * 256 + (third & 0xFF).reinterpret_as_int()) ^
      slicing_table.unsafe_get(
        6 * 256 + ((third >> 8) & 0xFF).reinterpret_as_int(),
      ) ^
      slicing_table.unsafe_get(
        5 * 256 + ((third >> 16) & 0xFF).reinterpret_as_int(),
      ) ^
      slicing_table.unsafe_get(4 * 256 + (third >> 24).reinterpret_as_int()) ^
      slicing_table.unsafe_get(3 * 256 + (fourth & 0xFF).reinterpret_as_int()) ^
      slicing_table.unsafe_get(
        2 * 256 + ((fourth >> 8) & 0xFF).reinterpret_as_int(),
      ) ^
      slicing_table.unsafe_get(
        256 + ((fourth >> 16) & 0xFF).reinterpret_as_int(),
      ) ^
      slicing_table.unsafe_get((fourth >> 24).reinterpret_as_int())
    continue offset + 16, next
  } nobreak {
    update_scalar(crc ^ xor_mask, data[block_end:])
  }
}
