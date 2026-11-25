///|
test "bench all byte-search directions and arities" (bench : @bench.T) {
  for input in byte_inputs() {
    for (data, offset) in views(input.data, input.partial) {
      for (operation, arity, reverse) in byte_operations() {
        for implementation in byte_implementations(arity) {
          bench.bench(
            name="\{operation}-\{input.label}:\{implementation}:\{data.length()}:\{offset}",
            () => bench.keep(search_byte(data, arity, reverse, implementation)),
          )
        }
      }
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench complete byte counts and lazy match iteration" (bench : @bench.T) {
  for (label, data, arity, count) in iteration_inputs() {
    for implementation in ["own-scalar", "own-simd", "reference"] {
      bench.bench(name="\{label}:\{implementation}:\{data.length()}:0", () => {
        bench.keep(iterate_bytes(data, arity, count, implementation))
      })
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench substring one-off construction and reused finders" (
  bench : @bench.T,
) {
  for input in substring_inputs() {
    for (data, offset) in views(input.data, input.partial) {
      for reverse in [false, true] {
        let operation = if reverse { "rfind" } else { "find" }
        for implementation in substring_implementations(reverse) {
          bench.bench(
            name="\{operation}-\{input.label}:\{implementation}:\{data.length()}:\{offset}",
            () => {
              bench.keep(
                search_substring(data, input.needle, reverse, implementation),
              )
            },
          )
          let simd = implementation == "own-simd"
          let forward = @memmem.Finder::new(
            input.needle,
            simd~,
            prefilter=if implementation == "own-twoway" {
              @memmem.None
            } else {
              @memmem.Auto
            },
          )
          let backward = @memmem.FinderRev::new(input.needle, simd~)
          bench.bench(
            name="reuse-\{operation}-\{input.label}:\{implementation}:\{data.length()}:\{offset}",
            () => {
              let found = if implementation == "core" {
                if reverse {
                  data.rev_find(input.needle)
                } else {
                  data.find(input.needle)
                }
              } else if reverse {
                backward.rfind(data)
              } else {
                forward.find(data)
              }
              bench.keep(found.unwrap_or(-1))
            },
          )
        }
      }
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench non-overlapping and empty-boundary substring iteration" (
  bench : @bench.T,
) {
  for (label, data, needle) in substring_iteration_inputs() {
    for reverse in [false, true] {
      let operation = if reverse { "rfind-iter" } else { "find-iter" }
      for implementation in ["own-scalar", "own-simd", "reference"] {
        bench.bench(
          name="\{operation}-\{label}:\{implementation}:\{data.length()}:0",
          () => {
            bench.keep(
              iterate_substrings(data, needle, reverse, implementation),
            )
          },
        )
      }
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
