///|
test "upstream forgiving vectors retain ignored unused bits and exact whitespace" {
  // Expectations retained from base64-simd 0.8.0 src/forgiving.rs.
  let vectors : Array[(Bytes, Bytes)] = [
    (b"ab", b"\x69"),
    (b"abc", b"\x69\xb7"),
    (b"abcd", b"\x69\xb7\x1d"),
    (b"helloworld", b"\x85\xe9\x65\xa3\x0a\x2b\x95"),
    (b" h e l l o w o r\nl\rd\t", b"\x85\xe9\x65\xa3\x0a\x2b\x95"),
    (b"", b""),
    (b" \t\n\x0c\r", b""),
    (b"Zg", b"f"),
    (b"Zh", b"f"),
    (b"Zh==", b"f"),
    (b"Zm8", b"fo"),
    (b"Zm9", b"fo"),
    (b"Zm9=", b"fo"),
    (b" Z\th\x0c=\r=\n ", b"f"),
  ]
  for (input, expected) in vectors {
    for simd in [false, true] {
      assert_eq(@base64.forgiving_decode(input, simd~), expected)
      let text = String::from_array(
        [
          for byte in input => byte.to_int().to_char().unwrap()
        ],
      )
      assert_eq(@base64.forgiving_decode_string(text, simd~), expected)
      let output = FixedArray::make(expected.length() + 2, b'!')
      assert_eq(
        @base64.forgiving_decode_into(input, output, offset=1, simd~),
        expected.length(),
      )
      assert_eq(Bytes::from_array(output[:]), b"!" + expected + b"!")
      let inplace = (input + b"!").to_fixedarray()
      let decoded = @base64.forgiving_decode_inplace(
        inplace,
        length=input.length(),
        simd~,
      )
      assert_eq(decoded, expected.length())
      assert_eq(Bytes::from_array(inplace[:decoded]), expected)
      let whole = input.to_fixedarray()
      assert_eq(
        @base64.forgiving_decode_inplace(whole, simd~),
        expected.length(),
      )
    }
  }
}

///|
test "forgiving vector blocks and whitespace normalization preserve binary output" {
  for length in 0..<130 {
    let expected = payload(length)
    let encoded = ascii(bitstream_encode(expected, false, true))
    let spaced = Bytes::from_array(
      [
        for byte in encoded => [byte, b' ', b'\t', b'\n', b'\x0c', b'\r']
      ].flatten()[:],
    )
    for simd in [false, true] {
      assert_eq(@base64.forgiving_decode(encoded, simd~), expected)
      assert_eq(@base64.forgiving_decode(spaced, simd~), expected)
      let data = spaced.to_fixedarray()
      assert_eq(@base64.forgiving_decode_inplace(data, simd~), length)
      assert_eq(Bytes::from_array(data[:length]), expected)
    }
  }
}

///|
test "forgiving rejects vertical tab, wrong alphabet, and malformed padding" {
  for
    input in [
      b"A", b"=", b"==", b"===", b"====", b"AA=", b"AA===", b"AAA==", b"AA=A", b"AAAA=",
      b"AAAA====", b"AA==AAAA", b"AA\x0bA", b"AA\x00A", b"-_8=", b"AA\xffA", b" AA\xffA",
    ] {
    for simd in [false, true] {
      invalid(() => ignore(@base64.forgiving_decode(input, simd~)))
      let data = input.to_fixedarray()
      invalid(() => ignore(@base64.forgiving_decode_inplace(data, simd~)))
      let output = FixedArray::make(64, b'!')
      invalid(() => ignore(@base64.forgiving_decode_into(input, output, simd~)))
    }
  }
  let output : FixedArray[Byte] = []
  too_small(() => ignore(@base64.forgiving_decode_into(b" Z h = = ", output)))
  too_small(() => ignore(@base64.forgiving_decode_into(b"", output, offset=1)))
  invalid(() => ignore(@base64.forgiving_decode_inplace(output, length=-1)))
}
