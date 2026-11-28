///|
/// Scans complete pairs of the same code unit using adjacent bits in one mask.
/// The caller guarantees at least 33 code units in `text`.
#cfg(any(target="native", target="wasm"))
fn find_repeated_pair(
  text : StringView,
  code : UInt16,
  reverse~ : Bool,
) -> Int32? {
  let len = text.length()
  let start = text.start_offset()
  let data = text.data()
  let edge = if reverse { len - 2 } else { 0 }
  if data.unsafe_get(start + edge) == code &&
    data.unsafe_get(start + edge + 1) == code {
    return Some(edge)
  }
  let key = @simd.i16x8_splat(code)
  let last_block = len - 33
  let remainder = last_block % 32
  // An overlapping second block aligns the remaining scan to the far end.
  // Its repeated starts have already been ruled out in this direction.
  let initial_step = if remainder == 0 { 32 } else { remainder }
  for scanned = 0, step = initial_step; scanned <= last_block; {
    let block = if reverse { last_block - scanned } else { scanned }
    let offset = start + block
    // Every block covers 32 candidates. The last candidate's second unit
    // is the one-unit lookahead at offset + 32.
    let m0 = match_units(data, offset, key)
    let m1 = match_units(data, offset + 8, key)
    let m2 = match_units(data, offset + 16, key)
    let m3 = match_units(data, offset + 24, key)
    let left = @simd.v128_or_(m0, m1)
    let right = @simd.v128_or_(m2, m3)
    if @simd.i8x16_bitmask(@simd.v128_or_(left, right)) != 0 {
      let lo = @simd.i8x16_bitmask(@simd.i8x16_narrow_i16x8_s(m0, m1))
      let hi = @simd.i8x16_bitmask(@simd.i8x16_narrow_i16x8_s(m2, m3))
      let mask = (lo | (hi << 16)).reinterpret_as_uint()
      let lookahead = if data.unsafe_get(offset + 32) == code {
        0x80000000U
      } else {
        0U
      }
      let pairs = mask & ((mask >> 1) | lookahead)
      if pairs != 0U {
        return Some(block + match_lane(pairs.reinterpret_as_int(), reverse~))
      }
    }
    continue scanned + step, 32
  } nobreak {
    None
  }
}
