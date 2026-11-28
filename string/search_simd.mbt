///|
/// Finds one UTF-16 code unit using StringZilla's equality masks and ordered lane selection.
///
/// Adapted from StringZilla v5.3.2 find/v128.h by Ash Vardanian (Apache-2.0).
/// This port uses eight 16-bit lanes, checked string-view bounds and core tails.
#cfg(any(target="native", target="wasm"))
fn scan_code_unit(text : StringView, code : UInt16, reverse~ : Bool) -> Int32? {
  let len = text.length()
  if len < 32 {
    return if reverse {
      text.rev_find_code_unit(code)
    } else {
      text.find_code_unit(code)
    }
  }
  let data = text.data()
  let start = text.start_offset()
  let key = @simd.i16x8_splat(code)
  let cleanup = for scanned = 0; len - scanned >= 32; scanned = scanned + 32 {
    let block = if reverse { len - scanned - 32 } else { scanned }
    let base = start + block
    let first = match_units(data, base, key)
    let second = match_units(data, base + 8, key)
    let third = match_units(data, base + 16, key)
    let last = match_units(data, base + 24, key)
    let any = @simd.v128_or_(
      @simd.v128_or_(first, second),
      @simd.v128_or_(third, last),
    )
    if @simd.i8x16_bitmask(any) != 0 {
      let mask = @simd.i16x8_bitmask(first) |
        (@simd.i16x8_bitmask(second) << 8) |
        (@simd.i16x8_bitmask(third) << 16) |
        (@simd.i16x8_bitmask(last) << 24)
      return Some(block + match_lane(mask, reverse~))
    }
  } nobreak {
    scanned
  }
  if reverse {
    text.unsafe_view(start=0, end=len - cleanup).rev_find_code_unit(code)
  } else {
    text
    .unsafe_view(start=cleanup, end=len)
    .find_code_unit(code)
    .map(index => cleanup + index)
  }
}

///|
/// Broadcasts equality over eight code units; callers bound the complete load.
#cfg(any(target="native", target="wasm"))
#inline
fn match_units(data : String, offset : Int32, key : V128) -> V128 {
  @simd.i16x8_eq(@simd.v128_load_i16x8(data, offset), key)
}

///|
/// Returns the first or last set lane in a nonzero mask.
#cfg(any(target="native", target="wasm"))
#inline
fn match_lane(mask : Int32, reverse~ : Bool) -> Int32 {
  if reverse {
    31 - mask.clz()
  } else {
    mask.ctz()
  }
}

///|
/// Chooses beginning, midpoint and final probes, shifting repeated probes toward distinct code units.
///
/// Adapts `sz_locate_needle_anomalies_` from StringZilla v5.3.2 find/serial.h
/// by Ash Vardanian (Apache-2.0). Each UTF-16 probe considers at most eight
/// nearby positions, which keeps preparation bounded even for long needles.
#cfg(any(target="native", target="wasm"))
fn needle_probes(needle : StringView) -> (Int32, Int32, Int32) {
  let mut middle = needle.length() / 2
  let mut last = needle.length() - 1
  let first_code = needle.unsafe_get(0)
  let middle_end = middle + (last - middle).min(8)
  for pos in middle..<middle_end {
    if needle.unsafe_get(pos) != first_code {
      middle = pos
      break
    }
  }
  let middle_code = needle.unsafe_get(middle)
  let last_end = last - (last - middle - 1).min(7).max(0)
  for pos in (last + 1)>..last_end {
    let code = needle.unsafe_get(pos)
    if code != first_code && code != middle_code {
      last = pos
      break
    }
  }
  let last_code = needle.unsafe_get(last)
  for pos in 0..<middle.min(8) {
    let code = needle.unsafe_get(pos)
    if code != middle_code && code != last_code {
      return (pos, middle, last)
    }
  }
  (0, middle, last)
}

///|
/// Intersects the final probe with two partially filtered masks and packs their lanes.
#cfg(any(target="native", target="wasm"))
#inline
fn candidate_mask(
  data : String,
  last : Int32,
  last_key : V128,
  low_matches : V128,
  high_matches : V128,
) -> Int32 {
  let low = @simd.v128_and_(low_matches, match_units(data, last, last_key))
  let high = @simd.v128_and_(
    high_matches,
    match_units(data, last + 8, last_key),
  )
  @simd.i8x16_bitmask(@simd.i8x16_narrow_i16x8_s(low, high))
}

///|
/// Applies the two remaining probes when only one half of a block has hits.
#cfg(any(target="native", target="wasm"))
#inline
fn filter_half(
  data : String,
  middle : Int32,
  last : Int32,
  middle_key : V128,
  last_key : V128,
  first_low : V128,
  first_high : V128,
) -> Int32 {
  candidate_mask(
    data,
    last,
    last_key,
    @simd.v128_and_(first_low, match_units(data, middle, middle_key)),
    @simd.v128_and_(first_high, match_units(data, middle + 8, middle_key)),
  )
}

///|
/// Keeps the native filter for long searches with a two-unit needle.
#cfg(target="native")
const SIMD_TWO_UNIT_SEARCH = true

///|
/// Uses core's two-anchor search for two-unit needles on Wasm.
#cfg(target="wasm")
const SIMD_TWO_UNIT_SEARCH = false

///|
/// Scans complete candidate windows with three probes and verifies every surviving lane.
///
/// Adapted from StringZilla v5.3.2 find/v128.h by Ash Vardanian (Apache-2.0).
/// The caller has established that the needle fits and has at least two units.
#cfg(any(target="native", target="wasm"))
fn find_substring(
  text : StringView,
  needle : StringView,
  reverse~ : Bool,
) -> Int32? {
  let len = text.length()
  let needle_len = needle.length()
  let candidates = len - needle_len + 1
  if needle_len == 2 && (!SIMD_TWO_UNIT_SEARCH || candidates < 64) {
    return if reverse { text.rev_find(needle) } else { text.find(needle) }
  }
  let data = text.data()
  let start = text.start_offset()
  let (first, middle, last) = needle_probes(needle)
  let first_code = needle.unsafe_get(first)
  let edge = if reverse { candidates - 1 } else { 0 }
  if data.unsafe_get(start + edge + first) == first_code &&
    equal_range(text, edge, needle, needle_len) {
    return Some(edge)
  }
  let first_key = @simd.i16x8_splat(first_code)
  let middle_code = needle.unsafe_get(middle)
  let last_code = needle.unsafe_get(last)
  // A repeated middle code unit can preserve many of the leading matches.
  let (middle, last, middle_code, last_code) = if middle_code == first_code {
    (last, middle, last_code, middle_code)
  } else {
    (middle, last, middle_code, last_code)
  }
  let middle_key = @simd.i16x8_splat(middle_code)
  let last_key = @simd.i16x8_splat(last_code)
  let mut failures = 0
  let step = if candidates >= 64 { 32 } else { 16 }
  let scanned = for scanned = 0
                    candidates - scanned >= step
                    scanned = scanned + step {
    let block = if reverse { candidates - scanned - step } else { scanned }
    let base = start + block
    // Every loaded lane represents a complete start, even at the last probe.
    let first_low = match_units(data, base + first, first_key)
    let first_high = match_units(data, base + first + 8, first_key)
    let first_pair = @simd.v128_or_(first_low, first_high)
    let mut mask = if step == 32 {
      let second_low = match_units(data, base + first + 16, first_key)
      let second_high = match_units(data, base + first + 24, first_key)
      let second_pair = @simd.v128_or_(second_low, second_high)
      if @simd.i8x16_bitmask(@simd.v128_or_(first_pair, second_pair)) == 0 {
        continue
      }
      if @simd.i8x16_bitmask(first_pair) == 0 {
        filter_half(
          data,
          base + middle + 16,
          base + last + 16,
          middle_key,
          last_key,
          second_low,
          second_high,
        ) <<
        16
      } else if @simd.i8x16_bitmask(second_pair) == 0 {
        filter_half(
          data,
          base + middle,
          base + last,
          middle_key,
          last_key,
          first_low,
          first_high,
        )
      } else {
        // A frequent first probe can match in both halves without leaving any
        // starts that also match the middle probe. Check that before packing.
        let midpoint = base + middle
        let first_low = @simd.v128_and_(
          first_low,
          match_units(data, midpoint, middle_key),
        )
        let first_high = @simd.v128_and_(
          first_high,
          match_units(data, midpoint + 8, middle_key),
        )
        let second_low = @simd.v128_and_(
          second_low,
          match_units(data, midpoint + 16, middle_key),
        )
        let second_high = @simd.v128_and_(
          second_high,
          match_units(data, midpoint + 24, middle_key),
        )
        let first_pair = @simd.v128_or_(first_low, first_high)
        let second_pair = @simd.v128_or_(second_low, second_high)
        if @simd.i8x16_bitmask(@simd.v128_or_(first_pair, second_pair)) == 0 {
          continue
        }
        let first_mask = candidate_mask(
          data,
          base + last,
          last_key,
          first_low,
          first_high,
        )
        let second_mask = candidate_mask(
          data,
          base + last + 16,
          last_key,
          second_low,
          second_high,
        )
        first_mask | (second_mask << 16)
      }
    } else {
      if @simd.i8x16_bitmask(first_pair) == 0 {
        continue
      }
      filter_half(
        data,
        base + middle,
        base + last,
        middle_key,
        last_key,
        first_low,
        first_high,
      )
    }
    while mask != 0 {
      let lane = match_lane(mask, reverse~)
      let candidate = block + lane
      if equal_range(text, candidate, needle, needle_len) {
        return Some(candidate)
      }
      failures += 1
      // Bound the total verification work. The core search keeps its linear
      // fallback on periodic inputs and may revisit this block.
      if failures == 16 {
        break
      }
      mask = mask ^ (1 << lane)
    }
    if failures == 16 {
      break scanned
    }
  } nobreak {
    scanned
  }
  if scanned == candidates {
    return None
  }
  if reverse {
    text.unsafe_view(start=0, end=len - scanned).rev_find(needle)
  } else {
    text
    .unsafe_view(start=scanned, end=len)
    .find(needle)
    .map(index => scanned + index)
  }
}
