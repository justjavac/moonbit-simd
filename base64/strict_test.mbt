///|
test "upstream canonicity and strict padding remain distinct from forgiving decode" {
  // Expectations retained from base64-simd 0.8.0 tests/it.rs::canonicity.
  assert_eq(@base64.standard.decode(b"SGVsbG8="), b"Hello")
  assert_eq(@base64.standard.decode(b"SGVsbA=="), b"Hell")
  for encoded in ["SGVsbG9=", "SGVsbG9", "SGVsbA=", "SGVsbA", "SGVsbA===="] {
    for simd in [false, true] {
      invalid(() => @base64.standard.check(ascii(encoded), simd~))
      invalid(() => ignore(@base64.standard.decode_string(encoded, simd~)))
    }
  }
  for (config, _, padding) in policies() {
    for
      text in [
        "=", "==", "===", "====", "A", "A=", "A==", "A===", "AA=", "AA===", "AAA==",
        "AAAA=", "AAAA====", "AA=A", "AA==AAAA", "AB==", "AAB=", "AA\nA", "AA\rA",
        "AA\tA", "AA A", "AA\u000bA", "AA\u000cA", "AA\u0000A",
      ] {
      for simd in [false, true] {
        invalid(() => config.check(ascii(text), simd~))
        invalid(() => ignore(config.decode(ascii(text), simd~)))
        invalid(() => ignore(config.decode_string(text, simd~)))
      }
    }
    for text in ["Zg", "Zm8"] {
      if padding {
        invalid(() => ignore(config.decode_string(text)))
      } else {
        config.check(ascii(text))
      }
    }
    for text in ["Zg==", "Zm8="] {
      if padding {
        config.check(ascii(text))
      } else {
        invalid(() => ignore(config.decode_string(text)))
      }
    }
  }
  invalid(() => ignore(@base64.standard.decode(b"-_8=")))
  invalid(() => ignore(@base64.url_safe.decode(b"+/8=")))
}

///|
test "unused bits are rejected for every sextet in short and vector tails" {
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  for a in 0..<64 {
    for b in 0..<64 {
      let tail = String::from_array([
        alphabet[a].to_char().unwrap(),
        alphabet[b].to_char().unwrap(),
      ])
      for prefix in ["", "AAAA".repeat(8)] {
        for
          (config, _, padding) in [
            (@base64.standard, false, true),
            (@base64.standard_no_pad, false, false),
          ] {
          let text = prefix + tail + (if padding { "==" } else { "" })
          for simd in [false, true] {
            if (b & 15) == 0 {
              let expected = @reference.decode(text)
              assert_eq(config.decode_string(text, simd~), expected)
              config.check(ascii(text), simd~)
            } else {
              invalid(() => config.check(ascii(text), simd~))
              invalid(() => ignore(config.decode_string(text, simd~)))
            }
          }
        }
      }
    }
    let tail = "AA" + String::from_array([alphabet[a].to_char().unwrap()])
    for prefix in ["", "AAAA".repeat(8)] {
      for
        (config, _, padding) in [
          (@base64.standard, false, true),
          (@base64.standard_no_pad, false, false),
        ] {
        let text = prefix + tail + (if padding { "=" } else { "" })
        for simd in [false, true] {
          if (a & 3) == 0 {
            assert_eq(
              config.decode_string(text, simd~),
              @reference.decode(text),
            )
          } else {
            invalid(() => config.check(ascii(text), simd~))
            invalid(() => ignore(config.decode_string(text, simd~)))
          }
        }
      }
    }
  }
}

///|
test "all byte values at every vector lane match an independent alphabet oracle" {
  for
    (config, url_safe, _) in [
      (@base64.standard_no_pad, false, false),
      (@base64.url_safe_no_pad, true, false),
    ] {
    for code in 0..<256 {
      let valid = match code {
        'A'..<='Z' | 'a'..<='z' | '0'..<='9' => true
        '+' | '/' => !url_safe
        '-' | '_' => url_safe
        _ => false
      }
      for lane in 0..<16 {
        let input = Bytes::makei(32, i => {
          if i == lane {
            code.to_byte()
          } else {
            b'A'
          }
        })
        let text = String::from_array(
          [
            for byte in input => byte.to_int().to_char().unwrap()
          ],
        )
        for simd in [false, true] {
          if valid {
            config.check(input, simd~)
            assert_eq(
              config.decode(input, simd~),
              @reference.decode(text, url_safe~),
            )
            assert_eq(
              config.decode_string(text, simd~),
              @reference.decode(text, url_safe~),
            )
          } else {
            invalid(() => config.check(input, simd~))
            invalid(() => ignore(config.decode(input, simd~)))
            invalid(() => ignore(config.decode_string(text, simd~)))
          }
        }
      }
    }
  }
}

///|
test "UTF-16 non-ASCII cannot narrow into valid ASCII sextets" {
  for code in [0x80, 0xc1, 0xff, 0x100, 0x141, 0x8000, 0x8041, 0xff41, 0xffff] {
    for lane in 0..<16 {
      let input = String::from_array(
        [
          for i in 0..<32 => {
            (if i == lane { code } else { 65 }).to_char().unwrap()
          }
        ],
      )
      for simd in [false, true] {
        invalid(() => ignore(@base64.standard.decode_string(input, simd~)))
        invalid(() => ignore(@base64.forgiving_decode_string(input, simd~)))
        invalid(() => {
          ignore(@base64.forgiving_decode_string(" " + input, simd~))
        })
      }
    }
  }
  for input in ["😀", "é", "中文", "\u00a0", "\u2000", "\u2028"] {
    invalid(() => ignore(@base64.standard.decode_string(input)))
    invalid(() => ignore(@base64.forgiving_decode_string(input)))
  }
}

///|
test "unpaired UTF-16 surrogates cannot become ASCII after vector narrowing" {
  // The unchecked byte copy constructs deliberately malformed UTF-16 storage.
  // Ordinary Char constructors cannot represent these isolated code units.
  assert_eq(b"A\x00".repeat(32).to_unchecked_string(), "A".repeat(32))
  for surrogate in [b"\x00\xd8", b"\x00\xdc", b"\xff\xdf"] {
    for lane in 0..<16 {
      let units = b"A\x00".repeat(lane) + surrogate + b"A\x00".repeat(31 - lane)
      let text = units.to_unchecked_string()
      for simd in [false, true] {
        invalid(() => ignore(@base64.standard.decode_string(text, simd~)))
        invalid(() => ignore(@base64.forgiving_decode_string(text, simd~)))
      }
    }
  }
}
