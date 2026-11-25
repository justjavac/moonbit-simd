///|
/// Prepends one to three predecessor bytes using fixed-width lane arithmetic.
#cfg(target="native")
fn native_previous(input : V128, previous : V128, distance : Int32) -> V128 {
  let low = @simd.i64x2_extract_lane(input, 0)
  let high = @simd.i64x2_extract_lane(input, 1)
  let carry = @simd.i64x2_extract_lane(previous, 1)
  let bits = distance * 8
  @simd.i64x2_const(
    (low << bits) | (carry >> (64 - bits)),
    (high << bits) | (low >> (64 - bits)),
  )
}

///|
/// Checks the UTF-8 byte grammar with native vector range masks and predecessor lanes.
#cfg(target="native")
fn block_errors(input : V128, previous : V128) -> V128 {
  // The current native x86 lowering emulates unsigned byte comparisons,
  // shuffles, and swizzles with per-lane callbacks. Sign-flipped comparisons
  // and two UInt64 lanes preserve the grammar without those operations.
  let prev1 = native_previous(input, previous, 1)
  let prev2 = native_previous(input, previous, 2)
  let prev3 = native_previous(input, previous, 3)
  let sign = @simd.i8x16_splat(128)
  let current_ordered = @simd.v128_xor(input, sign)
  let one_ordered = @simd.v128_xor(prev1, sign)
  let two_ordered = @simd.v128_xor(prev2, sign)
  let three_ordered = @simd.v128_xor(prev3, sign)
  let expected = @simd.v128_or_(
    @simd.i8x16_gt_s(one_ordered, @simd.i8x16_splat(63)),
    @simd.v128_or_(
      @simd.i8x16_gt_s(two_ordered, @simd.i8x16_splat(95)),
      @simd.i8x16_gt_s(three_ordered, @simd.i8x16_splat(111)),
    ),
  )
  // Signed values below -64 are precisely unsigned bytes 0x80..0xBF.
  let continuation = @simd.i8x16_lt_s(input, @simd.i8x16_splat(192))
  let lengths = @simd.v128_xor(expected, continuation)
  let bad_leading = @simd.v128_and_(
    @simd.i8x16_gt_s(current_ordered, @simd.i8x16_splat(63)),
    @simd.v128_or_(
      @simd.i8x16_lt_s(current_ordered, @simd.i8x16_splat(66)),
      @simd.i8x16_gt_s(current_ordered, @simd.i8x16_splat(116)),
    ),
  )
  let overlong_three = @simd.v128_and_(
    @simd.i8x16_eq(prev1, @simd.i8x16_splat(224)),
    @simd.i8x16_lt_s(current_ordered, @simd.i8x16_splat(32)),
  )
  let surrogate = @simd.v128_and_(
    @simd.i8x16_eq(prev1, @simd.i8x16_splat(237)),
    @simd.i8x16_gt_s(current_ordered, @simd.i8x16_splat(31)),
  )
  let overlong_four = @simd.v128_and_(
    @simd.i8x16_eq(prev1, @simd.i8x16_splat(240)),
    @simd.i8x16_lt_s(current_ordered, @simd.i8x16_splat(16)),
  )
  let too_large = @simd.v128_and_(
    @simd.i8x16_eq(prev1, @simd.i8x16_splat(244)),
    @simd.i8x16_gt_s(current_ordered, @simd.i8x16_splat(15)),
  )
  @simd.v128_or_(
    @simd.v128_or_(lengths, bad_leading),
    @simd.v128_or_(
      @simd.v128_or_(overlong_three, surrogate),
      @simd.v128_or_(overlong_four, too_large),
    ),
  )
}
