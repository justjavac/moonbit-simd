///|
/// Marks every non-ASCII-digit lane, treating high-bit bytes as below ASCII zero.
#cfg(any(target="native", target="wasm"))
#inline
fn vector_invalid_digits(block : V128) -> Int32 {
  @simd.i8x16_bitmask(
    @simd.v128_or_(
      @simd.i8x16_gt_s(block, @simd.i8x16_splat(b'9')),
      @simd.i8x16_gt_s(@simd.i8x16_splat(b'0'), block),
    ),
  )
}

///|
/// Scans complete sixteen-byte vectors without reading past the supplied view.
#cfg(any(target="native", target="wasm"))
fn vector_digit_length(data : BytesView) -> Int32 {
  for rest = data, count = 0 {
    match rest {
      [v128le(block), .. tail] => {
        let invalid = vector_invalid_digits(block)
        if invalid != 0 {
          break count + invalid.ctz()
        }
        continue tail, count + 16
      }
      _ => break count + scalar_digit_length(rest)
    }
  }
}

///|
/// Ports upstream's decimal reduction tree to portable V128 integer operations.
#cfg(any(target="native", target="wasm"))
#inline
fn reduce_sixteen(block : V128) -> UInt64 {
  let digits = @simd.v128_and_(block, @simd.i8x16_splat(15))
  let pairs = @simd.i16x8_add(
    @simd.i16x8_mul(
      @simd.v128_and_(digits, @simd.i16x8_splat(255)),
      @simd.i16x8_splat(10),
    ),
    @simd.i16x8_shr_u(digits, 8),
  )
  // Pairs are <= 99 and quads <= 9999, so signed dot products and the
  // unsigned narrowing step are exact and cannot saturate.
  let quads = @simd.i32x4_dot_i16x8_s(
    pairs,
    @simd.i16x8_const(100, 1, 100, 1, 100, 1, 100, 1),
  )
  let packed = @simd.i16x8_narrow_i32x4_u(quads, quads)
  let octets = @simd.i32x4_dot_i16x8_s(
    packed,
    @simd.i16x8_const(10000, 1, 10000, 1, 10000, 1, 10000, 1),
  )
  @simd.i32x4_extract_lane(octets, 0).to_uint64() * 100000000UL +
  @simd.i32x4_extract_lane(octets, 1).to_uint64()
}
