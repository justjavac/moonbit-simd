# UUID checked examples

```mbt check
///|
test "parse mixed-case UUID and format both spellings" {
  let id = @uuid.parse("67E55044-10b1-426f-9247-BB680e5fe0c8")
  assert_eq(id.format_simple(), "67e5504410b1426f9247bb680e5fe0c8")
  assert_eq(
    id.format_hyphenated(case=@uuid.Upper),
    "67E55044-10B1-426F-9247-BB680E5FE0C8",
  )
}
```

```mbt check
///|
test "write into a reusable guarded byte buffer" {
  let id = @uuid.parse_bytes(b"00000000000000000000000000000000")
  let output : FixedArray[Byte] = FixedArray::make(34, b'!')
  id.write_simple(output, offset=1)
  assert_eq(Bytes::from_array(output), b"!00000000000000000000000000000000!")
}
```
