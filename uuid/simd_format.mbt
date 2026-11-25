///|
/// Expands sixteen UUID bytes to two vectors of ASCII hexadecimal text.
#cfg(target="wasm")
#inline
fn encode_ascii32(uuid : Uuid, case : AsciiCase) -> (V128, V128) {
  let alphabet = if case == Lower {
    @simd.i8x16_const(
      b'0', b'1', b'2', b'3', b'4', b'5', b'6', b'7', b'8', b'9', b'a', b'b', b'c',
      b'd', b'e', b'f',
    )
  } else {
    @simd.i8x16_const(
      b'0', b'1', b'2', b'3', b'4', b'5', b'6', b'7', b'8', b'9', b'A', b'B', b'C',
      b'D', b'E', b'F',
    )
  }
  let bytes = reverse_words(@simd.i64x2_const(uuid.high, uuid.low))
  let high = @simd.i8x16_swizzle(alphabet, @simd.i8x16_shr_u(bytes, 4))
  let low = @simd.i8x16_swizzle(
    alphabet,
    @simd.v128_and_(bytes, @simd.i8x16_splat(15)),
  )
  (
    @simd.i8x16_shuffle(
      high, low, 0, 16, 1, 17, 2, 18, 3, 19, 4, 20, 5, 21, 6, 22, 7, 23,
    ),
    @simd.i8x16_shuffle(
      high, low, 8, 24, 9, 25, 10, 26, 11, 27, 12, 28, 13, 29, 14, 30, 15, 31,
    ),
  )
}

///|
/// Converts sixteen native nibbles to ASCII with vector arithmetic and masks.
#cfg(target="native")
#inline
fn ascii_nibbles(value : V128, case : AsciiCase) -> V128 {
  let alpha = @simd.i8x16_gt_u(value, @simd.i8x16_splat(9))
  let adjustment = @simd.v128_and_(
    alpha,
    @simd.i8x16_splat(if case == Lower { 39 } else { 7 }),
  )
  @simd.i8x16_add(@simd.i8x16_add(value, @simd.i8x16_splat(b'0')), adjustment)
}

///|
/// Expands native UUID bytes using portable widening and pair interleaving.
#cfg(target="native")
#inline
fn encode_ascii32(uuid : Uuid, case : AsciiCase) -> (V128, V128) {
  let bytes = @simd.i64x2_const(swap_bytes(uuid.high), swap_bytes(uuid.low))
  let high = ascii_nibbles(@simd.i8x16_shr_u(bytes, 4), case)
  let low = ascii_nibbles(@simd.v128_and_(bytes, @simd.i8x16_splat(15)), case)
  (
    @simd.v128_or_(
      @simd.i16x8_extend_low_i8x16_u(high),
      @simd.i16x8_shl(@simd.i16x8_extend_low_i8x16_u(low), 8),
    ),
    @simd.v128_or_(
      @simd.i16x8_extend_high_i8x16_u(high),
      @simd.i16x8_shl(@simd.i16x8_extend_high_i8x16_u(low), 8),
    ),
  )
}

///|
/// Writes vector hexadecimal output and inserts hyphens within checked bounds.
#cfg(any(target="native", target="wasm"))
fn write_simd(
  uuid : Uuid,
  destination : FixedArray[Byte],
  offset : Int32,
  hyphenated : Bool,
  case : AsciiCase,
) -> Unit {
  let (first, second) = encode_ascii32(uuid, case)
  if !hyphenated {
    @simd.v128_store(destination, offset, first)
    @simd.v128_store(destination, offset + 16, second)
    return
  }
  let (front, back) = insert_hyphens(first, second)
  @simd.v128_store(destination, offset, front)
  @simd.v128_store(destination, offset + 16, back)
  @simd.v128_store32_lane(destination, offset + 32, second, 3)
}

///|
/// Inserts Wasm hyphens with bounded constant vector shuffles and masks.
#cfg(target="wasm")
#inline
fn insert_hyphens(first : V128, second : V128) -> (V128, V128) {
  let front = @simd.v128_or_(
    @simd.i8x16_swizzle(
      first,
      @simd.i8x16_const(0, 1, 2, 3, 4, 5, 6, 7, 128, 8, 9, 10, 11, 128, 12, 13),
    ),
    @simd.i8x16_const(0, 0, 0, 0, 0, 0, 0, 0, b'-', 0, 0, 0, 0, b'-', 0, 0),
  )
  let back = @simd.v128_or_(
    @simd.v128_and_(
      @simd.i8x16_shuffle(
        first, second, 14, 15, 0, 16, 17, 18, 19, 0, 20, 21, 22, 23, 24, 25, 26,
        27,
      ),
      @simd.i8x16_const(
        255, 255, 0, 255, 255, 255, 255, 0, 255, 255, 255, 255, 255, 255, 255, 255,
      ),
    ),
    @simd.i8x16_const(0, 0, b'-', 0, 0, 0, 0, b'-', 0, 0, 0, 0, 0, 0, 0, 0),
  )
  (front, back)
}

///|
/// Inserts native hyphens by packing fixed fields without optional byte shuffles.
#cfg(target="native")
#inline
fn insert_hyphens(first : V128, second : V128) -> (V128, V128) {
  let a0 = @simd.i64x2_extract_lane(first, 0)
  let a1 = @simd.i64x2_extract_lane(first, 1)
  let b0 = @simd.i64x2_extract_lane(second, 0)
  let b1 = @simd.i64x2_extract_lane(second, 1)
  // Front: 0..7, '-', 8..11, '-', 12..13.
  // Back: 14..15, '-', 16..19, '-', 20..27; the writer stores 28..31 separately.
  let front_high = 0x2d000000002dUL |
    ((a1 & 0xffffffffUL) << 8) |
    (((a1 >> 32) & 0xffffUL) << 48)
  let back_low = 0x2d000000002d0000UL | (a1 >> 48) | ((b0 & 0xffffffffUL) << 24)
  let back_high = (b0 >> 32) | (b1 << 32)
  (@simd.i64x2_const(a0, front_high), @simd.i64x2_const(back_low, back_high))
}
