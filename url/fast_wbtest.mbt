///|
test "canonical fast parsing agrees with the complete parser across generated URLs" {
  for scheme in ["http", "https", "ws", "wss", "ftp"] {
    for
      host in [
        "example.com", "xn--", "x..a", "x.0xff", "0xffffffff1", "a.123.", "1abc.example",
        "a.-",
      ] {
      for
        path in [
          "", "/", "/a/b", "/a/../b", "/a.txt", "/%2e/x", "/a%20b", "/a//b", "/./",
          "/%", "/x'",
        ] {
        for
          tail in [
            "", "?", "#", "?#", "?a=b#c", "?x=%20", "?x='", "#x?y", "#{}。",
          ] {
          let source = "_" + scheme + "://" + host + path + tail + "_"
          let view = source[1:source.length() - 1]
          for simd in [false, true] {
            let expected = Some(
              freeze(parse_record(prepare_input(view, simd), None, simd)),
            ) catch {
              _ => None
            }
            let actual = try_parse(view, simd~)
            assert_eq(
              actual.map(url => url.href()),
              expected.map(url => url.href()),
            )
            if actual is Some(a) && expected is Some(b) {
              assert_eq(a.hostname().to_owned(), b.hostname().to_owned())
              assert_eq(a.pathname().to_owned(), b.pathname().to_owned())
              assert_eq(
                a.query().map(view => view.to_owned()),
                b.query().map(view => view.to_owned()),
              )
              assert_eq(
                a.fragment().map(view => view.to_owned()),
                b.fragment().map(view => view.to_owned()),
              )
            }
          }
        }
      }
    }
  }
}

///|
test "UTF-16 SIMD guard agrees at boundaries and every disallowed byte" {
  for length in [0, 1, 7, 8, 9, 15, 16, 17, 31, 32, 65] {
    for offset in [0, 1, 3] {
      for byte in 0..<256 {
        let character = byte.unsafe_to_char()
        let source = "_".repeat(offset) +
          "a".repeat(length) +
          character.to_string() +
          "tail"
        let input = source[offset:offset + length + 1]
        assert_eq(simple_ascii_wide(input), simple_ascii_scalar(input))
      }
    }
  }
}
