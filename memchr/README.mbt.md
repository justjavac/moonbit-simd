# Checked byte-search examples

```mbt check
///|
test "byte search and view-relative offsets" {
  assert_eq(@memchr.memchr(b'o', b"foo bar foo"), Some(1))
  assert_eq(@memchr.memrchr(b'o', b"foo bar foo"), Some(10))
  assert_eq(@memchr.memchr2(b' ', b'!', b"foo bar"), Some(3))
  assert_eq(@memchr.memchr3(b'x', b'y', b'z', b"xyz"[1:]), Some(0))
}
```

```mbt check
///|
test "mixed cursor consumption and independent copies" {
  let matches = @memchr.memchr_iter(b'o', b"foo bar foo")
  assert_eq(matches.next(), Some(1))
  let copy = matches.copy()
  assert_eq(matches.next_back(), Some(10))
  assert_eq(matches.count(), 2)
  assert_eq(copy.iter().to_array(), [2, 9, 10])
}
```
