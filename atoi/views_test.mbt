///|
test "offset views and every tail length exclude surrounding sentinel bytes" {
  for offset in 0..<32 {
    for length in 0..<=65 {
      let body = if length == 0 {
        b""
      } else {
        Bytes::make(length - 1, b'0') + b"7"
      }
      let backing = Bytes::make(offset, b'\xFF') + body + b"99\xFF"
      let view = backing[offset:offset + length]
      for simd in [false, true] {
        if length == 0 {
          expect_error(
            () => (@atoi.parse(view, skip_zeroes=true, simd~) : UInt64),
            @atoi.Empty,
          )
        } else {
          let value : UInt64 = @atoi.parse(view, skip_zeroes=true, simd~)
          let wide : @atoi.UInt128 = @atoi.parse(view, skip_zeroes=true, simd~)
          assert_eq(value, 7UL)
          assert_eq(wide.to_string(), "7")
          let prefix : (UInt64, Int32) = @atoi.parse_prefix(
            view,
            skip_zeroes=true,
            simd~,
          )
          assert_eq(prefix, (7UL, length))
        }
      }
    }
  }
}

///|
test "invalid bytes at each vector position retain exact prefix boundaries" {
  for length in [16, 17, 19, 20, 31, 32, 33, 39] {
    for position in 0..<length {
      for bad in [b'/', b':', b'\x00', b'\x80', b'\xFF'] {
        let input = Bytes::make(position, b'0') +
          Bytes::make(1, bad) +
          Bytes::make(length - position - 1, b'9')
        for simd in [false, true] {
          if position == 0 {
            expect_error(
              () => {
                (
                  @atoi.parse_prefix(input, skip_zeroes=true, simd~) :
                  (UInt64, Int32))
              },
              @atoi.Empty,
            )
          } else {
            let prefix : (UInt64, Int32) = @atoi.parse_prefix(
              input,
              skip_zeroes=true,
              simd~,
            )
            assert_eq(prefix, (0UL, position))
            expect_error(
              () => (@atoi.parse(input, skip_zeroes=true, simd~) : UInt64),
              @atoi.Invalid64(0UL, position, input),
            )
          }
        }
      }
    }
  }
}

///|
test "errors retain the exact input subview rather than unrelated backing bytes" {
  let backing = b"outside+000123xunrelated"
  let view = backing[7:15]
  try (@atoi.parse(view, skip_plus=true) : Int64) catch {
    @atoi.Invalid64(value, position, stored) => {
      assert_eq(value, 123UL)
      assert_eq(position, 6)
      assert_true(stored == b"000123x")
      assert_eq(stored.start_offset(), 8)
      assert_true(stored.data() == backing)
    }
    _ => fail("Expected an invalid suffix with a retained view")
  } noraise {
    _ => fail("Expected an invalid suffix")
  }
}

///|
test "word access and decimal formatting remain exact for all 128-bit signs" {
  let zero = @atoi.UInt128::from_words(high=0UL, low=0UL)
  assert_eq(zero.to_string(), "0")
  let negative_one = @atoi.Int128::from_bits(
    @atoi.UInt128::from_words(
      high=0xFFFFFFFFFFFFFFFFUL,
      low=0xFFFFFFFFFFFFFFFFUL,
    ),
  )
  assert_eq(negative_one.to_string(), "-1")
  let mut seed = 0xC0FFEEUL
  for _ in 0..<128 {
    seed = seed * 6364136223846793005UL + 1442695040888963407UL
    let high = seed
    seed = seed * 6364136223846793005UL + 1442695040888963407UL
    let low = seed
    let value = @atoi.UInt128::from_words(high~, low~)
    let unsigned = (@bigint.BigInt::from_uint64(high) << 64) +
      @bigint.BigInt::from_uint64(low)
    assert_eq(value.to_string(), unsigned.to_string())
    let parsed : @atoi.UInt128 = @atoi.parse(@utf8.encode(value.to_string()))
    assert_eq(parsed, value)
    let signed = @atoi.Int128::from_bits(value)
    let expected = if high >> 63 != 0 {
      unsigned - (1N << 128)
    } else {
      unsigned
    }
    assert_eq(signed.to_string(), expected.to_string())
    let parsed : @atoi.Int128 = @atoi.parse(@utf8.encode(signed.to_string()))
    assert_eq(parsed, signed)
  }
}
