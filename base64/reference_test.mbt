///|
/// Lists the four public configurations together with their specification policies.
fn policies() -> Array[(@base64.Base64, Bool, Bool)] {
  [
    (@base64.standard, false, true),
    (@base64.standard_no_pad, false, false),
    (@base64.url_safe, true, true),
    (@base64.url_safe_no_pad, true, false),
  ]
}

///|
/// Encodes an independent per-bit stream according to RFC 4648.
fn bitstream_encode(
  data : BytesView,
  url_safe : Bool,
  padding : Bool,
) -> String {
  let alphabet = if url_safe {
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  } else {
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  }
  let result = StringBuilder()
  let mut sextet = 0
  let mut bits = 0
  for byte in data {
    for shift = 7; shift >= 0; shift = shift - 1 {
      sextet = (sextet << 1) | ((byte.to_int() >> shift) & 1)
      bits += 1
      if bits == 6 {
        result.write_char(alphabet[sextet].to_char().unwrap())
        sextet = 0
        bits = 0
      }
    }
  }
  if bits != 0 {
    result.write_char(alphabet[sextet << (6 - bits)].to_char().unwrap())
  }
  if padding {
    let remainder = result.to_string().length() % 4
    if remainder != 0 {
      for _ in 0..<(4 - remainder) {
        result.write_char('=')
      }
    }
  }
  result.to_string()
}

///|
/// Builds deterministic binary inputs with all bit positions exercised.
fn payload(length : Int32, seed~ : UInt32 = 0x91e10da5) -> Bytes {
  let mut state = seed
  Bytes::makei(length, _ => {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    state.to_byte()
  })
}

///|
/// Converts test ASCII to bytes without borrowing the implementation's encoder.
fn ascii(text : StringView) -> Bytes {
  Bytes::from_array(text.code_units().map(code => code.to_byte()))
}

///|
/// Verifies that a public operation rejects invalid Base64 with the typed error.
fn invalid(operation : () -> Unit raise @base64.Base64Error) -> Unit raise {
  try operation() catch {
    error => assert_true(error is @base64.InvalidInput)
  } noraise {
    _ => fail("Expected InvalidInput")
  }
}

///|
/// Verifies an output range failure without accepting a malformed input error.
fn too_small(operation : () -> Unit raise @base64.Base64Error) -> Unit raise {
  try operation() catch {
    error => assert_true(error is @base64.OutputTooSmall)
  } noraise {
    _ => fail("Expected OutputTooSmall")
  }
}

///|
test "RFC 4648 and upstream basic vectors under all four policies" {
  let vectors : Array[(Bytes, String)] = [
    (b"", ""),
    (b"f", "Zg=="),
    (b"fo", "Zm8="),
    (b"foo", "Zm9v"),
    (b"foob", "Zm9vYg=="),
    (b"fooba", "Zm9vYmE="),
    (b"foobar", "Zm9vYmFy"),
    (b"hello world", "aGVsbG8gd29ybGQ="),
    (b"\xfb\xff", "+/8="),
  ]
  for (config, url_safe, padding) in policies() {
    assert_eq(config, @base64.Base64::new(url_safe~, padding~))
    assert_eq(config.charset().length(), 64)
    for (data, expected) in vectors {
      let expected = if url_safe {
        expected.replace_all(old="+", new="-").replace_all(old="/", new="_")
      } else {
        expected
      }
      let expected = if padding {
        expected
      } else {
        expected.replace_all(old="=", new="")
      }
      for simd in [false, true] {
        assert_eq(config.encode_to_string(data, simd~), expected)
        assert_eq(config.encode(data, simd~), ascii(expected))
        assert_eq(config.decode_string(expected, simd~), data)
        assert_eq(config.decode(ascii(expected), simd~), data)
        config.check(ascii(expected), simd~)
        assert_eq(config.encoded_length(data.length()), expected.length())
        assert_eq(config.decoded_length(ascii(expected)), data.length())
      }
    }
  }
}

///|
test "scalar and vector paths match the independent bitstream oracle and core" {
  let lengths = [ for i in 0..<130 => i ]
  for
    length in [255, 256, 257, 511, 512, 513, 1023, 1024, 1025, 4095, 4096, 4097] {
    lengths.push(length)
  }
  for length in lengths {
    let data = payload(length, seed=length.reinterpret_as_uint() + 1)
    for (config, url_safe, padding) in policies() {
      let expected = bitstream_encode(data, url_safe, padding)
      assert_eq(@reference.encode(data, url_safe~, padding~), expected)
      assert_eq(@reference.decode(expected, url_safe~), data)
      for simd in [false, true] {
        assert_eq(config.encode_to_string(data, simd~), expected)
        assert_eq(config.decode(ascii(expected), simd~), data)
        assert_eq(config.decode_string(expected, simd~), data)
        config.check(ascii(expected), simd~)
      }
    }
  }
}

///|
test "every single byte and every two-byte high sextet round trips" {
  for value in 0..<256 {
    let single : Bytes = [value.to_byte()]
    let pair : Bytes = [value.to_byte(), (255 - value).to_byte()]
    for data in [single, pair] {
      for (config, url_safe, padding) in policies() {
        let expected = bitstream_encode(data, url_safe, padding)
        for simd in [false, true] {
          assert_eq(config.encode_to_string(data, simd~), expected)
          assert_eq(config.decode_string(expected, simd~), data)
        }
      }
    }
  }
}

///|
test "packed encoding covers every twelve-bit index in each half of a triple" {
  let length = 4096 * 3
  let backing = Bytes::makei(length + 2, index => {
    if index == 0 || index == length + 1 {
      b'!'
    } else {
      let position = index - 1
      let pair = position / 3
      let triple = (pair << 12) | pair
      (triple >> (16 - position % 3 * 8)).to_byte()
    }
  })
  let input = backing[1:1 + length]
  for (config, url_safe, padding) in policies() {
    let expected = ascii(bitstream_encode(input, url_safe, padding))
    let output = FixedArray::make(expected.length() + 2, b'!')
    assert_eq(
      config.encode_into(input, output, offset=1, simd=false),
      expected.length(),
    )
    assert_eq(Bytes::from_array(output[:]), b"!" + expected + b"!")
  }
}

///|
test "length estimates preserve structural-only validation and avoid integer overflow" {
  for (config, _, padding) in policies() {
    assert_eq(config.estimated_decoded_length(0), 0)
    assert_eq(config.estimated_decoded_length(1), 3)
    assert_eq(config.estimated_decoded_length(2), 3)
    assert_eq(config.estimated_decoded_length(3), 3)
    assert_eq(config.estimated_decoded_length(4), 3)
    assert_eq(config.estimated_decoded_length(5), 6)
    assert_eq(config.estimated_decoded_length(0x7fffffff), 1610612736)
    assert_eq(config.decoded_length(b"!!!!"), 3)
    assert_eq(config.decoded_length(b"A==="), if padding { 1 } else { 3 })
    invalid(() => config.check(b"A==="))
  }
  assert_eq(@base64.standard.encoded_length(1610612733), 2147483644)
  assert_eq(@base64.standard_no_pad.encoded_length(1610612735), 2147483647)
  assert_eq(@base64.standard.decoded_length(b"AA=="), 1)
  assert_eq(@base64.standard.decoded_length(b"AAA="), 2)
  assert_eq(@base64.standard_no_pad.decoded_length(b"AA"), 1)
  assert_eq(@base64.standard_no_pad.decoded_length(b"AAA"), 2)
  invalid(() => ignore(@base64.standard_no_pad.decoded_length(b"A")))
}

///|
test "panic negative encoded length" {
  ignore(@base64.standard.encoded_length(-1))
}

///|
test "panic encoded length overflow" {
  ignore(@base64.standard.encoded_length(1610612734))
}

///|
test "panic unpadded encoded length overflow" {
  ignore(@base64.standard_no_pad.encoded_length(1610612736))
}

///|
test "panic negative decoded length estimate" {
  ignore(@base64.standard.estimated_decoded_length(-1))
}
