///|
/// Read-only totals returned by `count()` or snapshotted by `Counter::counts()`.
/// Fields are independent `UInt64` counts. All three are zero for empty input.
#derive(Eq, Debug)
pub struct Counts {
  /// Number of LF bytes (`0x0A`). A CRLF sequence contributes one.
  lines : UInt64
  /// Number of runs separated by space or bytes `0x09..0x0D`.
  words : UInt64
  /// Number of bytes supplied in the view or across all stream updates.
  bytes : UInt64
}

///|
/// Counts LF bytes, ASCII-delimited words, and bytes in `data` without copying
/// the view. Any byte outside ASCII space and `0x09..0x0D` is part of a word,
/// including embedded NUL and high-bit bytes. An unterminated final word
/// counts once, and the empty view returns three zeros.
///
/// The default `simd=true` requests vectors on native and linear-memory Wasm
/// for views containing at least 16 bytes. Shorter views, Wasm GC, JavaScript,
/// and an explicit `simd=false` use the scalar implementation.
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
