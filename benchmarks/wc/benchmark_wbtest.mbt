///|
/// Holds a deterministic view and its prepared chunks for the stream API.
priv struct Workload {
  name : String
  data : BytesView
  offset : Int32
  chunks : Array[BytesView]
}

///|
/// Builds the same text and binary inputs for every backend.
fn workloads() -> Array[Workload] {
  let text = b"Words in a line\r\nmore\twords and a final word\n"
  let workloads : Array[Workload] = []
  for
    (name, length, offset, chunk) in [
      ("short", 13, 0, 0),
      ("offset", 33, 3, 0),
      ("text", 4096, 0, 0),
      ("binary", 65539, 1, 0),
      ("stream63", 4096, 0, 63),
      ("stream8k", 1048576, 0, 8192),
    ] {
    let buffer = Bytes::makei(length + offset, i => {
      if i < offset {
        b'\n'
      } else if name == "binary" {
        let index = i - offset
        (index * 197 + index / 13).to_byte()
      } else {
        text[(i - offset) % text.length()]
      }
    })
    let data = buffer[offset:]
    let chunks : Array[BytesView] = []
    if chunk != 0 {
      for start = 0; start < length; start = start + chunk {
        chunks.push(data[start:(start + chunk).min(length)])
      }
    }
    workloads.push({ name, data, offset, chunks, })
  }
  workloads
}

///|
/// Counts words at their end using explicit separators and an incoming state.
fn reference_scan(data : BytesView, inside : Bool) -> (Int32, Int32, Bool) {
  for byte in data; lines = 0, completed = 0, inside = inside {
    let newline = if byte == 0x0A { 1 } else { 0 }
    match byte {
      0x20 | 0x09 | 0x0A | 0x0B | 0x0C | 0x0D =>
        continue lines + newline,
          completed + (if inside { 1 } else { 0 }),
          false
      _ => continue lines, completed, true
    }
  } nobreak {
    (lines, completed, inside)
  }
}

///|
/// Runs the independent scalar comparison and includes final-word handling.
fn reference(workload : Workload) -> (UInt64, UInt64, UInt64) {
  let (lines, completed, inside) = if workload.chunks.is_empty() {
    reference_scan(workload.data, false)
  } else {
    for chunk in workload.chunks; lines = 0, words = 0, inside = false {
      let (more_lines, more_words, inside) = reference_scan(chunk, inside)
      continue lines + more_lines, words + more_words, inside
    } nobreak {
      (lines, words, inside)
    }
  }
  let words = completed + (if inside { 1 } else { 0 })
  (lines.to_uint64(), words.to_uint64(), workload.data.length().to_uint64())
}

///|
/// Measures the public one-shot or mutable stream API with visible totals.
fn measured(
  workload : Workload,
  implementation : String,
) -> (UInt64, UInt64, UInt64) {
  if implementation == "reference" {
    return reference(workload)
  }
  let simd = implementation == "own-simd"
  let result = if workload.chunks.is_empty() {
    @wc.count(workload.data, simd~)
  } else {
    let counter = @wc.Counter::new(simd~)
    for chunk in workload.chunks {
      counter.update(chunk)
    }
    counter.counts()
  }
  (result.lines, result.words, result.bytes)
}

///|
test "word count adapters agree for identical inputs and chunk schedules" {
  let inputs = workloads()
  assert_eq(inputs.map(input => input.data.length()), [
    13, 33, 4096, 65539, 4096, 1048576,
  ])
  for input in inputs {
    let expected = reference({ ..input, chunks: [], })
    for implementation in ["reference", "own-scalar", "own-simd"] {
      assert_eq(measured(input, implementation), expected)
    }
  }
}

///|
test "bench wc one-shot and streaming" (bench : @bench.T) {
  let implementations = if @env.get_env_var("WC_BENCHMARK_REVERSE") == Some("1") {
    ["own-simd", "own-scalar", "reference"]
  } else {
    ["reference", "own-scalar", "own-simd"]
  }
  for input in workloads() {
    let expected = reference({ ..input, chunks: [], })
    for implementation in implementations {
      assert_eq(measured(input, implementation), expected)
      bench.bench(
        name="\{input.name}:\{implementation}:\{input.data.length()}:\{input.offset}",
        () => bench.keep(measured(input, implementation)),
      )
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
