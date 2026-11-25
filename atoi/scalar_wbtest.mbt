///|
/// Provides a byte-wise oracle independent of the upstream SWAR mask.
fn reference_word_length(word : UInt64) -> Int32 {
  for index in 0..<8 {
    let byte = ((word >> (index * 8)) & 255UL).to_byte()
    if byte < b'0' || byte > b'9' {
      return index
    }
  }
  8
}

///|
test "SWAR digit masks match every byte value and a per-byte random oracle" {
  for position in 0..<8 {
    for byte in 0..<=255 {
      let shift = position * 8
      let word = (0x3930393039303930UL & (255UL << shift).lnot()) |
        (byte.to_uint64() << shift)
      assert_eq(word_digit_length(word), reference_word_length(word))
    }
  }
  let mut seed = 0xBAD5EEDUL
  for _ in 0..<4096 {
    seed = seed * 6364136223846793005UL + 1442695040888963407UL
    assert_eq(word_digit_length(seed), reference_word_length(seed))
  }
}

///|
test "SWAR reduction agrees with independent digit accumulation" {
  let mut seed = 0x51A1A5U
  for _ in 0..<1024 {
    let mut word = 0UL
    let mut expected = 0UL
    for position in 0..<8 {
      seed = seed * 1664525U + 1013904223U
      let digit = (seed >> 16) % 10U
      expected = expected * 10UL + digit.to_uint64()
      word = word | ((digit.to_uint64() + 48UL) << (position * 8))
    }
    assert_eq(reduce_eight(word), expected)
  }
  assert_eq(reduce_eight(0x3939393939393939UL), 99999999UL)
}

///|
#cfg(any(target="native", target="wasm"))
test "vector reduction and masks agree with independent scalar oracles" {
  let mut seed = 0x516D128U
  for _ in 0..<512 {
    let mut expected = 0UL
    let bytes = Bytes::makei(16, _ => {
      seed = seed * 1664525U + 1013904223U
      let digit = (seed >> 16) % 10U
      expected = expected * 10UL + digit.to_uint64()
      (digit + 48U).to_byte()
    })
    match bytes {
      [v128le(block)] => {
        assert_eq(reduce_sixteen(block), expected)
        assert_eq(vector_invalid_digits(block), 0)
      }
      _ => fail("Expected exactly one vector")
    }
  }
  for position in 0..<16 {
    for byte in 0..<=255 {
      let bytes = Bytes::makei(16, index => {
        if index == position {
          byte.to_byte()
        } else {
          b'0'
        }
      })
      match bytes {
        [v128le(block)] => {
          let expected = if byte >= 48 && byte <= 57 {
            0
          } else {
            1 << position
          }
          assert_eq(vector_invalid_digits(block), expected)
        }
        _ => fail("Expected exactly one vector")
      }
    }
  }
}
