///|
test "pending suffix excludes complete scalars and retains incomplete or illegal leads" {
  let vectors : Array[(Bytes, Int32)] = [
    (b"", 0),
    (b"abc", 3),
    (b"\xC2\x80", 2),
    (b"\xE2\x82\xAC", 3),
    (b"\xF0\x9F\x98\x80", 4),
    (b"abc\xE2", 3),
    (b"abc\xE2\x82", 3),
    (b"abc\xF0\x9F\x98", 3),
    (b"abc\xFF", 3),
    (b"abc\xC0", 3),
    (b"\x80\x80\x80", 3),
    (b"abc\x80\x80", 5),
  ]
  for (bytes, expected) in vectors {
    assert_eq(pending_suffix_start(bytes), expected)
    assert_eq(pending_suffix_start((b"ignored" + bytes)[7:]), expected)
  }
}
