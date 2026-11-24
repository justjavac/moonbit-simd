///|
test "scalar and SIMD scans agree at block boundaries and unaligned subviews" {
  for length in [0, 1, 7, 8, 15, 16, 17, 31, 32, 33, 64, 257] {
    for offset in [0, 1, 3] {
      for special in [false, true] {
        let plain = Bytes::make(length + offset, b'a')
        let view = plain[offset:]
        assert_eq(
          authority_end(view, special, false),
          authority_end(view, special, true),
        )
        assert_eq(contains_ignored(view, false), contains_ignored(view, true))
        for position in 0..<length {
          for byte in [b'/', b'?', b'\\', b'\t', b'\n', b'\r'] {
            let data = Bytes::makei(length + offset, i => {
              if i == offset + position {
                byte
              } else {
                b'a'
              }
            })
            let view = data[offset:]
            assert_eq(
              authority_end(view, special, false),
              authority_end(view, special, true),
            )
            assert_eq(
              contains_ignored(view, false),
              contains_ignored(view, true),
            )
          }
        }
      }
    }
  }
}

///|
test "SWAR case folding matches an independent per-byte ASCII oracle" {
  for offset in [0, 1, 3] {
    let bytes = Bytes::makei(256 + offset, i => ((i * 37) & 127).to_byte())
    let view = bytes[offset:]
    let expected = Bytes::from_iter(
      view
      .iter()
      .map(byte => if byte >= b'A' && byte <= b'Z' { byte + 32 } else { byte }),
    )
    assert_eq(@utf8.encode(lower_ascii(view)), expected)
  }
}
