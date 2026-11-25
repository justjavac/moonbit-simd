///|
test "bench strict UTF-8 validation and decoder acceptance baselines" (
  bench : @bench.T,
) {
  for input in inputs() {
    for (view, offset) in views(input) {
      let workload = if input.valid {
        "validate-" + input.label
      } else {
        input.label
      }
      for (implementation, validate) in validators() {
        bench.bench(
          name="\{workload}:\{implementation}:\{view.length()}:\{offset}",
          () => bench.keep(validate(view)),
        )
      }
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench strict UTF-8 validation plus UTF-16 decoding" (bench : @bench.T) {
  for input in inputs() {
    if !input.valid {
      continue
    }
    for (view, offset) in views(input) {
      for (implementation, decode) in decoders() {
        bench.bench(
          name="decode-\{input.label}:\{implementation}:\{view.length()}:\{offset}",
          () => bench.keep(decode(view)),
        )
      }
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench streaming UTF-8 validation with prepared owned chunks" (
  bench : @bench.T,
) {
  for
    (label, pattern) in [
      ("ascii", b"a"),
      ("mixed", b"abcd\xC3\xB6\xE4\xB8\xAD\xF0\x9F\x98\x80xyz"),
    ] {
    let data = repeated(pattern, 65536)
    for chunk in [1, 64, 4096] {
      let chunks : Array[Bytes] = []
      for offset = 0; offset < data.length(); offset = offset + chunk {
        chunks.push(data[offset:(offset + chunk).min(data.length())].to_owned())
      }
      for simd in [false, true] {
        let implementation = if simd { "own-simd" } else { "own-scalar" }
        bench.bench(name="stream-\{label}:\{implementation}:65536:\{chunk}", () => {
          let state = @ours.Validator::new(simd~)
          for bytes in chunks {
            state.update(bytes)
          }
          bench.keep(state.finalize())
        })
      }
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
