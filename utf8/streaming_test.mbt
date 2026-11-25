///|
test "streaming matches whole-input validation for varied and empty chunks" {
  let valid = @encoding.encode(
    "ASCII, Ελληνικά, 中文, 😀, \u{FEFF}, \u{0}. ".repeat(37),
  )
  let inputs = [
    valid,
    valid + b"\xF0\x9F",
    valid + b"\xFF",
    b"\xC0\x80" + valid,
    Bytes::make(63, b'a') + b"\xF4\x8F\xBF\xBF" + valid,
  ]
  for data in inputs {
    let expected = @utf8.is_valid(data, simd=false)
    for simd in [false, true] {
      for
        chunk in [1, 2, 3, 7, 15, 16, 31, 63, 64, 65, 99, 128, 256, 1024, 4096] {
        let state = @utf8.Validator::new(simd~)
        for offset = 0; offset < data.length(); offset = offset + chunk {
          state.update(data[offset:(offset + chunk).min(data.length())])
          state.update(b"")
        }
        assert_eq(state.finalize(), expected)
        assert_eq(state.finalize(), expected)
      }
    }
  }
}

///|
test "every split of valid and invalid sequences preserves streaming restrictions" {
  let sequences : Array[Bytes] = [
    b"\xC2\x80", b"\xE0\xA0\x80", b"\xED\x9F\xBF", b"\xF0\x90\x80\x80", b"\xF4\x8F\xBF\xBF",
    b"\xE0\x9F\x80", b"\xED\xA0\x80", b"\xF0\x8F\xBF\xBF", b"\xF4\x90\x80\x80", b"\xF0\x9F\x98a",
  ]
  for prefix in [0, 15, 31, 63, 127] {
    for sequence in sequences {
      let data = Bytes::make(prefix, b'a') + sequence
      for split in 0..<=data.length() {
        for simd in [false, true] {
          let state = @utf8.Validator::new(simd~)
          state.update(data[:split])
          state.update(data[split:])
          assert_eq(state.finalize(), @utf8.is_valid(data, simd=false))
        }
      }
    }
  }
}

///|
test "observation permits completion, reset clears errors, and copies isolate state" {
  let state = @utf8.Validator::new()
  assert_true(state.finalize())
  state.update(b"\xF0\x9F")
  assert_true(!state.finalize())
  let branch = state.copy()
  state.update(b"\x98\x80")
  assert_true(state.finalize())
  assert_true(!branch.finalize())
  branch.update(b"a")
  assert_true(!branch.finalize())
  branch.update(b"valid suffix")
  assert_true(!branch.finalize())
  let shared = state
  shared.update(b"\xFF")
  assert_true(!state.finalize())
  shared.reset()
  assert_true(state.finalize())
  assert_true(!branch.finalize())
  branch.reset()
  branch.update(b"\xE2\x82\xAC")
  assert_true(branch.finalize())
}
