///|
/// Counts completed words using the explicit ASCII separator set.
fn reference(data : BytesView) -> (UInt64, UInt64, UInt64) {
  let separators : Array[Byte] = [0x20, 0x09, 0x0A, 0x0B, 0x0C, 0x0D]
  let mut lines = 0UL
  let mut words = 0UL
  let mut inside = false
  for byte in data {
    if byte == 0x0A {
      lines += 1
    }
    if separators.contains(byte) {
      if inside {
        words += 1
      }
      inside = false
    } else {
      inside = true
    }
  }
  if inside {
    words += 1
  }
  (lines, words, data.length().to_uint64())
}

///|
/// Compares read-only public totals to expected numeric values.
fn assert_counts(
  actual : @wc.Counts,
  expected : (UInt64, UInt64, UInt64),
) -> Unit raise {
  assert_eq((actual.lines, actual.words, actual.bytes), expected)
}

///|
test "fastlwc counts LF and all six ASCII delimiters" {
  for simd in [false, true] {
    assert_counts(@wc.count(b"", simd~), (0, 0, 0))
    assert_counts(@wc.count(b" \t\n\x0b\x0c\r", simd~), (1, 0, 6))
    assert_counts(@wc.count(b"a\r\nb\rc\td\x0be\x0cf g", simd~), (1, 7, 14))
    assert_counts(@wc.count(b"\n\nlast", simd~), (2, 1, 6))
    assert_counts(@wc.count(b"a\xc2\xa0b\x00\x0e\xff", simd~), (0, 1, 7))
  }
}

///|
test "every byte is classified at every vector lane and across block boundaries" {
  for value in 0..<256 {
    for lane in 0..<16 {
      let buffer = Bytes::makei(37, i => {
        if i == 1 + 16 + lane {
          value.to_byte()
        } else if i >= 1 && i < 35 {
          b'x'
        } else {
          b'\n'
        }
      })
      let data = buffer[1:35]
      let expected = reference(data)
      assert_counts(@wc.count(data, simd=false), expected)
      assert_counts(@wc.count(data, simd=true), expected)
    }
  }
}

///|
test "all vector tail lengths stay within unaligned and empty views" {
  let alphabet = b" \n\t7\x0b\x0c\rabc\x00\x0e\x1f\x80\xff"
  let data = Bytes::makei(120, i => {
    alphabet[(i * 7 + i / 6) % alphabet.length()]
  })
  for offset in 0..<16 {
    for length in 0..<=80 {
      let input = data[offset:offset + length]
      let expected = reference(input)
      assert_counts(@wc.count(input, simd=false), expected)
      assert_counts(@wc.count(input, simd=true), expected)
    }
  }
}

///|
test "stream chunks and empty updates preserve the incoming word boundary" {
  let alphabet = b"x\nx\x00\xff\t xyzqzqz\x0e\ra\x0c"
  let data = Bytes::makei(343, i => alphabet[(i + i / 19) % alphabet.length()])
  let input = data[3:342]
  for simd in [false, true] {
    for chunk in 1..<=65 {
      let counter = @wc.Counter::new(simd~)
      for start = 0; start < input.length(); start = start + chunk {
        let end = (start + chunk).min(input.length())
        counter.update(input[start:end])
        counter.update(input[end:end])
        assert_counts(counter.counts(), reference(input[:end]))
      }
    }
  }
}

///|
test "long streams preserve counts through dense lines and mixed alignment" {
  let lines = Bytes::make(16385, b'\n')
  let word = Bytes::make(16385, b'x')
  for simd in [false, true] {
    assert_counts(@wc.count(lines, simd~), (16385, 0, 16385))
    assert_counts(@wc.count(word, simd~), (0, 1, 16385))
    let counter = @wc.Counter::new(simd~)
    counter.update(lines[1:])
    counter.update(word)
    counter.update(word[3:])
    counter.update(lines[1:16])
    assert_counts(counter.counts(), (16399, 1, 49166))
  }
}

///|
test "copies retain pending word state and snapshots outlive resets" {
  for simd in [false, true] {
    let counter = @wc.Counter::new(simd~)
    let shared = counter
    let empty = counter.counts()
    counter.update(b"partial")
    let saved = shared.counts()
    let fork = counter.copy()
    shared.update(b"\nnext")
    fork.update(b"word")
    assert_counts(counter.counts(), (1, 2, 12))
    assert_counts(fork.counts(), (0, 1, 11))
    shared.reset()
    assert_eq(counter.counts(), empty)
    assert_counts(saved, (0, 1, 7))
    counter.update(b"new")
    assert_counts(counter.counts(), (0, 1, 3))
    assert_counts(fork.counts(), (0, 1, 11))
  }
}
