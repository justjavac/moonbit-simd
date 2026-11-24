# justjavac/crc32

IEEE CRC-32 with streaming updates and checksum combination, licensed under MIT.
See [README.md](README.md) for installation, the full API, and backend details.

```mbt check
///|
test "hash and stream" {
  assert_eq(@crc32.hash(b"123456789"), 0xCBF43926U)
  assert_eq(@crc32.hash(b"123456789", simd=true), 0xCBF43926U)
  let state = @crc32.Hasher::new()
  state.update(b"1234")
  state.update(b"56789")
  assert_eq(state.finalize(), 0xCBF43926U)
}
```

```mbt check
///|
test "combine blocks" {
  let joined = @crc32.combine(@crc32.hash(b"hello"), @crc32.hash(b" world"), 6)
  assert_eq(joined, @crc32.hash(b"hello world"))
}
```
