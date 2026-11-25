# UTF-8 examples

```mbt check
///|
test "validate and decode UTF-8" {
  let data = b"I \xE2\x9D\xA4 UTF-8!"
  assert_true(@utf8.is_valid(data))
  assert_eq(@utf8.from_utf8(data), "I ❤ UTF-8!")
  assert_true(!@utf8.is_valid(b"\xED\xA0\x80"))
}
```

```mbt check
///|
test "complete a streamed multibyte sequence" {
  let state = @utf8.Validator::new()
  state.update(b"\xF0\x9F")
  assert_true(!state.finalize())
  state.update(b"\x98\x80")
  assert_true(state.finalize())
  let branch = state.copy()
  branch.update(b"\xFF")
  assert_true(!branch.finalize())
  assert_true(state.finalize())
}
```
