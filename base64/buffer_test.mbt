///|
test "all vector offsets and tails preserve bounded input and output ranges" {
  for length in 0..<68 {
    for offset in 0..<17 {
      let data = payload(
        length,
        seed=length.reinterpret_as_uint() + offset.reinterpret_as_uint() + 1,
      )
      let backing = b"!".repeat(offset) + data + b"!".repeat(17)
      let view = backing[offset:offset + length]
      for (config, url_safe, padding) in policies() {
        let expected = bitstream_encode(data, url_safe, padding)
        let bytes = ascii(expected)
        let byte_backing = b"!".repeat(offset) + bytes + b"!".repeat(17)
        let byte_view = byte_backing[offset:offset + bytes.length()]
        let string_backing = "!".repeat(offset) + expected + "!".repeat(17)
        let string_view = string_backing[offset:offset + expected.length()]
        for simd in [false, true] {
          assert_eq(config.encode_to_string(view, simd~), expected)
          assert_eq(config.decode(byte_view, simd~), data)
          assert_eq(config.decode_string(string_view, simd~), data)
          config.check(byte_view, simd~)
          let encoded = FixedArray::make(bytes.length() + 6, b'!')
          assert_eq(
            config.encode_into(view, encoded, offset=3, simd~),
            bytes.length(),
          )
          assert_eq(Bytes::from_array(encoded[:]), b"!!!" + bytes + b"!!!")
          let decoded = FixedArray::make(data.length() + 6, b'!')
          assert_eq(
            config.decode_into(byte_view, decoded, offset=3, simd~),
            data.length(),
          )
          assert_eq(Bytes::from_array(decoded[:]), b"!!!" + data + b"!!!")
        }
      }
    }
  }
}

///|
test "in-place decode reads before writes and exposes mutation through aliases" {
  for length in 0..<130 {
    let data = payload(length)
    for (config, url_safe, padding) in policies() {
      let encoded = ascii(bitstream_encode(data, url_safe, padding))
      for simd in [false, true] {
        let buffer = (encoded + b"!!!").to_fixedarray()
        let shared = buffer
        let original = Bytes::from_array(buffer[:])
        let actual = config.decode_inplace(
          buffer,
          length=encoded.length(),
          simd~,
        )
        assert_eq(actual, length)
        assert_eq(Bytes::from_array(shared[:actual]), data)
        assert_eq(
          Bytes::from_array(buffer[actual:]),
          original[actual:].to_owned(),
        )
        let whole = encoded.to_fixedarray()
        assert_eq(config.decode_inplace(whole, simd~), length)
        assert_eq(Bytes::from_array(whole[:length]), data)
      }
    }
  }
}

///|
test "buffer range and structural errors leave destinations unchanged" {
  for simd in [false, true] {
    let output : FixedArray[Byte] = [b'!', b'!', b'!']
    too_small(() => ignore(@base64.standard.encode_into(b"foo", output, simd~)))
    too_small(() => {
      ignore(@base64.standard.encode_into(b"", output, offset=-1, simd~))
    })
    too_small(() => {
      ignore(@base64.standard.encode_into(b"", output, offset=4, simd~))
    })
    too_small(() => {
      ignore(@base64.standard.decode_into(b"Zm9v", output, offset=1, simd~))
    })
    too_small(() => {
      ignore(@base64.standard.decode_into(b"", output, offset=-1, simd~))
    })
    too_small(() => {
      ignore(@base64.standard.decode_into(b"", output, offset=4, simd~))
    })
    invalid(() => ignore(@base64.standard.decode_into(b"A", output, simd~)))
    invalid(() => {
      ignore(@base64.standard.decode_inplace(output, length=-1, simd~))
    })
    invalid(() => {
      ignore(@base64.standard.decode_inplace(output, length=4, simd~))
    })
    assert_eq(Bytes::from_array(output[:]), b"!!!")
    let capacity = FixedArray::make(64, b'!')
    invalid(() => {
      ignore(
        @base64.standard.decode_into(
          b"AAAA".repeat(8) + b"!!!!",
          capacity,
          simd~,
        ),
      )
    })
    assert_eq(Bytes::from_array(capacity[27:]), b"!".repeat(37))
  }
}

///|
test "append operations preserve prefixes and decode failure is atomic" {
  // Prefixes and input retained from base64-simd 0.8.0 tests/it.rs::allocation.
  for simd in [false, true] {
    let encoded = StringBuilder()
    encoded.write_string("data:;base64,")
    @base64.standard.encode_append(b"helloworld", encoded, simd~)
    assert_eq(encoded.to_string(), "data:;base64,aGVsbG93b3JsZA==")
    let decoded = @buffer.Buffer()
    decoded.write_bytes(b"123")
    @base64.standard.decode_append(b"aGVsbG93b3JsZA==", decoded, simd~)
    assert_eq(decoded.to_bytes(), b"123helloworld")
    let shared = decoded
    invalid(() => {
      @base64.standard.decode_append(
        b"AAAA".repeat(8) + b"AAAB====",
        decoded,
        simd~,
      )
    })
    assert_eq(shared.to_bytes(), b"123helloworld")
  }
}
