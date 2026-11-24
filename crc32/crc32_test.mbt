///|
test "published IEEE CRC-32 reference vectors" {
  let vectors : Array[(Bytes, UInt32)] = [
    (b"", 0U),
    (b"123456789", 0xCBF43926U),
    (b"a", 0xE8B7BE43U),
    (b"hello", 0x3610A686U),
    (b"hello world", 0x0D4A1185U),
    (b"The quick brown fox jumps over the lazy dog", 0x414FA339U),
    (Bytes::makei(32, _ => 0), 0x190A55ADU),
    (Bytes::makei(32, _ => 0xFF), 0xFF6CAB0BU),
    (Bytes::makei(32, i => i.to_byte()), 0x91267E8AU),
  ]
  for (data, expected) in vectors {
    assert_eq(@crc32.hash(data), expected)
    assert_eq(@crc32.hash(data, simd=true), expected)
    let state = @crc32.Hasher::new()
    state.update(data)
    assert_eq(state.finalize(), expected)
    assert_eq(state.total_len(), data.length().to_uint64())
  }
}

///|
test "empty updates preserve finalized initial checksums" {
  for initial in [0U, 1U, 0x12345678U, 0xFFFFFFFFU] {
    assert_eq(@crc32.update(initial, b""), initial)
    assert_eq(@crc32.update(initial, b"", simd=true), initial)
    let state = @crc32.Hasher::new_with_initial(initial, simd=true)
    state.update(b"")
    assert_eq(state.finalize(), initial)
    assert_eq(state.total_len(), 0UL)
  }
}

///|
test "streaming is independent of chunk size and empty updates" {
  let data = Bytes::makei(5003, i => ((i * 73 + i / 7 + 19) & 0xFF).to_byte())
  let expected = @crc32.hash(data)
  for simd in [false, true] {
    for chunk in [1, 3, 7, 8, 15, 16, 31, 64, 127, 256, 1023, 1024, 4096, 5003] {
      let state = @crc32.Hasher::new(simd~)
      for offset = 0; offset < data.length(); offset = offset + chunk {
        state.update(data[offset:(offset + chunk).min(data.length())])
        state.update(b"")
      }
      assert_eq(state.finalize(), expected)
      assert_eq(state.total_len(), 5003UL)
    }
  }
}

///|
test "continuation and checksum combination agree at every split" {
  let data = Bytes::makei(257, i => ((i * 131 + 7) & 0xFF).to_byte())
  let expected = @crc32.hash(data)
  for split in 0..<=data.length() {
    let first = @crc32.hash(data[:split])
    let second = @crc32.hash(data[split:])
    assert_eq(@crc32.update(first, data[split:]), expected)
    assert_eq(
      @crc32.combine(first, second, (data.length() - split).to_uint64()),
      expected,
    )
  }
}

///|
test "subviews preserve their exact byte boundaries" {
  let data = b"ignored prefix123456789ignored suffix"
  assert_eq(@crc32.hash(data[14:23]), 0xCBF43926U)
  let state = @crc32.Hasher::new()
  state.update(data[14:18])
  state.update(data[18:23])
  assert_eq(state.finalize(), 0xCBF43926U)
  assert_eq(state.total_len(), 9UL)
}

///|
test "resumed states track supplied and newly processed lengths" {
  let state = @crc32.Hasher::new_with_initial_len(@crc32.hash(b"hello"), 5)
  state.update(b" ")
  let suffix = @crc32.Hasher::new()
  suffix.update(b"world")
  state.combine(suffix)
  assert_eq(state.finalize(), @crc32.hash(b"hello world"))
  assert_eq(state.total_len(), 11UL)
  assert_eq(suffix.finalize(), @crc32.hash(b"world"))
  assert_eq(suffix.total_len(), 5UL)
  let unknown = @crc32.Hasher::new_with_initial(@crc32.hash(b"hello"))
  unknown.update(b" world")
  assert_eq(unknown.finalize(), state.finalize())
  assert_eq(unknown.total_len(), 6UL)
}

///|
test "finalization observes state and permits more updates" {
  let state = @crc32.Hasher::new()
  assert_eq(state.finalize(), 0U)
  state.update(b"hello")
  assert_eq(state.finalize(), @crc32.hash(b"hello"))
  assert_eq(state.finalize(), @crc32.hash(b"hello"))
  state.update(b" world")
  assert_eq(state.finalize(), @crc32.hash(b"hello world"))
}

///|
test "copy forks independent state while assignment shares it" {
  let prefix = @crc32.Hasher::new(simd=true)
  prefix.update(b"hello")
  let branch = prefix.copy()
  branch.update(b" world")
  assert_eq(branch.finalize(), @crc32.hash(b"hello world"))
  assert_eq(prefix.finalize(), @crc32.hash(b"hello"))
  assert_eq(prefix.total_len(), 5UL)
  let shared = prefix
  shared.update(b"!")
  assert_eq(prefix.finalize(), @crc32.hash(b"hello!"))
  assert_eq(prefix.total_len(), 6UL)
  branch.reset()
  assert_eq(branch.finalize(), 0U)
  assert_eq(prefix.finalize(), @crc32.hash(b"hello!"))
}

///|
test "reset discards constructor state and allows reuse" {
  let state = @crc32.Hasher::new_with_initial_len(0x12345678, 123)
  state.update(b"old input")
  state.reset()
  assert_eq(state.finalize(), 0U)
  assert_eq(state.total_len(), 0UL)
  state.update(b"new input")
  assert_eq(state.finalize(), @crc32.hash(b"new input"))
  assert_eq(state.total_len(), 9UL)
}

///|
test "combination is associative and leaves suffix states unchanged" {
  let a = @crc32.Hasher::new()
  let b = @crc32.Hasher::new()
  let c = @crc32.Hasher::new()
  a.update(b"hello")
  b.update(b" ")
  c.update(b"world")
  let left = a.copy()
  left.combine(b)
  left.combine(c)
  let suffix = b.copy()
  suffix.combine(c)
  let right = a.copy()
  right.combine(suffix)
  assert_eq(left.finalize(), right.finalize())
  assert_eq(left.finalize(), @crc32.hash(b"hello world"))
  assert_eq(left.total_len(), 11UL)
  assert_eq(right.total_len(), 11UL)
  assert_eq(b.finalize(), @crc32.hash(b" "))
  assert_eq(c.finalize(), @crc32.hash(b"world"))
}

///|
test "combination handles empty suffixes and aliasing" {
  let state = @crc32.Hasher::new()
  state.update(b"abc")
  state.combine(@crc32.Hasher::new_with_initial(0x12345678))
  assert_eq(state.finalize(), @crc32.hash(b"abc"))
  assert_eq(state.total_len(), 3UL)
  state.combine(state)
  assert_eq(state.finalize(), @crc32.hash(b"abcabc"))
  assert_eq(state.total_len(), 6UL)
  assert_eq(@crc32.combine(0xC401F8C9, 0xFFFFFFFF, 0), 0xC401F8C9U)
}

///|
test "crc32fast combination vectors include full-width lengths" {
  assert_eq(@crc32.combine(0x7CBA3D5E, 0xE7466D39, 0xB), 0x76365C4FU)
  assert_eq(@crc32.combine(0x576C62D6, 0x123256E1, 0x47), 0x0579A636U)
  assert_eq(@crc32.combine(0x4F626F9A, 0x9E5CCBF5, 0xA59D), 0x98D43168U)
  assert_eq(@crc32.combine(0xA09B8A88, 0x815B0F48, 0x40F39511), 0x0D7A5F79U)
  assert_eq(
    @crc32.combine(0x7F6A4306, 0xBC929646, 0x828CDE72B3E25301),
    0xEF922DDAU,
  )
}

///|
test "largest represented length accepts empty operations" {
  let state = @crc32.Hasher::new_with_initial_len(
    0x12345678, 0xFFFFFFFFFFFFFFFF,
  )
  state.update(b"")
  state.combine(@crc32.Hasher::new())
  assert_eq(state.total_len(), 0xFFFFFFFFFFFFFFFFUL)
  assert_eq(state.finalize(), 0x12345678U)
}

///|
test "panic update rejects represented length overflow" {
  let state = @crc32.Hasher::new_with_initial_len(0, 0xFFFFFFFFFFFFFFFF)
  state.update(b"x")
}

///|
test "panic combination rejects represented length overflow" {
  let state = @crc32.Hasher::new_with_initial_len(0, 0xFFFFFFFFFFFFFFFF)
  let suffix = @crc32.Hasher::new()
  suffix.update(b"x")
  state.combine(suffix)
}
