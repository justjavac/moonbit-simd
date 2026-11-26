// The word-start mask adapts fastlwc's SIMD_USE_POPCNT kernel (MIT, expr-fi).

///|
/// Uses the fastlwc word-start mask on complete vectors and scans the tail.
#cfg(any(target="native", target="wasm"))
fn scan(
  data : BytesView,
  previous_space : Int32,
  simd : Bool,
) -> (Int32, Int32, Int32) {
  let length = data.length()
  guard simd && length >= 16 else { return scan_scalar(data, previous_space) }
  let buffer = data.data()
  let start = data.start_offset()
  let newline = @simd.i8x16_splat(0x0A)
  let space = @simd.i8x16_splat(0x20)
  let bias = @simd.i8x16_splat(114)
  let before_tab = @simd.i8x16_splat(122)
  for offset = 0, lines = 0, words = 0, previous = previous_space; length -
     offset >=
     16; {
    // "Aligned" refers to byte offsets. The guard keeps the load in the view.
    let block = buffer.unsafe_extract_v128_aligned(start + offset)
    // Only 0x09..0x0D map to the signed range 123..127 after wrapping addition.
    let controls = @simd.i8x16_gt_s(@simd.i8x16_add(block, bias), before_tab)
    let whitespace = @simd.i8x16_bitmask(
      @simd.v128_or_(controls, @simd.i8x16_eq(block, space)),
    )
    let line_feeds = @simd.i8x16_bitmask(@simd.i8x16_eq(block, newline))
    // Shift earlier lanes onto their successors and insert the incoming bit.
    // Invert only the low 16 bits to exclude the shifted-out bit from starts.
    let starts = (whitespace ^ 0xFFFF) & ((whitespace << 1) | previous)
    continue offset + 16,
      lines + line_feeds.popcnt(),
      words + starts.popcnt(),
      whitespace >> 15
  } nobreak {
    let (tail_lines, tail_words, last) = scan_scalar(data[offset:], previous)
    (lines + tail_lines, words + tail_words, last)
  }
}

///|
/// Uses scalar scanning on backends without the portable V128 kernel.
#cfg(not(any(target="native", target="wasm")))
fn scan(
  data : BytesView,
  previous_space : Int32,
  _simd : Bool,
) -> (Int32, Int32, Int32) {
  scan_scalar(data, previous_space)
}
