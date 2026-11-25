///|
/// Checks precise errors for both public implementation requests.
fn expect_error(
  data : BytesView,
  position : Int32,
  length : Int32?,
) -> Unit raise {
  for simd in [false, true] {
    assert_true(!@utf8.is_valid(data, simd~))
    try @utf8.validate(data, simd~) catch {
      error => {
        assert_eq(error.valid_up_to(), position)
        assert_eq(error.error_len(), length)
      }
    } noraise {
      _ => fail("expected invalid UTF-8")
    }
    try @utf8.from_utf8(data, simd~) catch {
      error => {
        assert_eq(error.valid_up_to(), position)
        assert_eq(error.error_len(), length)
      }
    } noraise {
      _ => fail("expected decoding to fail")
    }
  }
}

///|
test "strict UTF-8 accepts scalar boundaries, BOM, NUL, and upstream languages" {
  // The language samples are retained from simdutf8 0.1.5 tests/tests.rs.
  let strings = [
    "", "\u{0}", "The quick brown fox jumps over the lazy dog", "öäüÖÄÜß",
    "❤️✨🥺🔥😂😊✔️👍🥰", "断用山昨屈内銀代意検瓶調像。情旗最投任留財夜隆年表高学送意功者。",
    "意ざど禁23費サヒ車園オスミト規更ワエ異67事続トソキ音合岡治こ訪京ぴ日9稿がト明安イ抗的ウクロコ売一エコヨホ必噴塗ッ。",
    "3인은 대법원장이 지명하는 자를 임명한다, 대통령은 제3항과 제4항의 사유를 지체없이 공포하여야 한다,",
    "\u{FEFF}BOM\u{0}\u{7F}\u{80}\u{7FF}\u{800}\u{D7FF}\u{E000}\u{FFFF}\u{10000}\u{10FFFF}",
  ]
  for text in strings {
    let bytes = @encoding.encode(text)
    for simd in [false, true] {
      assert_true(@utf8.is_valid(bytes, simd~))
      @utf8.validate(bytes, simd~)
      assert_eq(@utf8.from_utf8(bytes, simd~), text)
    }
  }
}

///|
test "precise errors reject every illegal encoding category" {
  let vectors : Array[(Bytes, Int32?)] = [
    (b"\x80", Some(1)),
    (b"\xBF", Some(1)),
    (b"\xC0\x80", Some(1)),
    (b"\xC1\xBF", Some(1)),
    (b"\xE0\x80\x80", Some(1)),
    (b"\xED\xA0\x80", Some(1)),
    (b"\xED\xBF\xBF", Some(1)),
    (b"\xF0\x80\x80\x80", Some(1)),
    (b"\xF4\x90\x80\x80", Some(1)),
    (b"\xF5\x80\x80\x80", Some(1)),
    (b"\xFF", Some(1)),
    (b"\xC3", None),
    (b"\xE2", None),
    (b"\xE2\x82", None),
    (b"\xF0", None),
    (b"\xF0\x9F", None),
    (b"\xF0\x9F\x98", None),
    (b"\xE2\x82a", Some(2)),
    (b"\xF0\x9Fa", Some(2)),
    (b"\xF0\x9F\x98a", Some(3)),
    (b"\xE0\x9F", Some(1)),
    (b"\xED\xA0", Some(1)),
    (b"\xF4\x90", Some(1)),
  ]
  for (bytes, length) in vectors {
    for
      prefix in [
        0, 1, 2, 7, 8, 9, 15, 16, 31, 32, 33, 63, 64, 65, 127, 128, 129,
      ] {
      let data = Bytes::make(prefix, b'a') + bytes
      expect_error(data, prefix, length)
      let suffix_length = Some(length.unwrap_or(bytes.length()))
      expect_error(data + b"ASCII suffix", prefix, suffix_length)
    }
  }
}

///|
test "all sixteen tails and sixty-four block offsets retain sequence boundaries" {
  let sequences : Array[Bytes] = [
    b"\xC2\x80", b"\xDF\xBF", b"\xE0\xA0\x80", b"\xED\x9F\xBF", b"\xEF\xBF\xBF",
    b"\xF0\x90\x80\x80", b"\xF4\x8F\xBF\xBF",
  ]
  for prefix in 0..<144 {
    for suffix in 0..<16 {
      for sequence in sequences {
        let bytes = Bytes::make(prefix, b'a') +
          sequence +
          Bytes::make(suffix, b'b')
        for simd in [false, true] {
          assert_true(@utf8.is_valid(bytes, simd~))
          @utf8.validate(bytes, simd~)
        }
      }
    }
  }
}

///|
test "unaligned views never include rejected bytes outside their bounds" {
  for offset in 0..<16 {
    for length in 0..<160 {
      let data = Bytes::make(offset, 0xFF) + Bytes::make(length, b'a') + b"\xFF"
      let view = data[offset:offset + length]
      for simd in [false, true] {
        assert_true(@utf8.is_valid(view, simd~))
        @utf8.validate(view, simd~)
      }
    }
    let prefix = Bytes::make(offset, 0xFF)
    let input = prefix + Bytes::make(63, b'a') + b"\xF0\x9F\x98\x80"
    expect_error(input[offset:offset + 66], 63, None)
    expect_error(
      (prefix + Bytes::make(63, b'a') + b"\xF0\x9Fa")[offset:],
      63,
      Some(2),
    )
  }
}

///|
test "early precise errors keep the first failure across later malformed blocks" {
  let data = Bytes::make(63, b'a') + b"\xE2\x82a" + Bytes::make(257, 0xFF)
  expect_error(data, 63, Some(2))
}

///|
test "error presentation retains Rust-compatible invalid and incomplete messages" {
  try @utf8.validate(b"a\xF0\x9Fa") catch {
    error => {
      assert_eq(
        Show::to_string(error),
        "invalid utf-8 sequence of 2 bytes from index 1",
      )
      debug_inspect(
        error,
        content="Utf8Error(valid_up_to=1, error_len=Some(2))",
      )
    }
  } noraise {
    _ => fail("expected invalid UTF-8")
  }
  try @utf8.validate(b"\xF0") catch {
    error =>
      assert_eq(
        Show::to_string(error),
        "incomplete utf-8 byte sequence from index 0",
      )
  } noraise {
    _ => fail("expected incomplete UTF-8")
  }
}
