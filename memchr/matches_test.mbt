///|
test "mixed double-ended consumption is unique and assignments share progress" {
  for simd in [false, true] {
    for reverse in [false, true] {
      let source = b"!a!b!c!a!b!c!"
      let cursor = if reverse {
        @memchr.memrchr3_iter(b'a', b'b', b'c', source[1:12], simd~)
      } else {
        @memchr.memchr3_iter(b'a', b'b', b'c', source[1:12], simd~)
      }
      let shared = cursor
      assert_eq(shared.next(), Some(if reverse { 10 } else { 0 }))
      let copy = cursor.copy()
      assert_eq(cursor.next_back(), Some(if reverse { 0 } else { 10 }))
      assert_eq(shared.next(), Some(if reverse { 8 } else { 2 }))
      assert_eq(cursor.next_back(), Some(if reverse { 2 } else { 8 }))
      assert_eq(cursor.count(), 2)
      assert_eq(shared.next(), None)
      assert_eq(copy.count(), 5)
      assert_eq(copy.next_back(), None)
      assert_eq(cursor.iter().count(), 0)
    }
  }
}

///|
test "independent cursor copies retain original input and partial progress" {
  for simd in [false, true] {
    let cursor = @memchr.memchr_iter(b'o', b"foo bar foo", simd~)
    assert_eq(cursor.next(), Some(1))
    let copy = cursor.copy()
    assert_eq(cursor.iter().to_array(), [2, 9, 10])
    assert_eq(copy.next_back(), Some(10))
    assert_eq(copy.iter().to_array(), [2, 9])
    assert_eq(cursor.next_back(), None)
    let empty = @memchr.memrchr_iter(0, b"", simd~)
    assert_eq(empty.next_back(), None)
    assert_eq(empty.copy().next(), None)
    assert_eq(empty.count(), 0)
  }
}
