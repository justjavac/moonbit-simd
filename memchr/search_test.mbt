///|
/// Computes matching positions independently with one comparison per input byte.
fn reference_positions(
  data : BytesView,
  a : Byte,
  b : Byte,
  c : Byte,
  arity : Int32,
) -> Array[Int32] {
  let result = []
  for index, byte in data {
    if byte == a || (arity >= 2 && byte == b) || (arity == 3 && byte == c) {
      result.push(index)
    }
  }
  result
}

///|
/// Checks every public byte operation against independently collected positions.
fn verify_bytes(data : BytesView, a : Byte, b : Byte, c : Byte) -> Unit raise {
  for simd in [false, true] {
    for arity in 1..<=3 {
      let expected = reference_positions(data, a, b, c, arity)
      let (first, last, forward, reverse) = match arity {
        1 =>
          (
            @memchr.memchr(a, data, simd~),
            @memchr.memrchr(a, data, simd~),
            @memchr.memchr_iter(a, data, simd~),
            @memchr.memrchr_iter(a, data, simd~),
          )
        2 =>
          (
            @memchr.memchr2(a, b, data, simd~),
            @memchr.memrchr2(a, b, data, simd~),
            @memchr.memchr2_iter(a, b, data, simd~),
            @memchr.memrchr2_iter(a, b, data, simd~),
          )
        _ =>
          (
            @memchr.memchr3(a, b, c, data, simd~),
            @memchr.memrchr3(a, b, c, data, simd~),
            @memchr.memchr3_iter(a, b, c, data, simd~),
            @memchr.memrchr3_iter(a, b, c, data, simd~),
          )
      }
      assert_eq(first, expected.get(0))
      assert_eq(last, expected.last())
      assert_eq(forward.copy().count(), expected.length())
      assert_eq(reverse.copy().count(), expected.length())
      assert_eq(forward.iter().to_array(), expected)
      assert_eq(reverse.iter().to_array(), expected.rev())
      assert_eq(forward.next(), None)
      assert_eq(forward.next_back(), None)
      assert_eq(reverse.next(), None)
      assert_eq(reverse.next_back(), None)
      assert_eq(forward.count(), 0)
    }
  }
}

///|
test "empty input, NUL, arbitrary bytes, and duplicate needle unions" {
  for data in [b"", b"\x00", b"\xFF", b"\x00\x01\x00\xFF\x80\x7F", b"abcabcxyz"] {
    verify_bytes(data, 0, 1, 255)
    verify_bytes(data, 255, 255, 255)
    verify_bytes(data, b'a', b'z', b'a')
  }
  assert_eq(@memchr.memchr(0xA9, b"\xC3\xA9"), Some(1))
}

///|
test "every short length and offset view excludes matching outside bytes" {
  for length in 0..<=80 {
    for offset in 0..<=31 {
      let backing = Bytes::makei(offset + length + 17, index => {
        if index < offset || index >= offset + length {
          0
        } else {
          let index = index - offset
          match index % 11 {
            0 => 0
            1 => 1
            2 => 255
            _ => ((index * 37 + length * 19) & 255).to_byte()
          }
        }
      })
      let data = backing[offset:offset + length]
      verify_bytes(data, 0, 1, 255)
      verify_bytes(data, 128, 128, 127)
    }
  }
}

///|
test "every byte value and matching lane has independent first and last offsets" {
  for value in 0..<256 {
    let needle = value.to_byte()
    for position in 0..<33 {
      let data = Bytes::makei(33, index => {
        if index == position {
          needle
        } else {
          (value ^ 1).to_byte()
        }
      })
      for simd in [false, true] {
        assert_eq(@memchr.memchr(needle, data, simd~), Some(position))
        assert_eq(@memchr.memrchr(needle, data, simd~), Some(position))
        assert_eq(
          @memchr.memchr3_iter(needle, needle, needle, data, simd~).count(),
          1,
        )
      }
    }
  }
}

///|
test "large dense and sparse inputs count each position once" {
  let dense = Bytes::make(65536, 255)
  for simd in [false, true] {
    assert_eq(@memchr.memchr3_iter(255, 255, 255, dense, simd~).count(), 65536)
    assert_eq(@memchr.memrchr2_iter(255, 255, dense, simd~).count(), 65536)
    assert_eq(@memchr.memchr(0, dense, simd~), None)
    assert_eq(@memchr.memrchr(0, dense, simd~), None)
  }
  let varied = Bytes::makei(2049, index => (index * 131 + index / 7).to_byte())
  for value in 0..<256 {
    verify_bytes(
      varied[1:2048],
      value.to_byte(),
      (value ^ 1).to_byte(),
      (value ^ 128).to_byte(),
    )
  }
}
