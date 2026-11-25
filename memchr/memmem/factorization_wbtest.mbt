///|
/// Compares suffixes until their first differing byte, treating shared prefixes as ties.
fn compare_suffixes(data : BytesView, left : Int32, right : Int32) -> Int32 {
  for offset in 0..<(data.length() - left).min(data.length() - right) {
    if data[left + offset] < data[right + offset] {
      return -1
    }
    if data[left + offset] > data[right + offset] {
      return 1
    }
  }
  0
}

///|
/// Computes the exact finite-string period by testing every possible displacement.
fn reference_period(data : BytesView) -> Int32 {
  for period in 1..<=data.length() {
    let mut valid = true
    for index in period..<data.length() {
      if data[index] != data[index - period] {
        valid = false
        break
      }
    }
    if valid {
      return period
    }
  }
  1
}

///|
test "suffix and period extraction agrees with an independent cubic oracle" {
  for length in 0..<=8 {
    for bits in 0..<(1 << length) {
      let input = Bytes::makei(length, index => ((bits >> index) & 1).to_byte())
      for reverse in [false, true] {
        let data = if reverse {
          Bytes::makei(length, index => input[length - index - 1])
        } else {
          input
        }
        for maximal in [false, true] {
          let mut best = 0
          for candidate in 1..<length {
            let order = compare_suffixes(data, candidate, best)
            if (maximal && order > 0) || (!maximal && order < 0) {
              best = candidate
            }
          }
          let (position, period) = suffix(input, maximal~, reverse~)
          assert_eq(position, if reverse { length - best } else { best })
          assert_eq(period, reference_period(data[best:]))
        }
      }
    }
  }
}

///|
test "ranked pairs stay distinct and approximate sets never lose needle bytes" {
  assert_eq(frequency_rank.length(), 256)
  for byte in 0..<256 {
    let needle = Bytes::make(300, byte.to_byte())
    let searcher = preprocess(needle, reverse=false)
    assert_eq((searcher.index1, searcher.index2), (0, 1))
    assert_true(searcher.contains(byte.to_byte()))
    for other in 0..<256 {
      assert_eq(searcher.contains(other.to_byte()), other % 64 == byte % 64)
    }
  }
  let all_bytes = Bytes::makei(256, index => index.to_byte())
  let searcher = preprocess(all_bytes, reverse=false)
  assert_true(searcher.index1 != searcher.index2)
  assert_true(searcher.index1 < 255 && searcher.index2 < 255)
  for byte in all_bytes {
    assert_true(searcher.contains(byte))
  }
}

///|
test "candidate vectors use the exact view and every remaining tail length" {
  for needle_length in [2, 3, 7, 17, 65, 256] {
    let needle = Bytes::makei(needle_length, index => {
      (index * 41 + 17).to_byte()
    })
    let searcher = preprocess(needle, reverse=false)
    for starts in 1..<=80 {
      for offset in [0, 1, 3, 15] {
        let length = starts + needle_length - 1
        let backing = needle +
          Bytes::make(offset, 0) +
          Bytes::makei(length, index => needle[index % needle_length]) +
          needle
        let data = backing[needle_length + offset:needle_length +
          offset +
          length]
        let expected : Int32? = for position in 0..<starts {
          if data[position + searcher.index1] == needle[searcher.index1] &&
            data[position + searcher.index2] == needle[searcher.index2] {
            break Some(position)
          }
        } nobreak {
          None
        }
        assert_eq(scalar_pair(needle, data, searcher), expected)
        assert_eq(vector_pair(needle, data, searcher), expected)
      }
    }
  }
}
