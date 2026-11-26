///|
/// Read-only totals for a byte sequence. `lines` counts LF bytes, `words`
/// counts runs of bytes separated by ASCII whitespace, and `bytes` is the
/// length. All three totals are zero for empty input.
#derive(Eq, Debug)
pub struct Counts {
  lines : UInt64
  words : UInt64
  bytes : UInt64
}

///|
/// Counts LF bytes, ASCII-delimited words, and bytes in `data` without copying
/// the view or requiring valid text. A final word counts without a trailing
/// separator. Returns zero totals for an empty view.
///
/// `simd=true` requests vectors on native and Wasm when a complete 16-byte
/// block is present. Short inputs, Wasm GC, and JavaScript use scalar code.
pub fn count(data : BytesView, simd~ : Bool = true) -> Counts {
  let (lines, words, _) = scan(data, 1, simd)
  {
    lines: lines.to_uint64(),
    words: words.to_uint64(),
    bytes: data.length().to_uint64(),
  }
}

///|
/// Scans a view from an incoming whitespace bit, returning local LF and word
/// counts and the outgoing whitespace bit.
fn scan_scalar(
  data : BytesView,
  previous_space : Int32,
) -> (Int32, Int32, Int32) {
  for byte in data; lines = 0, words = 0, previous = previous_space {
    let space = if byte is (0x09..<=0x0D | 0x20) { 1 } else { 0 }
    let newline = if byte == b'\n' { 1 } else { 0 }
    continue lines + newline, words + (previous & (space ^ 1)), space
  } nobreak {
    (lines, words, previous)
  }
}
