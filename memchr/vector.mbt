///|
/// Builds a sixteen-bit union of equal-byte lanes without scalar lane extraction.
#cfg(any(target="native", target="wasm"))
#inline
fn vector_mask(
  block : V128,
  a : V128,
  b : V128,
  c : V128,
  arity : Int32,
) -> Int32 {
  let matched = @simd.i8x16_eq(block, a)
  @simd.i8x16_bitmask(
    if arity == 1 {
      matched
    } else if arity == 2 {
      @simd.v128_or_(matched, @simd.i8x16_eq(block, b))
    } else {
      @simd.v128_or_(
        matched,
        @simd.v128_or_(@simd.i8x16_eq(block, b), @simd.i8x16_eq(block, c)),
      )
    },
  )
}

///|
/// Finds the first matching lane in complete vectors, then searches the remainder.
#cfg(any(target="native", target="wasm"))
fn vector_find(needles : Needles, data : BytesView) -> Int32? {
  let (a, b, c, arity) = needles.values()
  let (a, b, c) = (
    @simd.i8x16_splat(a),
    @simd.i8x16_splat(b),
    @simd.i8x16_splat(c),
  )
  let buffer = data.data()
  let start = data.start_offset()
  let length = data.length()
  let offset = for offset = 0; length - offset >= 16; offset = offset + 16 {
    // The view-length guard proves start + offset + 16 <= the view end.
    // "aligned" means a byte offset, not a sixteen-byte-aligned address.
    let block = buffer.unsafe_extract_v128_aligned(start + offset)
    let mask = vector_mask(block, a, b, c, arity)
    if mask != 0 {
      return Some(offset + mask.ctz())
    }
  } nobreak {
    offset
  }
  match scalar_find(needles, data[offset:]) {
    Some(index) => Some(offset + index)
    None => None
  }
}

///|
/// Finds the last matching lane without loading before or beyond the view.
#cfg(any(target="native", target="wasm"))
fn vector_rfind(needles : Needles, data : BytesView) -> Int32? {
  let (a, b, c, arity) = needles.values()
  let (a, b, c) = (
    @simd.i8x16_splat(a),
    @simd.i8x16_splat(b),
    @simd.i8x16_splat(c),
  )
  let buffer = data.data()
  let start = data.start_offset()
  let end = for end = data.length(); end >= 16; end = end - 16 {
    // end never exceeds the view length and end - 16 is nonnegative.
    let block = buffer.unsafe_extract_v128_aligned(start + (end - 16))
    let mask = vector_mask(block, a, b, c, arity)
    if mask != 0 {
      return Some(end - 16 + (31 - mask.clz()))
    }
  } nobreak {
    end
  }
  scalar_rfind(needles, data[:end])
}

///|
/// Counts the union of matching lanes with a population count and bounded tail.
#cfg(any(target="native", target="wasm"))
fn vector_count(needles : Needles, data : BytesView) -> Int32 {
  let (a, b, c, arity) = needles.values()
  let (a, b, c) = (
    @simd.i8x16_splat(a),
    @simd.i8x16_splat(b),
    @simd.i8x16_splat(c),
  )
  let buffer = data.data()
  let start = data.start_offset()
  let length = data.length()
  for offset = 0, count = 0; length - offset >= 16; {
    // Loads remain bounded by the view, including when its buffer has sentinels.
    let block = buffer.unsafe_extract_v128_aligned(start + offset)
    continue offset + 16, count + vector_mask(block, a, b, c, arity).popcnt()
  } nobreak {
    count + scalar_count(needles, data[offset:])
  }
}

///|
/// Preserves forward-search semantics on backends without vector declarations.
#cfg(not(any(target="native", target="wasm")))
fn vector_find(needles : Needles, data : BytesView) -> Int32? {
  scalar_find(needles, data)
}

///|
/// Preserves reverse-search semantics on backends without vector declarations.
#cfg(not(any(target="native", target="wasm")))
fn vector_rfind(needles : Needles, data : BytesView) -> Int32? {
  scalar_rfind(needles, data)
}

///|
/// Preserves unique-match counting on backends without vector declarations.
#cfg(not(any(target="native", target="wasm")))
fn vector_count(needles : Needles, data : BytesView) -> Int32 {
  scalar_count(needles, data)
}
