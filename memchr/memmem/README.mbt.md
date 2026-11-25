# Checked substring-search examples

```mbt check
///|
test "reusable finders and non-overlapping matches" {
  let finder = @memmem.Finder::new(b"aba")
  assert_eq(finder.find(b"ababa"), Some(0))
  assert_eq(finder.find_iter(b"ababa").iter().to_array(), [0])
  assert_eq(@memmem.rfind_iter(b"ababa", b"aba").iter().to_array(), [2])
  assert_eq(@memmem.find_iter(b"\xC3\xA9", b"").iter().to_array(), [0, 1, 2])
}
```
