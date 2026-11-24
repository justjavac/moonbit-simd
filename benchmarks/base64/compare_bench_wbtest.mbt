///|
test "bench Base64 allocating public encoding and decoding" (bench : @bench.T) {
  for variant in variants {
    for length in variant.sizes() {
      let input = payload(length)
      let encoded = expected_encoding(input, variant)
      for implementation in libraries {
        if implementation.supports(variant) {
          if implementation.encodes(length) {
            bench.bench(
              name="encode-\{variant.label()}:\{implementation.label()}:\{length}:0",
              () => bench.keep(implementation.encode(input, variant)),
            )
          }
          bench.bench(
            name="decode-\{variant.label()}:\{implementation.label()}:\{length}:0",
            () => bench.keep(implementation.decode(encoded, variant)),
          )
        }
      }
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench Base64 public APIs on partial byte and UTF-16 views" (
  bench : @bench.T,
) {
  for length in [64, 1048576] {
    let input = payload(length)
    let backing = b"!" + input + b"!"
    let view = backing[1:1 + length]
    let encoded = expected_encoding(input, Standard)
    let string_backing = "!" + encoded + "!"
    let string_view = string_backing[1:1 + encoded.length()]
    for implementation in libraries {
      if implementation.encodes(length) {
        bench.bench(
          name="encode-standard:\{implementation.label()}:\{length}:1",
          () => bench.keep(implementation.encode(view, Standard)),
        )
      }
      bench.bench(
        name="decode-standard:\{implementation.label()}:\{length}:1",
        () => bench.keep(implementation.decode(string_view, Standard)),
      )
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench Base64 public decoding from prepared ASCII bytes" (bench : @bench.T) {
  for length in [64, 1048576] {
    let encoded = ascii(expected_encoding(payload(length), Standard))
    for simd in [false, true] {
      let implementation = if simd { "own-simd" } else { "own-scalar" }
      bench.bench(name="decode-bytes-standard:\{implementation}:\{length}:0", () => {
        bench.keep(try! @ours.standard.decode(encoded, simd~))
      })
    }
    bench.bench(name="decode-bytes-standard:moonbase:\{length}:0", () => {
      bench.keep(
        try! @moonbase.decode_bytes(encoded, padding=true, strict=true),
      )
    })
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench Base64 buffer reuse, checking, and in-place decoding" (
  bench : @bench.T,
) {
  for length in [64, 1048576] {
    let input = payload(length)
    let encoded = ascii(expected_encoding(input, Standard))
    for simd in [false, true] {
      let implementation = if simd { "own-simd" } else { "own-scalar" }
      let encode_output = FixedArray::make(encoded.length(), b'\x00')
      let decode_output = FixedArray::make(length, b'\x00')
      bench.bench(name="encode-into-standard:\{implementation}:\{length}:0", () => {
        bench.keep(try! @ours.standard.encode_into(input, encode_output, simd~))
        bench.keep(encode_output)
      })
      bench.bench(name="decode-into-standard:\{implementation}:\{length}:0", () => {
        bench.keep(
          try! @ours.standard.decode_into(encoded, decode_output, simd~),
        )
        bench.keep(decode_output)
      })
      bench.bench(
        name="decode-inplace-standard:\{implementation}:\{length}:0",
        () => {
          let buffer = encoded.to_fixedarray()
          bench.keep(try! @ours.standard.decode_inplace(buffer, simd~))
          bench.keep(buffer)
        },
      )
      bench.bench(name="check-standard:\{implementation}:\{length}:0", () => {
        bench.keep(try! @ours.standard.check(encoded, simd~))
      })
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
