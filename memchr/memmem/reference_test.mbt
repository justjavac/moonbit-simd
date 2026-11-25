///|
/// Checks a candidate with independent per-byte equality and explicit lengths.
fn reference_at(
  haystack : BytesView,
  needle : BytesView,
  start : Int32,
) -> Bool {
  if needle.length() > haystack.length() - start {
    return false
  }
  for index in 0..<needle.length() {
    if haystack[start + index] != needle[index] {
      return false
    }
  }
  true
}

///|
/// Computes the first and last match independently of all production algorithms.
fn reference_find(haystack : BytesView, needle : BytesView) -> (Int32?, Int32?) {
  if needle.length() > haystack.length() {
    return (None, None)
  }
  let mut first = None
  let mut last = None
  for index in 0..<=(haystack.length() - needle.length()) {
    if reference_at(haystack, needle, index) {
      if first is None {
        first = Some(index)
      }
      last = Some(index)
    }
  }
  (first, last)
}

///|
/// Computes directional non-overlapping matches with a naive candidate loop.
fn reference_matches(
  haystack : BytesView,
  needle : BytesView,
  reverse~ : Bool,
) -> Array[Int32] {
  let positions = []
  if needle.length() > haystack.length() {
    return positions
  }
  if needle.is_empty() {
    for index in 0..<=haystack.length() {
      positions.push(if reverse { haystack.length() - index } else { index })
    }
    return positions
  }
  if reverse {
    let mut end = haystack.length()
    while end >= needle.length() {
      if reference_at(haystack, needle, end - needle.length()) {
        positions.push(end - needle.length())
        end = end - needle.length()
      } else {
        end = end - 1
      }
    }
  } else {
    let mut start = 0
    while start <= haystack.length() - needle.length() {
      if reference_at(haystack, needle, start) {
        positions.push(start)
        start = start + needle.length()
      } else {
        start = start + 1
      }
    }
  }
  positions
}

///|
/// Compares public one-off and reusable search APIs against an independent oracle.
fn verify_substring(
  haystack : BytesView,
  needle : BytesView,
  iterators~ : Bool = false,
) -> Unit raise {
  let (first, last) = reference_find(haystack, needle)
  for simd in [false, true] {
    for prefilter in [@memmem.Auto, @memmem.None] {
      let finder = @memmem.Finder::new(needle, simd~, prefilter~)
      assert_eq(finder.find(haystack), first)
      assert_eq(@memmem.find(haystack, needle, simd~, prefilter~), first)
      assert_eq(finder.needle(), needle)
      assert_eq(finder.find(haystack), first)
      if iterators {
        let expected = reference_matches(haystack, needle, reverse=false)
        assert_eq(finder.find_iter(haystack).iter().to_array(), expected)
        assert_eq(
          @memmem.find_iter(haystack, needle, simd~, prefilter~)
          .iter()
          .to_array(),
          expected,
        )
      }
    }
    let finder = @memmem.FinderRev::new(needle, simd~)
    assert_eq(finder.rfind(haystack), last)
    assert_eq(@memmem.rfind(haystack, needle, simd~), last)
    assert_eq(finder.needle(), needle)
    assert_eq(finder.rfind(haystack), last)
    if iterators {
      let expected = reference_matches(haystack, needle, reverse=true)
      assert_eq(finder.rfind_iter(haystack).iter().to_array(), expected)
      assert_eq(
        @memmem.rfind_iter(haystack, needle, simd~).iter().to_array(),
        expected,
      )
    }
  }
}

///|
test "exhaustive binary haystacks and needles cover both periodic factorizations" {
  for hay_length in 0..<=8 {
    for hay_bits in 0..<(1 << hay_length) {
      let haystack = Bytes::makei(hay_length, index => {
        ((hay_bits >> index) & 1).to_byte()
      })
      for needle_length in 0..<=5 {
        for needle_bits in 0..<(1 << needle_length) {
          let needle = Bytes::makei(needle_length, index => {
            ((needle_bits >> index) & 1).to_byte()
          })
          verify_substring(haystack, needle)
        }
      }
    }
  }
}

///|
test "deterministic arbitrary bytes and retained offset needles match independent scans" {
  let mut seed = 0xF371A085U
  for case in 0..<500 {
    seed = seed * 1664525U + 1013904223U
    let length = (seed % 513U).reinterpret_as_int()
    let data = Bytes::makei(length + 34, _ => {
      seed = seed * 1664525U + 1013904223U
      (seed >> 24).to_byte()
    })
    let offset = case % 32
    let haystack = data[offset:offset + length]
    seed = seed * 1664525U + 1013904223U
    let needle_length = (seed % 97U).reinterpret_as_int()
    let needle = if case % 2 == 0 && length > 0 {
      let start = (seed % length.reinterpret_as_uint()).reinterpret_as_int()
      haystack[start:(start + needle_length).min(length)]
    } else {
      let owned = Bytes::makei(needle_length + 2, _ => {
        seed = seed * 1664525U + 1013904223U
        (seed >> 24).to_byte()
      })
      owned[1:1 + needle_length]
    }
    verify_substring(haystack, needle, iterators=true)
  }
}
