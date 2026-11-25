///|
/// Powers of ten for validated groups of at most sixteen decimal digits.
let decimal_powers : ReadOnlyArray[UInt64] = [
  1UL, 10UL, 100UL, 1000UL, 10000UL, 100000UL, 1000000UL, 10000000UL, 100000000UL,
  1000000000UL, 10000000000UL, 100000000000UL, 1000000000000UL, 10000000000000UL,
  100000000000000UL, 1000000000000000UL, 10000000000000000UL,
]

///|
/// Finds the first non-digit byte of a little-endian word using upstream SWAR.
#inline
fn word_digit_length(word : UInt64) -> Int32 {
  let high = ((word + 0x0606060606060606UL) & 0xF0F0F0F0F0F0F0F0UL) >> 4
  let low = word & 0xF0F0F0F0F0F0F0F0UL
  ((high | low) ^ 0x3333333333333333UL).ctz() / 8
}

///|
/// Reduces eight validated ASCII digits through pairs, quads, and an octet.
#inline
fn reduce_eight(word : UInt64) -> UInt64 {
  // Little-endian byte order puts the earlier digit in the low lane. Each
  // wrapping multiplier combines it with the next digit at weight 10^k.
  let pairs = ((word & 0x0F0F0F0F0F0F0F0FUL) * 0xA01UL) >> 8
  let quads = ((pairs & 0x00FF00FF00FF00FFUL) * 0x640001UL) >> 16
  ((quads & 0x0000FFFF0000FFFFUL) * 0x271000000001UL) >> 32
}

///|
/// Scans bounded eight-byte words and a byte-wise tail for an ASCII digit prefix.
fn scalar_digit_length(data : BytesView) -> Int32 {
  for rest = data, count = 0 {
    match rest {
      [u64le(word), .. tail] => {
        let length = word_digit_length(word)
        if length < 8 {
          break count + length
        }
        continue tail, count + 8
      }
      [b'0'..<=b'9', .. tail] => continue tail, count + 1
      _ => break count
    }
  }
}

///|
/// Counts leading ASCII zeroes with bounded word loads and a byte-wise tail.
/// Local complete-operation measurements favor this SWAR scan for both requests
/// on native and Wasm; optional SIMD applies to the significant digits that follow.
fn scalar_zero_length(data : BytesView) -> Int32 {
  for rest = data, count = 0 {
    match rest {
      [u64le(word), .. tail] => {
        let length = (word ^ 0x3030303030303030UL).ctz() / 8
        if length < 8 {
          break count + length
        }
        continue tail, count + 8
      }
      [b'0', .. tail] => continue tail, count + 1
      _ => break count
    }
  }
}

///|
/// Reads eight validated digits using SWAR, or reduces a short remainder.
fn scalar_decimal_group(data : BytesView) -> (UInt64, Int32) {
  match data {
    [u64le(word), ..] => (reduce_eight(word), 8)
    _ => {
      let mut value = 0UL
      for byte in data {
        value = value * 10UL + (byte.to_uint64() - 48UL)
      }
      (value, data.length())
    }
  }
}
