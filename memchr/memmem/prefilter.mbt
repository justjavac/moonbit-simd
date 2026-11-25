///|
/// Finds a possible start by checking the two chosen bytes at valid positions.
fn scalar_pair(
  needle : BytesView,
  data : BytesView,
  searcher : Searcher,
) -> Int32? {
  let starts = data.length() - needle.length() + 1
  let a = needle[searcher.index1]
  let b = needle[searcher.index2]
  let first = data[searcher.index1:searcher.index1 + starts]
  for cursor = 0; cursor < starts; {
    match @bytesearch.memchr(a, first[cursor:], simd=false) {
      None => break None
      Some(found) => {
        let position = cursor + found
        if data[position + searcher.index2] == b {
          break Some(position)
        }
        continue position + 1
      }
    }
  } nobreak {
    None
  }
}

///|
/// Scans sixteen possible starts with two bounded, offset vector loads.
#cfg(any(target="native", target="wasm"))
fn vector_pair(
  needle : BytesView,
  data : BytesView,
  searcher : Searcher,
) -> Int32? {
  let starts = data.length() - needle.length() + 1
  let a = @simd.i8x16_splat(needle[searcher.index1])
  let b = @simd.i8x16_splat(needle[searcher.index2])
  let buffer = data.data()
  let start = data.start_offset()
  let offset = for offset = 0; starts - offset >= 16; offset = offset + 16 {
    // index1/index2 < needle.length(), so both sixteen-byte loads end inside
    // the view when sixteen complete candidate starts remain.
    let left = buffer.unsafe_extract_v128_aligned(
      start + searcher.index1 + offset,
    )
    let right = buffer.unsafe_extract_v128_aligned(
      start + searcher.index2 + offset,
    )
    let mask = @simd.i8x16_bitmask(
      @simd.v128_and_(@simd.i8x16_eq(left, a), @simd.i8x16_eq(right, b)),
    )
    if mask != 0 {
      return Some(offset + mask.ctz())
    }
  } nobreak {
    offset
  }
  match scalar_pair(needle, data[offset:], searcher) {
    Some(index) => Some(offset + index)
    None => None
  }
}

///|
/// Uses the same predictive pair on backends without portable vector support.
#cfg(not(any(target="native", target="wasm")))
fn vector_pair(
  needle : BytesView,
  data : BytesView,
  searcher : Searcher,
) -> Int32? {
  scalar_pair(needle, data, searcher)
}

///|
/// Chooses vector filtering only when sixteen complete candidate starts remain.
fn find_pair(
  needle : BytesView,
  data : BytesView,
  searcher : Searcher,
  simd~ : Bool,
) -> Int32? {
  if simd && data.length() - needle.length() >= 15 {
    vector_pair(needle, data, searcher)
  } else {
    scalar_pair(needle, data, searcher)
  }
}
