///|
test "empty needles match every byte boundary including inside UTF-8" {
  for data in [b"", b"a", b"\xC3\xA9", b"\xF0\x9F\x98\x80", b"\x00\xFF"] {
    verify_substring(data, b"", iterators=true)
  }
  verify_substring(b"\xC3\xA9\xC3\xA9", b"\xA9\xC3", iterators=true)
  verify_substring(b"\x00\x01\x00\xFF\x00\x01", b"\x00\x01", iterators=true)
}

///|
test "all vector tails and view offsets exclude matches outside the haystack" {
  for length in 0..<=80 {
    for offset in [0, 1, 3, 7, 15, 16, 31] {
      for
        pattern in [
          b"a", b"ab", b"aba", b"\x00\xFF", b"abcdefg", b"aaaaaaaaaaaaaaaaa",
        ] {
        let middle = Bytes::makei(length, index => {
          if index % 11 < 3 {
            b"aba"[index % 11]
          } else {
            b'x'
          }
        })
        let prefix = pattern + Bytes::make(offset, b'#')
        let backing = prefix + middle + pattern
        let data = backing[prefix.length():prefix.length() + length]
        let needles = b"!" + pattern + b"?"
        verify_substring(data, needles[1:needles.length() - 1], iterators=true)
      }
    }
  }
}

///|
test "repeated, periodic, and approximate-byte-set collisions remain distinct" {
  for
    length in [2, 3, 7, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 255, 256, 257] {
    let a = Bytes::make(length, b'a')
    let periodic = b"ab".repeat(length / 2) +
      (if length % 2 == 1 { b"a" } else { b"" })
    for needle in [a, periodic, b"z" + a + b"x", a + b"z", b"z" + a] {
      let haystack = b"a".repeat(2048) +
        b"ab".repeat(512) +
        needle +
        needle +
        b"z"
      verify_substring(
        haystack[1:haystack.length() - 1],
        needle,
        iterators=true,
      )
    }
  }
  let all_bytes = Bytes::makei(256, index => index.to_byte())
  verify_substring(all_bytes + all_bytes, all_bytes, iterators=true)
  verify_substring(
    b"\x00\x40\x80\xC0".repeat(128),
    b"\x00\x80\x40",
    iterators=true,
  )
  assert_eq(@memmem.rfind(b"ababaz", b"abab"), Some(0))
}

///|
test "long adversarial pair collisions preserve exact results after filter shutdown" {
  let needle = b"a".repeat(1024) + b"b" + b"a".repeat(1024)
  let haystack = (b"a".repeat(1024) + b"b" + b"a".repeat(1023) + b"x").repeat(
      64,
    ) +
    needle
  for simd in [false, true] {
    assert_eq(
      @memmem.find(haystack, needle, simd~),
      Some(haystack.length() - needle.length()),
    )
    assert_eq(
      @memmem.find(haystack, needle, simd~, prefilter=@memmem.None),
      Some(haystack.length() - needle.length()),
    )
    assert_eq(
      @memmem.rfind(haystack, needle, simd~),
      Some(haystack.length() - needle.length()),
    )
  }
}
