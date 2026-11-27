///|
/// Compares a bounded range to the first `len` code units of `other`.
///
/// Adapted from StringZilla v5.3.2 compare/v128.h by Ash Vardanian (Apache-2.0).
/// This port XORs eight UTF-16 code units per block. Callers check both ranges.
#cfg(target="wasm")
fn equal_range(
  text : StringView,
  start : Int32,
  other : StringView,
  len : Int32,
) -> Bool {
  let left = text.data()
  let right = other.data()
  let left_start = text.start_offset() + start
  let right_start = other.start_offset()
  if physical_equal(left, right) && left_start == right_start {
    return true
  }
  if len < 32 {
    return left.unsafe_range_equal(
      right,
      start=left_start,
      other_start=right_start,
      len~,
    )
  }
  let rounded = for pos = 0; len - pos >= 32; pos = pos + 32 {
    let l = left_start + pos
    let r = right_start + pos
    let difference = @simd.v128_or_(
      @simd.v128_or_(
        compare_units(left, l, right, r),
        compare_units(left, l + 8, right, r + 8),
      ),
      @simd.v128_or_(
        compare_units(left, l + 16, right, r + 16),
        compare_units(left, l + 24, right, r + 24),
      ),
    )
    if @simd.v128_any_true(difference) {
      return false
    }
  } nobreak {
    pos
  }
  left.unsafe_range_equal(
    right,
    start=left_start + rounded,
    other_start=right_start + rounded,
    len=len - rounded,
  )
}

///|
/// Returns differences for eight code units from equally sized bounded blocks.
#cfg(target="wasm")
#inline
fn compare_units(
  left : String,
  lpos : Int32,
  right : String,
  rpos : Int32,
) -> V128 {
  @simd.v128_xor(
    @simd.v128_load_i16x8(left, lpos),
    @simd.v128_load_i16x8(right, rpos),
  )
}
