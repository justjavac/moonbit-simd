# Byte and UTF-8 code point counts

```mbt check
///|
test "count bytes in a view" {
  let input = b"|cat dog fox|"
  assert_eq(@bytecount.count(input[1:12], b' '), 2)
}

///|
test "count UTF-8 code points" {
  assert_eq(@bytecount.num_chars(b"A\xC3\xA9\xF0\x9F\x98\x80"), 3)
}
```
