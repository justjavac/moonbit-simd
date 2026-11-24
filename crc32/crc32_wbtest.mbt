///|
/// Reverses bits to translate between forward and reflected CRC registers.
fn reverse_word(value : UInt32) -> UInt32 {
  for bit in 0..<32; result = 0U {
    continue (result << 1) | ((value >> bit) & 1)
  } nobreak {
    result
  }
}

///|
/// Computes an independent forward-polynomial bitwise CRC without lookup tables.
fn reference_crc(initial : UInt32, data : BytesView) -> UInt32 {
  let mut state = reverse_word(initial ^ 0xFFFFFFFF)
  for byte in data {
    for bit in 0..<8 {
      let feedback = ((state >> 31) ^ (byte.to_uint() >> bit)) & 1
      state = state << 1
      if feedback != 0 {
        state = state ^ 0x04C11DB7
      }
    }
  }
  reverse_word(state) ^ 0xFFFFFFFF
}

///|
/// Generates deterministic binary input with high bits and changing byte patterns.
fn sample_bytes(length : Int32) -> Bytes {
  Bytes::makei(length, i => ((i * 73 + i / 7 + 19) & 0xFF).to_byte())
}

///|
test "scalar CRC agrees with the forward-polynomial oracle at boundaries" {
  let data = sample_bytes(16417)
  let lengths = [
    0, 1, 2, 3, 4, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128, 129, 255,
    256, 257, 511, 512, 513, 1023, 1024, 1025, 1087, 1088, 1089, 2047, 2048, 2049,
    4095, 4096, 4097, 16383, 16384, 16385,
  ]
  for offset in [0, 1, 2, 3, 7, 15, 16, 31] {
    for length in lengths {
      for initial in [0U, 1U, 0x12345678U, 0xFFFFFFFFU] {
        let view = data[offset:offset + length]
        assert_eq(update_scalar(initial, view), reference_crc(initial, view))
      }
    }
  }
}

///|
test "scalar CRC covers every possible single byte and custom initial state" {
  for byte in 0..<256 {
    let data = Bytes::makei(1, _ => byte.to_byte())
    for initial in [0U, 0x80000000U, 0xDEADBEEFU, 0xFFFFFFFFU] {
      assert_eq(update_scalar(initial, data), reference_crc(initial, data))
    }
  }
}

///|
#cfg(any(target="native", target="wasm"))
test "SIMD CRC agrees with the oracle on unaligned blocks and short tails" {
  let data = sample_bytes(16417)
  let lengths = [
    0, 1, 7, 8, 15, 16, 17, 31, 32, 63, 64, 65, 127, 128, 129, 255, 256, 257, 511,
    512, 513, 1023, 1024, 1025, 1087, 1088, 1089, 2047, 2048, 2049, 4095, 4096, 4097,
    16383, 16384, 16385,
  ]
  for offset in [0, 1, 2, 3, 7, 15, 16, 31] {
    for length in lengths {
      for initial in [0U, 1U, 0x12345678U, 0xFFFFFFFFU] {
        let view = data[offset:offset + length]
        let expected = reference_crc(initial, view)
        assert_eq(update_simd(initial, view), expected)
        assert_eq(update_dispatch(initial, view, true), expected)
        assert_eq(update_dispatch(initial, view, false), expected)
      }
    }
  }
}

///|
test "zero-byte polynomial operators agree with a bitwise oracle" {
  for length in [0, 1, 2, 7, 8, 63, 64, 255, 1024, 32768] {
    let zeros = Bytes::makei(length, _ => 0)
    for initial in [0U, 1U, 0x80000000U, 0xDEADBEEFU, 0xFFFFFFFFU] {
      let shifted = multiply_mod(shift_factor(length.to_uint64()), initial)
      assert_eq(
        shifted,
        reference_crc(initial ^ 0xFFFFFFFF, zeros) ^ 0xFFFFFFFF,
      )
    }
  }
}
