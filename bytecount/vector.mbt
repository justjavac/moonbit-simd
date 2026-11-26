///|
/// Compares the selected bits in a complete sixteen-byte block.
#cfg(any(target="native", target="wasm"))
#inline
fn matching_lanes(
  buffer : Bytes,
  offset : Int32,
  mask : V128,
  needle : V128,
) -> V128 {
  // Callers bound offset to a complete block. The load uses byte alignment.
  let block = buffer.unsafe_extract_v128_aligned(offset)
  @simd.i8x16_eq(@simd.v128_and_(block, mask), needle)
}

///|
/// Adds the sixteen unsigned byte counters from a SIMD batch.
#cfg(any(target="native", target="wasm"))
#inline
fn sum_lanes(counts : V128) -> Int32 {
  let pairs = @simd.i16x8_extadd_pairwise_i8x16_u(counts)
  let quads = @simd.i32x4_extadd_pairwise_i16x8_u(pairs)
  (@simd.i32x4_extract_lane(quads, 0) +
  @simd.i32x4_extract_lane(quads, 1) +
  @simd.i32x4_extract_lane(quads, 2) +
  @simd.i32x4_extract_lane(quads, 3)).reinterpret_as_int()
}

///|
/// Accumulates pairs of complete vectors before widening their byte counters.
#cfg(any(target="native", target="wasm"))
fn count_vector_batches(
  buffer : Bytes,
  start : Int32,
  end : Int32,
  mask : V128,
  needle : V128,
) -> Int32 {
  let pair_end = end - (end - start) % 32
  let zero = @simd.i8x16_splat(0)
  let total = for i = start, total = 0; i < pair_end; {
    // A true lane is 0xFF. Subtraction increments the byte counter by one.
    // At most 255 pairs enter each batch, so neither accumulator can wrap.
    let batch_end = i + (pair_end - i).min(255 * 32)
    let subtotal = for j = i, first = zero, second = zero; j < batch_end; {
      let a = matching_lanes(buffer, j, mask, needle)
      let b = matching_lanes(buffer, j + 16, mask, needle)
      continue j + 32, @simd.i8x16_sub(first, a), @simd.i8x16_sub(second, b)
    } nobreak {
      sum_lanes(first) + sum_lanes(second)
    }
    continue batch_end, total + subtotal
  } nobreak {
    total
  }
  if pair_end == end {
    total
  } else {
    total +
    @simd.i8x16_bitmask(matching_lanes(buffer, pair_end, mask, needle)).popcnt()
  }
}

///|
/// Uses lane batches for complete vectors on the native backend.
#cfg(target="native")
fn count_vectors(
  buffer : Bytes,
  start : Int32,
  end : Int32,
  mask : V128,
  needle : V128,
) -> Int32 {
  count_vector_batches(buffer, start, end, mask, needle)
}

///|
/// Counts matching lanes in complete vectors and finishes with the scalar tail.
#cfg(any(target="native", target="wasm"))
fn count_fast(data : BytesView, needle : Byte) -> Int32 {
  let length = data.length()
  if length < 128 {
    return count_words(data, needle)
  }
  let buffer = data.data()
  let start = data.start_offset()
  let end = start + length
  let vector_end = end - length % 16
  let matches = count_vectors(
    buffer,
    start,
    vector_end,
    @simd.i8x16_splat(0xFF),
    @simd.i8x16_splat(needle),
  )
  matches + count_bytes(buffer, vector_end, end, needle)
}

///|
/// Counts continuation lanes in complete vectors and finishes with the scalar tail.
#cfg(any(target="native", target="wasm"))
fn num_chars_fast(data : BytesView) -> Int32 {
  let length = data.length()
  if length < 128 {
    return num_chars_words(data)
  }
  let buffer = data.data()
  let start = data.start_offset()
  let end = start + length
  let vector_end = end - length % 16
  // A continuation byte starts with the bits 10.
  let continuations = count_vectors(
    buffer,
    start,
    vector_end,
    @simd.i8x16_splat(0xC0),
    @simd.i8x16_splat(0x80),
  )
  vector_end - start - continuations + count_chars(buffer, vector_end, end)
}

///|
/// Uses the eight-byte scalar kernel on the Wasm GC backend.
#cfg(target="wasm-gc")
fn count_fast(data : BytesView, needle : Byte) -> Int32 {
  count_words(data, needle)
}

///|
/// Uses the eight-byte scalar UTF-8 kernel on the Wasm GC backend.
#cfg(target="wasm-gc")
fn num_chars_fast(data : BytesView) -> Int32 {
  num_chars_words(data)
}
