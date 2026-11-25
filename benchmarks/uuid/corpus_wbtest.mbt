///|
/// Provides identical ASCII input spellings and independent expected binary UUIDs.
fn text_cases() -> Array[(String, String, Bytes)] {
  let example : Bytes = [
    0x67, 0xe5, 0x50, 0x44, 0x10, 0xb1, 0x42, 0x6f, 0x92, 0x47, 0xbb, 0x68, 0x0e,
    0x5f, 0xe0, 0xc8,
  ]
  let canonical = "67e55044-10b1-426f-9247-bb680e5fe0c8"
  [
    ("simple", "67e5504410b1426f9247bb680e5fe0c8", example),
    ("hyphenated", canonical, example),
    ("mixed", "67E55044-10b1-426F-9247-bB680e5Fe0c8", example),
    ("nil", "00000000-0000-0000-0000-000000000000", Bytes::makei(16, _ => 0)),
    ("max", "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF", Bytes::makei(16, _ => 255)),
    ("braced", "{" + canonical + "}", example),
    ("urn", "urn:uuid:" + canonical, example),
  ]
}

///|
/// Selects the shared full-string and materialized partial-view workloads.
fn input_offsets(label : String) -> Array[Int32] {
  if label == "simple" || label == "hyphenated" {
    [0, 1]
  } else {
    [0]
  }
}

///|
/// Defines rejection workloads shared by every comparison API.
fn invalid_cases() -> Array[(String, String)] {
  [
    ("empty", ""),
    ("short", "67e5504410b1426f9247bb680e5fe0c"),
    ("start", "g7e55044-10b1-426f-9247-bb680e5fe0c8"),
    ("end", "67e55044-10b1-426f-9247-bb680e5fe0cg"),
  ]
}

///|
/// Formats expected text with independent arithmetic rather than a compared codec.
fn reference_simple(input : BytesView) -> String {
  let builder = StringBuilder()
  for byte in input {
    for nibble in [byte.to_int() >> 4, byte.to_int() & 15] {
      let code = if nibble < 10 { 48 + nibble } else { 87 + nibble }
      builder.write_char(code.unsafe_to_char())
    }
  }
  builder.to_string()
}

///|
/// Inserts the fixed 8-4-4-4-12 separators into independently produced hex text.
fn reference_hyphenated(input : BytesView) -> String {
  let text = reference_simple(input)
  "\{text[:8]}-\{text[8:12]}-\{text[12:16]}-\{text[16:20]}-\{text[20:]}"
}

///|
/// Prepares 1024 deterministic distinct UUID values before verification or timing.
fn batch_cases() -> Array[(String, Bytes)] {
  let mut seed = 0xA5A5F00DU
  Array::makei(1024, _ => {
    let bytes = Bytes::makei(16, _ => {
      seed = seed * 1664525U + 1013904223U
      (seed >> 24).to_byte()
    })
    (reference_hyphenated(bytes), bytes)
  })
}

///|
/// Checks binary identity and canonical results through a library's public adapters.
fn[A] verify_library(
  parse_ : (StringView) -> A,
  bytes_ : (A) -> Bytes,
  canonical : (A) -> String,
  rejected : (StringView) -> Bool,
  simple? : (A) -> String,
  braced~ : Bool,
) -> Unit raise {
  for (label, text, bytes) in text_cases() {
    if label == "braced" && !braced {
      continue
    }
    for offset in input_offsets(label) {
      let source = if offset == 0 { text } else { "!" + text + "!" }
      let input = source[offset:offset + text.length()]
      let id = parse_(input)
      assert_eq(bytes_(id), bytes)
      assert_eq(canonical(id), reference_hyphenated(bytes))
      if simple is Some(format_) {
        assert_eq(format_(id), reference_simple(bytes))
      }
    }
  }
  for (_, input) in invalid_cases() {
    assert_true(rejected(input))
  }
  for (input, bytes) in batch_cases() {
    let id = parse_(input)
    assert_eq(bytes_(id), bytes)
    assert_eq(canonical(id), input)
  }
}

///|
/// Measures identical parse, canonical roundtrip, output, rejection, and batch APIs.
fn[A] benchmark_library(
  bench : @bench.T,
  implementation : String,
  parse_ : (StringView) -> A,
  canonical : (A) -> String,
  rejected : (StringView) -> Bool,
  simple? : (A) -> String,
  braced~ : Bool,
) -> Unit {
  for (label, text, _) in text_cases() {
    if label == "braced" && !braced {
      continue
    }
    for offset in input_offsets(label) {
      let source = if offset == 0 { text } else { "!" + text + "!" }
      let input = source[offset:offset + text.length()]
      for roundtrip in [false, true] {
        let workload = (if roundtrip { "roundtrip-" } else { "parse-" }) + label
        bench.bench(
          name="\{workload}:\{implementation}:\{text.length()}:\{offset}",
          () => {
            let id = parse_(input)
            if roundtrip {
              bench.keep(canonical(id))
            } else {
              bench.keep(id)
            }
          },
        )
      }
    }
  }
  let id = parse_(text_cases()[1].1)
  bench.bench(name="format-hyphenated:\{implementation}:16:0", () => {
    bench.keep(canonical(id))
  })
  if simple is Some(format_) {
    bench.bench(name="format-simple:\{implementation}:16:0", () => {
      bench.keep(format_(id))
    })
  }
  for (label, input) in invalid_cases() {
    bench.bench(name="invalid-\{label}:\{implementation}:\{input.length()}:0", () => {
      bench.keep(rejected(input))
    })
  }
  let batch = batch_cases()
  let text = batch.map(entry => entry.0)
  let ids = text.map(input => parse_(input))
  bench.bench(name="parse-batch1024:\{implementation}:36864:0", () => {
    for input in text {
      bench.keep(parse_(input))
    }
  })
  bench.bench(name="roundtrip-batch1024:\{implementation}:36864:0", () => {
    for input in text {
      bench.keep(canonical(parse_(input)))
    }
  })
  bench.bench(name="format-batch1024:\{implementation}:16384:0", () => {
    for id in ids {
      bench.keep(canonical(id))
    }
  })
}
