///|
/// Covers empty and short inputs, slicing boundaries, medium buffers, and 1 MiB.
let comparison_sizes : FixedArray[Int32] = [
  0, 1, 7, 8, 15, 16, 17, 64, 256, 1024, 4096, 65536, 1048576,
]

///|
test "bench public one-shot APIs with prepared owned input" (bench : @bench.T) {
  for length in comparison_sizes {
    let data = payload(length)
    for implementation in libraries {
      bench.bench(name="compare:\{implementation.label()}:\{length}:0", () => {
        bench.keep(implementation.checksum_owned(data))
      })
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench public APIs including required view materialization" (
  bench : @bench.T,
) {
  for length in [64, 1024, 4096, 65536, 1048576] {
    let source = payload(length + 1)
    let view = source[1:]
    for implementation in libraries {
      bench.bench(name="view:\{implementation.label()}:\{length}:1", () => {
        bench.keep(implementation.checksum_view(view))
      })
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench public streaming APIs with prepared owned chunks" (bench : @bench.T) {
  let data = payload(65536)
  for chunk_size in [1, 16, 256, 4096, 65536] {
    let chunks = prepared_chunks(data, chunk_size)
    for implementation in libraries {
      bench.bench(
        name="compare-stream:\{implementation.label()}:65536:\{chunk_size}",
        () => bench.keep(implementation.checksum_chunks(chunks)),
      )
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
