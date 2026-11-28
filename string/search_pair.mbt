///|
/// Uses the eight-lane pair kernel through 32 code units on native.
#cfg(target="native")
const SHORT_PAIR_LIMIT = 32

///|
/// Uses the eight-lane pair kernel through 24 code units on linear-memory Wasm.
#cfg(target="wasm")
const SHORT_PAIR_LIMIT = 24

///|
/// Uses the short exact-pair kernel when it can scan a full eight-lane block.
#cfg(any(target="native", target="wasm"))
#inline
fn find_pair(text : StringView, needle : StringView, reverse~ : Bool) -> Int32? {
  let candidates = text.length() - 1
  if candidates >= 8 && candidates < SHORT_PAIR_LIMIT {
    return find_short_pair(
      text,
      needle.unsafe_get(0),
      needle.unsafe_get(1),
      reverse~,
    )
  }
  if candidates >= SHORT_PAIR_LIMIT {
    return find_substring(text, needle, reverse~)
  }
  if reverse {
    text.rev_find(needle)
  } else {
    text.find(needle)
  }
}

///|
/// Matches both units in eight candidate lanes at a time. The view has at least nine units.
#cfg(any(target="native", target="wasm"))
fn find_short_pair(
  text : StringView,
  first : UInt16,
  second : UInt16,
  reverse~ : Bool,
) -> Int32? {
  let data = text.data()
  let start = text.start_offset()
  let end = text.length() - 1
  let edge = if reverse { end - 1 } else { 0 }
  let first_difference = data.unsafe_get(start + edge) ^ first
  let last_difference = data.unsafe_get(start + edge + 1) ^ second
  if (first_difference | last_difference) == 0 {
    return Some(edge)
  }
  let first_key = @simd.i16x8_splat(first)
  let second_key = @simd.i16x8_splat(second)
  let last_block = end - 8
  let remainder = last_block % 8
  let initial_step = if remainder == 0 { 8 } else { remainder }
  for scanned = 0, step = initial_step; scanned <= last_block; {
    let block = if reverse { last_block - scanned } else { scanned }
    let offset = start + block
    // The second load ends at offset + 8, inside the view. Each matching
    // 16-bit lane yields two set bits in the byte mask.
    let matches = @simd.v128_and_(
      match_units(data, offset, first_key),
      match_units(data, offset + 1, second_key),
    )
    let bits = @simd.i8x16_bitmask(matches)
    if bits != 0 {
      return Some(block + (match_lane(bits, reverse~) >> 1))
    }
    // An overlapping second block puts the rest of the scan on eight-start steps.
    continue scanned + step, 8
  } nobreak {
    None
  }
}

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
