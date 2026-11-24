# Checked Base64 examples

```mbt check
///|
test "standard padded Base64" {
  assert_eq(
    @base64.standard.encode_to_string(b"hello world"),
    "aGVsbG8gd29ybGQ=",
  )
  assert_eq(@base64.standard.decode_string("aGVsbG8gd29ybGQ="), b"hello world")
}
```

```mbt check
///|
test "URL-safe and WHATWG forgiving decoding" {
  assert_eq(@base64.url_safe_no_pad.encode_to_string(b"\xfb\xff"), "-_8")
  assert_eq(@base64.url_safe_no_pad.decode_string("-_8"), b"\xfb\xff")
  assert_eq(@base64.forgiving_decode_string(" Z h = = \n"), b"f")
}
```
