///|
test "empty views and exact byte matches" {
  let data = b"\xFF\x00\x01\xFF\x00\x02\xFF"
  let view = data[1:6]
  assert_eq(@bytecount.count(data[3:3], 0xFF), 0)
  assert_eq(@bytecount.count(view, 0x00), 2)
  assert_eq(@bytecount.count(view, 0xFF), 1)
  assert_eq(@bytecount.count(view, 0x7F), 0)
  assert_eq(@bytecount.naive_count(view, 0x00), 2)
  assert_eq(@bytecount.naive_count_32(view, 0xFF), 1)
  assert_eq(@bytecount.num_chars(data[3:3]), 0)
  assert_eq(@bytecount.naive_num_chars(data[3:3]), 0)
}

///|
test "non-continuation counts on valid and malformed UTF-8" {
  // BOM, ASCII, a combining mark, a three-byte character, and an emoji.
  let text = b"\xEF\xBB\xBFa\xCC\x81\xE6\xBC\xA2\xF0\x9F\x98\x80"
  assert_eq(@bytecount.num_chars(text), 5)
  assert_eq(@bytecount.naive_num_chars(text), 5)
  assert_eq(@bytecount.num_chars(text[1:]), 4)
  let malformed = b"\x80\xBF\xC0\xC1\xFE\xFF\xF0\x9F"
  assert_eq(@bytecount.num_chars(malformed), 5)
  assert_eq(@bytecount.naive_num_chars(malformed), 5)
}

///|
test "every needle and continuation class on unaligned views" {
  let bytes = Bytes::makei(544, i => i.to_byte())
  for offset in [0, 1, 7, 15] {
    let data = bytes[offset:offset + 512]
    for needle = 0; needle < 256; needle = needle + 1 {
      assert_eq(@bytecount.count(data, needle.to_byte()), 2)
    }
    assert_eq(@bytecount.num_chars(data), 384)
  }
}

///|
test "word and vector tails stay inside the view" {
  let bytes = Bytes::makei(304, i => if i % 4 == 0 { 0x80 } else { 0x00 })
  for start = 0; start < 16; start = start + 1 {
    for length = 0; length <= 288; length = length + 1 {
      let data = bytes[start:start + length]
      let continuations = (start + length + 3) / 4 - (start + 3) / 4
      assert_eq(@bytecount.count(data, 0x80), continuations)
      assert_eq(@bytecount.count(data, 0x00), length - continuations)
      assert_eq(@bytecount.num_chars(data), length - continuations)
    }
  }
}

///|
test "dense matches across byte-lane accumulator limits" {
  for
    length in [
      4079, 4080, 4081, 4095, 4096, 4097, 8159, 8160, 8161, 16320, 16321, 65539,
    ] {
    let ascii = Bytes::make(length + 3, b'x')
    let continuation = Bytes::make(length + 3, 0xBF)
    let ascii = ascii[1:length + 1]
    let continuation = continuation[1:length + 1]
    assert_eq(@bytecount.count(ascii, b'x'), length)
    assert_eq(@bytecount.count(ascii, b'y'), 0)
    assert_eq(@bytecount.count(continuation, 0xBF), length)
    assert_eq(@bytecount.num_chars(ascii), length)
    assert_eq(@bytecount.num_chars(continuation), 0)
  }
}

///|
test "mixed byte classes across batches in a partial view" {
  let bytes = Bytes::makei(16400, i => i.to_byte())
  let data = bytes[1:16386]
  // 64 full cycles of all bytes, followed by one additional ASCII byte.
  assert_eq(@bytecount.count(data, 0x01), 65)
  assert_eq(@bytecount.count(data, 0x00), 64)
  assert_eq(@bytecount.count(data, 0xFF), 64)
  assert_eq(@bytecount.num_chars(data), 64 * 192 + 1)
}
