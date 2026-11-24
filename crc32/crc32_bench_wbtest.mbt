///|
/// Holds sizes covering empty input, block boundaries, cache-sized buffers, and 1 MiB.
let benchmark_sizes : Array[Int32] = [
  0, 1, 7, 8, 15, 16, 17, 64, 256, 1024, 4096, 65536, 1048576,
]

///|
/// Computes the checksum of a virtual zero-filled suffix without allocating it.
fn benchmark_zero_crc(length : UInt64) -> UInt32 {
  for remaining = length, block_len = 1UL, block = hash(b"\x00"), crc = 0U; remaining !=
     0; {
    let next = if (remaining & 1) != 0 {
      combine(crc, block, block_len)
    } else {
      crc
    }
    if remaining == 1 {
      break next
    }
    continue remaining >> 1,
      block_len << 1,
      combine(block, block, block_len),
      next
  } nobreak {
    crc
  }
}

///|
test "bench one-shot hashing across sizes and subviews" (bench : @bench.T) {
  for length in benchmark_sizes {
    let source = sample_bytes(length + 1)
    for offset in [0, 1] {
      let data = source[offset:offset + length]
      for simd in [false, true] {
        let implementation = if simd { "simd-request" } else { "scalar" }
        bench.bench(name="hash:\{implementation}:\{length}:\{offset}", () => {
          bench.keep(hash(data, simd~))
        })
      }
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench incremental hashing across chunk sizes" (bench : @bench.T) {
  let source = sample_bytes(65536)
  for chunk in [1, 16, 256, 4096, 65536] {
    for simd in [false, true] {
      let implementation = if simd { "simd-request" } else { "scalar" }
      bench.bench(name="stream:\{implementation}:65536:\{chunk}", () => {
        let state = Hasher::new(simd~)
        for offset = 0; offset < source.length(); offset = offset + chunk {
          state.update(source[offset:(offset + chunk).min(source.length())])
        }
        bench.keep(state.finalize())
      })
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench checksum combination across full-width suffix lengths" (
  bench : @bench.T,
) {
  let prefix = hash(b"prefix")
  for
    length in [
      0UL, 1UL, 64UL, 4096UL, 1048576UL, 0xFFFFFFFFUL, 0xFFFFFFFFFFFFFFFFUL,
    ] {
    let suffix = benchmark_zero_crc(length)
    bench.bench(name="combine:gf2:\{length}:0", () => {
      bench.keep(combine(prefix, suffix, length))
    })
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
