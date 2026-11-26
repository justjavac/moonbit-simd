///|
/// Builds the shared short, unaligned, and bulk byte views.
fn workloads() -> Array[(BytesView, Int32)] {
  let pattern = b"text \xC3\xA9 \xE6\xBC\xA2 \xF0\x9F\x98\x80\n"
  [(7, 0), (16, 0), (65, 3), (128, 0), (4096, 0), (1048576, 1)].map(workload => {
    let (length, offset) = workload
    let data = Bytes::makei(length + offset + 1, i => {
      if i < offset || i == offset + length {
        b' '
      } else {
        pattern[(i - offset) % pattern.length()]
      }
    })
    (data[offset:offset + length], offset)
  })
}

///|
/// Prepares equivalent public calls and checks them against direct predicates.
fn adapters(data : BytesView) -> Array[(String, String, () -> Int32, Int32)] {
  let mut matches = 0
  let mut chars = 0
  for byte in data {
    if byte == b' ' {
      matches += 1
    }
    if byte < 0x80 || byte >= 0xC0 {
      chars += 1
    }
  }
  [
    ("count", "own-dispatch", () => @bytecount.count(data, b' '), matches),
    ("count", "own-naive", () => @bytecount.naive_count(data, b' '), matches),
    ("count", "memchr", () => @memchr.memchr_iter(b' ', data).count(), matches),
    ("num-chars", "own-dispatch", () => @bytecount.num_chars(data), chars),
    ("num-chars", "own-naive", () => @bytecount.naive_num_chars(data), chars),
  ]
}

///|
test "byte count adapters agree on the benchmark views" {
  for (data, _) in workloads() {
    for (_, _, run, expected) in adapters(data) {
      assert_eq(run(), expected)
    }
  }
}

///|
test "bench bytecount public APIs" (bench : @bench.T) {
  let reversed = @env.get_env_var("BYTECOUNT_BENCHMARK_REVERSE") == Some("1")
  for (data, offset) in workloads() {
    let cases = adapters(data)
    for i = 0; i < cases.length(); i = i + 1 {
      let (operation, implementation, run, expected) = cases[if reversed {
          cases.length() - i - 1
        } else {
          i
        }]
      assert_eq(run(), expected)
      bench.bench(
        name="\{operation}:\{implementation}:\{data.length()}:\{offset}",
        () => bench.keep(run()),
      )
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
