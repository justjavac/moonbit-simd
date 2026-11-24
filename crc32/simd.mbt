///|
/// Looks up four byte positions in the corresponding CRC slicing tables.
#cfg(any(target="native", target="wasm"))
#inline
fn lookup_lanes(words : V128, shift : Int32, slice : Int32) -> V128 {
  let indices = @simd.v128_and_(
    @simd.i32x4_shr_u(words, shift),
    @simd.i32x4_splat(0xFF),
  )
  // A lane's table encodes the number of bytes following that source byte
  // within the sixteen-byte block; no vector gather instruction is needed.
  @simd.i32x4_const(
    slicing_table[(slice + 12) * 256 +
    @simd.i32x4_extract_lane(indices, 0).reinterpret_as_int()],
    slicing_table[(slice + 8) * 256 +
    @simd.i32x4_extract_lane(indices, 1).reinterpret_as_int()],
    slicing_table[(slice + 4) * 256 +
    @simd.i32x4_extract_lane(indices, 2).reinterpret_as_int()],
    slicing_table[slice * 256 +
    @simd.i32x4_extract_lane(indices, 3).reinterpret_as_int()],
  )
}

///|
/// Extends a checksum with sixteen-byte SIMD slices and a scalar short tail.
#cfg(any(target="native", target="wasm"))
fn update_simd(initial : UInt32, data : BytesView) -> UInt32 {
  for rest = data, crc = initial ^ xor_mask {
    match rest {
      [v128le(block), .. tail] => {
        // The checked bitstring pattern loads only inside the input view.
        // XOR the continued CRC into the first little-endian word.
        let words = @simd.v128_xor(block, @simd.i32x4_const(crc, 0, 0, 0))
        let low = @simd.v128_xor(
          lookup_lanes(words, 0, 3),
          lookup_lanes(words, 8, 2),
        )
        let high = @simd.v128_xor(
          lookup_lanes(words, 16, 1),
          lookup_lanes(words, 24, 0),
        )
        let lanes = @simd.v128_xor(low, high)
        let next = @simd.i32x4_extract_lane(lanes, 0) ^
          @simd.i32x4_extract_lane(lanes, 1) ^
          @simd.i32x4_extract_lane(lanes, 2) ^
          @simd.i32x4_extract_lane(lanes, 3)
        continue tail, next
      }
      _ => break update_scalar(crc ^ xor_mask, rest)
    }
  }
}
