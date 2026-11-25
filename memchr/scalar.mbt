///|
/// Repeats a byte in all eight little-endian lanes of a word.
#cfg(not(target="js"))
#inline
fn splat_word(byte : Byte) -> UInt64 {
  byte.to_uint64() * 0x0101010101010101UL
}

///|
/// Marks exactly the zero bytes, avoiding the borrow false positives of haszero.
#cfg(not(target="js"))
#inline
fn zero_bytes(word : UInt64) -> UInt64 {
  // Masked lanes are <= 127; adding 127 never carries into another lane.
  // A lane's high bit stays zero exactly when the original byte was zero.
  let low = 0x7F7F7F7F7F7F7F7FUL
  (((word & low) + low) | word | low).lnot() & 0x8080808080808080UL
}

///|
/// Combines exact equality masks so duplicate values never inflate counts.
#cfg(not(target="js"))
#inline
fn word_mask(
  word : UInt64,
  a : UInt64,
  b : UInt64,
  c : UInt64,
  arity : Int32,
) -> UInt64 {
  let mask = zero_bytes(word ^ a)
  if arity == 1 {
    mask
  } else if arity == 2 {
    mask | zero_bytes(word ^ b)
  } else {
    mask | zero_bytes(word ^ b) | zero_bytes(word ^ c)
  }
}

///|
/// Finds the first matching byte using complete eight-byte words and a scalar tail.
#cfg(not(target="js"))
fn scalar_find(needles : Needles, data : BytesView) -> Int32? {
  let (a, b, c, arity) = needles.values()
  let (a, b, c) = (splat_word(a), splat_word(b), splat_word(c))
  for rest = data, offset = 0 {
    match rest {
      [u64le(word), .. tail] => {
        let mask = word_mask(word, a, b, c, arity)
        if mask != 0UL {
          break Some(offset + mask.ctz() / 8)
        }
        continue tail, offset + 8
      }
      _ => {
        for index, byte in rest {
          if needles.contains(byte) {
            return Some(offset + index)
          }
        }
        break None
      }
    }
  }
}

///|
/// Finds the last matching byte with word loads bounded by the actual view.
#cfg(not(target="js"))
fn scalar_rfind(needles : Needles, data : BytesView) -> Int32? {
  let (a, b, c, arity) = needles.values()
  let (a, b, c) = (splat_word(a), splat_word(b), splat_word(c))
  let end = for end = data.length(); end >= 8; end = end - 8 {
    // This view is exactly eight bytes, independently of the backing buffer.
    if data[end - 8:end] is [u64le(word), ..] {
      let mask = word_mask(word, a, b, c, arity)
      if mask != 0UL {
        return Some(end - 1 - mask.clz() / 8)
      }
    }
  } nobreak {
    end
  }
  for index = end; index > 0; index = index - 1 {
    if needles.contains(data[index - 1]) {
      return Some(index - 1)
    }
  }
  None
}

///|
/// Counts matching bytes with exact SWAR masks and a per-byte remainder.
#cfg(not(target="js"))
fn scalar_count(needles : Needles, data : BytesView) -> Int32 {
  let (a, b, c, arity) = needles.values()
  let (a, b, c) = (splat_word(a), splat_word(b), splat_word(c))
  for rest = data, count = 0 {
    match rest {
      [u64le(word), .. tail] =>
        continue tail, count + word_mask(word, a, b, c, arity).popcnt()
      _ => {
        let mut count = count
        for byte in rest {
          if needles.contains(byte) {
            count = count + 1
          }
        }
        break count
      }
    }
  }
}
