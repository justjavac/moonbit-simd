///|
/// Describes one prepared strict UTF-8 validation workload.
struct Input {
  label : String
  data : Bytes
  valid : Bool
}

///|
/// Repeats an exact byte pattern outside timed operations.
fn repeated(pattern : BytesView, length : Int32) -> Bytes {
  Bytes::makei(length, index => pattern[index % pattern.length()])
}

///|
/// Supplies the same valid texts and malformed inputs to every adapter.
fn inputs() -> Array[Input] {
  let mixed = b"abcd\xC3\xB6\xE4\xB8\xAD\xF0\x9F\x98\x80xyz"
  [
    { label: "empty", data: b"", valid: true, },
    { label: "ascii-15", data: Bytes::make(15, b'a'), valid: true, },
    { label: "ascii-64", data: Bytes::make(64, b'a'), valid: true, },
    { label: "ascii-4k", data: Bytes::make(4096, b'a'), valid: true, },
    { label: "ascii-1m", data: Bytes::make(1048576, b'a'), valid: true, },
    { label: "latin-4k", data: repeated(b"\xC3\xB6", 4096), valid: true, },
    { label: "cjk-4k", data: repeated(b"\xE4\xB8\xAD", 4095), valid: true, },
    {
      label: "emoji-4k",
      data: repeated(b"\xF0\x9F\x98\x80", 4096),
      valid: true,
    },
    { label: "mixed-4k", data: repeated(mixed, 4096), valid: true, },
    { label: "cjk-1m", data: repeated(b"\xE4\xB8\xAD", 1048575), valid: true, },
    {
      label: "emoji-1m",
      data: repeated(b"\xF0\x9F\x98\x80", 1048576),
      valid: true,
    },
    {
      label: "invalid-start",
      data: b"\xFF" + Bytes::make(65535, b'a'),
      valid: false,
    },
    {
      label: "invalid-end",
      data: Bytes::make(65535, b'a') + b"\xFF",
      valid: false,
    },
    {
      label: "invalid-overlong",
      data: Bytes::make(32767, b'a') +
      b"\xE0\x80\x80" +
      Bytes::make(32766, b'a'),
      valid: false,
    },
    {
      label: "invalid-truncated",
      data: Bytes::make(65535, b'a') + b"\xF0",
      valid: false,
    },
  ]
}

///|
/// Adds an offset-one partial view with invalid sentinels to selected text inputs.
fn views(input : Input) -> Array[(BytesView, Int32)] {
  let result = [(input.data[:], 0)]
  if ["ascii-4k", "cjk-4k", "emoji-4k"].contains(input.label) {
    let backing = b"\xFF" + input.data + b"\xFF"
    result.push((backing[1:1 + input.data.length()], 1))
  }
  result
}

///|
/// Converts the compat API's precise error into an acceptance result.
fn own_compat(input : BytesView) -> Bool {
  try @ours.validate(input) catch {
    _ => false
  } noraise {
    _ => true
  }
}

///|
/// Uses tonyfettes' validating byte-string constructor, including view materialization.
fn tonyfettes_valid(input : BytesView) -> Bool {
  try @tonyfettes.Utf8::of_bytesview(input) catch {
    _ => false
  } noraise {
    _ => true
  }
}

///|
/// Uses core's strict decoder as an acceptance baseline, including UTF-16 allocation.
fn core_valid(input : BytesView) -> Bool {
  try @core.decode(input, ignore_bom=false) catch {
    _ => false
  } noraise {
    _ => true
  }
}

///|
/// Returns public validation adapters with all required adaptation inside the call.
fn validators() -> Array[(String, (BytesView) -> Bool)] {
  [
    ("own-basic-scalar", input => @ours.is_valid(input, simd=false)),
    ("own-basic-simd", input => @ours.is_valid(input, simd=true)),
    ("own-compat", own_compat),
    ("tonyfettes", tonyfettes_valid),
    ("core", core_valid),
  ]
}

///|
/// Normalizes strict decoding APIs to observable optional UTF-16 strings.
fn decoders() -> Array[(String, (BytesView) -> String?)] {
  [
    (
      "own-scalar",
      input => {
        try @ours.from_utf8(input, simd=false) catch {
          _ => None
        } noraise {
          text => Some(text)
        }
      },
    ),
    (
      "own-simd",
      input => {
        try @ours.from_utf8(input, simd=true) catch {
          _ => None
        } noraise {
          text => Some(text)
        }
      },
    ),
    (
      "tonyfettes",
      input => {
        try @tonyfettes.decode(input) catch {
          _ => None
        } noraise {
          text => Some(text)
        }
      },
    ),
    (
      "core",
      input => {
        try @core.decode(input, ignore_bom=false) catch {
          _ => None
        } noraise {
          text => Some(text)
        }
      },
    ),
  ]
}

///|
test "UTF-8 comparison adapters agree on acceptance and decoded text" {
  let cases = inputs()
  assert_eq(cases.length(), 15)
  for input in cases {
    let expected = if input.valid {
      Some(@core.decode(input.data, ignore_bom=false))
    } else {
      None
    }
    for (view, _) in views(input) {
      for (_, validate) in validators() {
        assert_eq(validate(view), input.valid)
      }
      for (_, decode) in decoders() {
        assert_eq(decode(view), expected)
      }
    }
  }
  // BOM and scalar limits also check semantic equivalence outside measured cases.
  for bytes in [b"\xEF\xBB\xBF", b"\x00", b"\xF4\x8F\xBF\xBF", b"\xED\xA0\x80"] {
    for (_, validate) in validators() {
      assert_eq(validate(bytes), core_valid(bytes))
    }
    let expected = try @core.decode(bytes, ignore_bom=false) catch {
      _ => None
    } noraise {
      text => Some(text)
    }
    for (_, decode) in decoders() {
      assert_eq(decode(bytes), expected)
    }
  }
}
