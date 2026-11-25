///|
/// Stores immutable Two-Way factorization, an approximate byte set, and a pair.
priv struct Searcher {
  critical : Int32
  shift : Int32
  periodic : Bool
  byteset : UInt64
  index1 : Int32
  index2 : Int32
}

///|
/// Computes a maximal or minimal suffix and its period without reversing input.
fn suffix(
  needle : BytesView,
  maximal~ : Bool,
  reverse~ : Bool,
) -> (Int32, Int32) {
  let length = needle.length()
  let mut start = 0
  let mut period = 1
  let mut candidate = 1
  let mut offset = 0
  while candidate < length - offset {
    let current = if reverse {
      needle[length - 1 - start - offset]
    } else {
      needle[start + offset]
    }
    let other = if reverse {
      needle[length - 1 - candidate - offset]
    } else {
      needle[candidate + offset]
    }
    if current == other {
      if offset + 1 == period {
        candidate = candidate + period
        offset = 0
      } else {
        offset = offset + 1
      }
    } else if (maximal && other > current) || (!maximal && other < current) {
      start = candidate
      period = 1
      candidate = candidate + 1
      offset = 0
    } else {
      candidate = candidate + offset + 1
      offset = 0
      period = candidate - start
    }
  }
  (if reverse { length - start } else { start }, period)
}

///|
/// Selects the two predictive byte positions using upstream's pinned rank table.
fn rare_pair(needle : BytesView) -> (Int32, Int32) {
  let mut first = 0
  let mut second = 1
  if frequency_rank[needle[second].to_int()] <
    frequency_rank[needle[first].to_int()] {
    let previous = first
    first = second
    second = previous
  }
  // The upstream pair considers positions below 255; all rank indices are bytes.
  for index in 2..<needle.length().min(255) {
    let rank = frequency_rank[needle[index].to_int()]
    if rank < frequency_rank[needle[first].to_int()] {
      second = first
      first = index
    } else if needle[index] != needle[first] &&
      rank < frequency_rank[needle[second].to_int()] {
      second = index
    }
  }
  (first, second)
}

///|
/// Preprocesses the needle in linear time with constant auxiliary space.
fn preprocess(needle : BytesView, reverse~ : Bool) -> Searcher {
  let length = needle.length()
  let mut byteset = 0UL
  for byte in needle {
    byteset = byteset | (1UL << (byte.to_int() & 63))
  }
  if length < 2 {
    return {
      critical: if reverse {
        length
      } else {
        0
      },
      shift: 1,
      periodic: true,
      byteset,
      index1: 0,
      index2: 0,
    }
  }
  let minimum = suffix(needle, maximal=false, reverse~)
  let maximum = suffix(needle, maximal=true, reverse~)
  let (critical, period) = if (reverse && minimum.0 < maximum.0) ||
    (!reverse && minimum.0 > maximum.0) {
    minimum
  } else {
    maximum
  }
  // Comparing the two lengths avoids overflowing a doubled Int32 position.
  let periodic = if reverse {
    length - critical < critical &&
    needle[critical - period:critical].has_prefix(needle[critical:])
  } else {
    critical < length - critical &&
    needle[critical:critical + period].has_suffix(needle[:critical])
  }
  let (index1, index2) = rare_pair(needle)
  {
    critical,
    shift: if periodic {
      period
    } else {
      critical.max(length - critical)
    },
    periodic,
    byteset,
    index1,
    index2,
  }
}

///|
/// Rejects a byte only when it is certainly absent from the entire needle.
#inline
fn Searcher::contains(self : Searcher, byte : Byte) -> Bool {
  (self.byteset & (1UL << (byte.to_int() & 63))) != 0UL
}
