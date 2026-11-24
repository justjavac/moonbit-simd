///|
/// Formats known bytes with an independent per-nibble arithmetic oracle.
fn reference_simple(input : BytesView, upper~ : Bool = false) -> String {
  let result = StringBuilder()
  for byte in input {
    for nibble in [byte.to_int() >> 4, byte.to_int() & 15] {
      let code : Int32 = if nibble < 10 {
        '0' + nibble
      } else {
        (if upper { 'A' } else { 'a' }) + nibble - 10
      }
      result.write_char(code.unsafe_to_char())
    }
  }
  result.to_string()
}

///|
/// Inserts the specification's four hyphens into an independent compact result.
fn reference_hyphenated(input : BytesView, upper~ : Bool = false) -> String {
  let text = reference_simple(input, upper~)
  "\{text[:8]}-\{text[8:12]}-\{text[12:16]}-\{text[16:20]}-\{text[20:]}"
}

///|
/// Returns whether a byte belongs to the independently specified ASCII ranges.
fn reference_hex(value : Int32) -> Bool {
  (value >= '0' && value <= '9') ||
  (value >= 'A' && value <= 'F') ||
  (value >= 'a' && value <= 'f')
}

///|
/// Observes rejection without depending on production error details.
fn rejects_text(input : StringView, algorithm : @uuid.Algorithm) -> Bool {
  try @uuid.parse(input, algorithm~) catch {
    @uuid.InvalidUuid => true
    _ => abort("Unexpected text parser error")
  } noraise {
    _ => false
  }
}

///|
/// Observes byte rejection through the public arbitrary-byte parser.
fn rejects_bytes(input : BytesView, algorithm : @uuid.Algorithm) -> Bool {
  try @uuid.parse_bytes(input, algorithm~) catch {
    @uuid.InvalidUuid => true
    _ => abort("Unexpected byte parser error")
  } noraise {
    _ => false
  }
}

///|
test "network order, equality, ordering, and immutable ownership" {
  let binary : Bytes = [
    0x01, 0x02, 0x03, 0x04, 0x11, 0x12, 0x21, 0x22, 0x31, 0x32, 0x41, 0x42, 0x43,
    0x44, 0x45, 0x46,
  ]
  let id = @uuid.Uuid::from_bytes(binary)
  assert_eq(id.to_bytes(), binary)
  assert_eq(id.to_string(), "01020304-1112-2122-3132-414243444546")
  let assigned = id
  assert_eq(assigned, @uuid.parse("01020304111221223132414243444546"))
  let zero = @uuid.parse("00000000000000000000000000000000")
  let maximum = @uuid.parse("ffffffffffffffffffffffffffffffff")
  assert_true(zero < id && id < maximum)
  let keys : Map[@uuid.Uuid, Int32] = Map([])
  keys[id] = 7
  assert_eq(keys[assigned], 7)
  let source : FixedArray[Byte] = FixedArray::make(16, 0)
  let snapshot = @uuid.Uuid::from_bytes(Bytes::from_array(source))
  let saved = snapshot.to_bytes()
  source.fill(255)
  assert_eq(snapshot, zero)
  assert_eq(saved, zero.to_bytes())
}

///|
test "binary length validation and offset views" {
  for length in 0..<40 {
    let input = Bytes::makei(length, _ => 0)
    try @uuid.Uuid::from_bytes(input) catch {
      @uuid.InvalidByteLength(actual) => assert_eq(actual, length)
      _ => fail("Unexpected binary constructor error")
    } noraise {
      value => {
        assert_eq(length, 16)
        assert_eq(value.to_bytes(), input)
      }
    }
  }
  let binary = Bytes::makei(16, i => (i * 17).to_byte())
  for offset in 0..<32 {
    let backing = Bytes::makei(offset + 17, i => {
      if offset <= i && i < offset + 16 {
        binary[i - offset]
      } else {
        255
      }
    })
    assert_eq(
      @uuid.Uuid::from_bytes(backing[offset:offset + 16]).to_bytes(),
      binary,
    )
  }
}

///|
test "all UUID bit patterns, spellings, and output cases against arithmetic oracle" {
  let mut seed = 0xA5A5F00DU
  for _ in 0..<1024 {
    let binary = Bytes::makei(16, _ => {
      seed = seed * 1664525U + 1013904223U
      (seed >> 24).to_byte()
    })
    let id = @uuid.Uuid::from_bytes(binary)
    for algorithm in [@uuid.Auto, @uuid.Scalar, @uuid.Simd] {
      for (case, upper) in [(@uuid.Lower, false), (@uuid.Upper, true)] {
        let compact = reference_simple(binary, upper~)
        let canonical = reference_hyphenated(binary, upper~)
        assert_eq(id.format_simple(case~, algorithm~), compact)
        assert_eq(id.format_hyphenated(case~, algorithm~), canonical)
        assert_eq(@uuid.parse_simple(compact, algorithm~).to_bytes(), binary)
        assert_eq(
          @uuid.parse_hyphenated(canonical, algorithm~).to_bytes(),
          binary,
        )
        for
          text in [
            compact,
            canonical,
            "{" + canonical + "}",
            "urn:uuid:" + canonical,
          ] {
          assert_eq(@uuid.parse(text, algorithm~), id)
          assert_eq(@uuid.parse_bytes(@utf8.encode(text), algorithm~), id)
        }
      }
    }
  }
}

///|
test "every byte at every compact digit position is validated independently" {
  for position in 0..<32 {
    for value in 0..<256 {
      let buffer : FixedArray[Byte] = FixedArray::make(32, b'0')
      buffer[position] = value.to_byte()
      let bytes = Bytes::from_array(buffer)
      for algorithm in [@uuid.Scalar, @uuid.Simd] {
        assert_eq(rejects_bytes(bytes, algorithm), !reference_hex(value))
        if reference_hex(value) {
          let nibble = if value <= '9' {
            value - '0'
          } else if value <= 'F' {
            value - 'A' + 10
          } else {
            value - 'a' + 10
          }
          let expected = Bytes::makei(16, i => {
            if i == position / 2 {
              (nibble << (if position % 2 == 0 { 4 } else { 0 })).to_byte()
            } else {
              0
            }
          })
          assert_eq(@uuid.parse_bytes(bytes, algorithm~).to_bytes(), expected)
        }
      }
    }
  }
}

///|
test "high UTF-16 code units cannot alias ASCII after vector narrowing" {
  let codes : Array[Int32] = [
    0, 0x80, 0xff, 0x100, 0x130, 0x141, 0x161, 0x230, 0x300, 0xff10, 0xff21, 0xff41,
    0xd800, 0xdfff, 0xffff,
  ]
  let simple = "00000000000000000000000000000000"
  let canonical = "00000000-0000-0000-0000-000000000000"
  for
    (start, original) in [
      (0, simple),
      (0, canonical),
      (1, "{" + canonical + "}"),
      (9, "urn:uuid:" + canonical),
    ] {
    for position in start..<original.length() {
      if original[position] != '0' {
        continue
      }
      for code in codes {
        let raw : FixedArray[Byte] = FixedArray::makei(original.length() * 2, i => {
          if i % 2 == 0 {
            original[i / 2].to_byte()
          } else {
            0
          }
        })
        raw[position * 2] = code.to_byte()
        raw[position * 2 + 1] = (code >> 8).to_byte()
        let text = Bytes::from_array(raw).to_unchecked_string()
        for algorithm in [@uuid.Scalar, @uuid.Simd] {
          assert_true(rejects_text(text, algorithm))
        }
      }
    }
  }
}

///|
test "text and byte view bounds include unaligned wrappers and rejected guards" {
  let canonical = "67e55044-10b1-426f-9247-bb680e5fe0c8"
  let expected = @uuid.parse(canonical)
  for
    text in [
      canonical,
      canonical.replace_all(old="-", new=""),
      "{" + canonical + "}",
      "urn:uuid:" + canonical,
    ] {
    for offset in 0..<32 {
      let prefix = String::make(offset, '!')
      let backing = prefix + text + "g"
      let bytes = @utf8.encode(backing)
      for algorithm in [@uuid.Scalar, @uuid.Simd] {
        assert_eq(
          @uuid.parse(backing[offset:offset + text.length()], algorithm~),
          expected,
        )
        assert_eq(
          @uuid.parse_bytes(bytes[offset:offset + text.length()], algorithm~),
          expected,
        )
        assert_true(
          rejects_text(backing[offset:offset + text.length() - 1], algorithm),
        )
        assert_true(
          rejects_bytes(bytes[offset:offset + text.length() - 1], algorithm),
        )
      }
    }
    let supplementary = "😀" + text + "😀"
    assert_eq(
      @uuid.parse(supplementary[2:2 + text.length()], algorithm=@uuid.Simd),
      expected,
    )
  }
}

///|
test "hyphens, wrappers, empty input, and strict parser entry points" {
  let canonical = "67e55044-10b1-426f-9247-bb680e5fe0c8"
  for position in 0..<36 {
    let invalid = canonical[:position].to_owned() +
      "g" +
      canonical[position + 1:].to_owned()
    for algorithm in [@uuid.Scalar, @uuid.Simd] {
      assert_true(rejects_text(invalid, algorithm))
      assert_true(rejects_bytes(@utf8.encode(invalid), algorithm))
    }
  }
  for
    input in [
      "",
      " ",
      " " + canonical,
      canonical + "\n",
      "{{" + canonical + "}}",
      "(" + canonical + ")",
      "URN:UUID:" + canonical,
      "urn:UUID:" + canonical,
      "urn:uuid:{" + canonical + "}",
      "{" + canonical,
      canonical + "}",
      "{67e5504410b1426f9247bb680e5fe0c8}",
    ] {
    for algorithm in [@uuid.Scalar, @uuid.Simd] {
      assert_true(rejects_text(input, algorithm))
      assert_true(rejects_bytes(@utf8.encode(input), algorithm))
    }
  }
  for length in 0..<65 {
    let input = String::make(length, '0')
    assert_eq(rejects_text(input, @uuid.Simd), length != 32)
  }
  try @uuid.parse_simple(canonical) catch {
    @uuid.InvalidUuid => ()
    _ => fail("Unexpected compact parser error")
  } noraise {
    _ => fail("compact parser accepted hyphens")
  }
  try @uuid.parse_hyphenated("67e5504410b1426f9247bb680e5fe0c8") catch {
    @uuid.InvalidUuid => ()
    _ => fail("Unexpected hyphenated parser error")
  } noraise {
    _ => fail("hyphenated parser accepted compact text")
  }
}

///|
test "buffer writes preserve guards for every offset and case" {
  let id = @uuid.parse("01020304-1112-2122-3132-414243444546")
  let original = id.to_bytes()
  for algorithm in [@uuid.Auto, @uuid.Scalar, @uuid.Simd] {
    for (case, upper) in [(@uuid.Lower, false), (@uuid.Upper, true)] {
      for offset in 0..<32 {
        let simple : FixedArray[Byte] = FixedArray::make(offset + 33, b'!')
        let canonical : FixedArray[Byte] = FixedArray::make(offset + 37, b'!')
        id.write_simple(simple, offset~, case~, algorithm~)
        id.write_hyphenated(canonical, offset~, case~, algorithm~)
        let simple_bytes = Bytes::from_array(simple)
        let canonical_bytes = Bytes::from_array(canonical)
        assert_eq(
          simple_bytes[offset:offset + 32].to_owned(),
          @utf8.encode(reference_simple(original, upper~)),
        )
        assert_eq(
          canonical_bytes[offset:offset + 36].to_owned(),
          @utf8.encode(reference_hyphenated(original, upper~)),
        )
        for index in 0..<offset {
          assert_eq(simple[index], b'!')
          assert_eq(canonical[index], b'!')
        }
        assert_eq(simple[offset + 32], b'!')
        assert_eq(canonical[offset + 36], b'!')
      }
    }
  }
  assert_eq(id.to_bytes(), original)
}

///|
test "invalid output ranges leave every byte unchanged" {
  let id = @uuid.parse("ffffffffffffffffffffffffffffffff")
  for length in [0, 1, 31, 32, 35, 36, 37] {
    for offset in [-2147483648, -1, 0, 1, 2, 2147483647] {
      for algorithm in [@uuid.Scalar, @uuid.Simd] {
        let destination : FixedArray[Byte] = FixedArray::make(length, b'!')
        if offset < 0 || offset > length - 32 {
          try id.write_simple(destination, offset~, algorithm~) catch {
            @uuid.InvalidBuffer(offset=actual, required=32, length=capacity) => {
              assert_eq(actual, offset)
              assert_eq(capacity, length)
              assert_eq(destination, FixedArray::make(length, b'!'))
            }
            _ => fail("Unexpected compact buffer error")
          } noraise {
            _ => fail("invalid compact write succeeded")
          }
        }
        if offset < 0 || offset > length - 36 {
          try id.write_hyphenated(destination, offset~, algorithm~) catch {
            @uuid.InvalidBuffer(offset=actual, required=36, length=capacity) => {
              assert_eq(actual, offset)
              assert_eq(capacity, length)
              assert_eq(destination, FixedArray::make(length, b'!'))
            }
            _ => fail("Unexpected hyphenated buffer error")
          } noraise {
            _ => fail("invalid hyphenated write succeeded")
          }
        }
      }
    }
  }
}
