///|
test "overlapping forward and reverse choices have independent non-overlap semantics" {
  for simd in [false, true] {
    assert_eq(@memmem.find_iter(b"ababa", b"aba", simd~).iter().to_array(), [0])
    assert_eq(@memmem.rfind_iter(b"ababa", b"aba", simd~).iter().to_array(), [2])
    assert_eq(@memmem.find_iter(b"aaaaaaa", b"aaa", simd~).iter().to_array(), [
      0, 3,
    ])
    assert_eq(@memmem.rfind_iter(b"aaaaaaa", b"aaa", simd~).iter().to_array(), [
      4, 1,
    ])
  }
}

///|
test "forward substring cursor aliases mutate while copies and reusable finders stay independent" {
  for needle in [b"aba", b""] {
    let finder = @memmem.Finder::new(
      (b"!" + needle + b"?")[1:1 + needle.length()],
    )
    let haystack = b"!ababa aba?"[1:10]
    let expected = reference_matches(haystack, needle, reverse=false)
    let cursor = finder.find_iter(haystack)
    let shared = cursor
    assert_eq(shared.next(), expected.get(0))
    let copy = cursor.copy()
    assert_eq(cursor.iter().to_array(), expected[1:].to_owned())
    assert_eq(shared.next(), None)
    assert_eq(copy.iter().to_array(), expected[1:].to_owned())
    assert_eq(copy.next(), None)
    assert_eq(copy.copy().next(), None)
    assert_eq(finder.find_iter(haystack).iter().to_array(), expected)
    assert_eq(finder.needle(), needle[:])
  }
}

///|
test "reverse substring cursor copies preserve progress including zero empty boundary" {
  for needle in [b"aba", b""] {
    let finder = @memmem.FinderRev::new(needle)
    let haystack = b"ababa aba"
    let expected = reference_matches(haystack, needle, reverse=true)
    let cursor = finder.rfind_iter(haystack)
    let shared = cursor
    assert_eq(shared.next(), expected.get(0))
    let copy = cursor.copy()
    assert_eq(cursor.iter().to_array(), expected[1:].to_owned())
    assert_eq(shared.next(), None)
    assert_eq(copy.iter().to_array(), expected[1:].to_owned())
    assert_eq(copy.next(), None)
    assert_eq(copy.copy().next(), None)
    assert_eq(finder.rfind_iter(haystack).iter().to_array(), expected)
    assert_eq(finder.needle(), needle[:])
  }
}
