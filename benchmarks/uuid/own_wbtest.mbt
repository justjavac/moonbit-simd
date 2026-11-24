///|
/// Reports whether the requested public text parser rejected input.
fn own_rejected(input : StringView, algorithm : @ours.Algorithm) -> Bool {
  try @ours.parse(input, algorithm~) catch {
    _ => true
  } noraise {
    _ => false
  }
}

///|
test "UUID scalar and SIMD adapters match independent binary and formatting oracles" {
  for algorithm in [@ours.Scalar, @ours.Simd] {
    verify_library(
      input => try! @ours.parse(input, algorithm~),
      id => id.to_bytes(),
      id => id.format_hyphenated(algorithm~),
      input => own_rejected(input, algorithm),
      simple=id => id.format_simple(algorithm~),
      braced=true,
    )
    for (label, text, bytes) in text_cases() {
      if label == "nil" || label == "max" || label == "mixed" {
        continue
      }
      for offset in [0, 1] {
        let raw = @utf8.encode("!".repeat(offset) + text + "!")
        assert_eq(
          @ours.parse_bytes(raw[offset:offset + text.length()], algorithm~).to_bytes(),
          bytes,
        )
      }
    }
  }
}

///|
test "bench own UUID public operations" (bench : @bench.T) {
  for algorithm in [@ours.Scalar, @ours.Simd] {
    let implementation = if algorithm == @ours.Scalar {
      "own-scalar"
    } else {
      "own-simd"
    }
    benchmark_library(
      bench,
      implementation,
      input => try! @ours.parse(input, algorithm~),
      id => id.format_hyphenated(algorithm~),
      input => own_rejected(input, algorithm),
      simple=id => id.format_simple(algorithm~),
      braced=true,
    )
    let id = try! @ours.parse(text_cases()[1].1)
    bench.bench(name="format-simple-upper:\{implementation}:16:0", () => {
      bench.keep(id.format_simple(case=@ours.Upper, algorithm~))
    })
    bench.bench(name="format-hyphenated-upper:\{implementation}:16:0", () => {
      bench.keep(id.format_hyphenated(case=@ours.Upper, algorithm~))
    })
    for (label, text, _) in text_cases() {
      if label == "nil" || label == "max" || label == "mixed" {
        continue
      }
      for offset in [0, 1] {
        let source = @utf8.encode("!".repeat(offset) + text + "!")
        let input = source[offset:offset + text.length()]
        bench.bench(
          name="parse-bytes-\{label}:\{implementation}:\{text.length()}:\{offset}",
          () => bench.keep(try! @ours.parse_bytes(input, algorithm~)),
        )
      }
    }
    for (case, label) in [(@ours.Lower, "lower"), (@ours.Upper, "upper")] {
      for offset in [0, 1] {
        let simple : FixedArray[Byte] = FixedArray::make(offset + 33, 0)
        let canonical : FixedArray[Byte] = FixedArray::make(offset + 37, 0)
        bench.bench(
          name="write-simple-\{label}:\{implementation}:16:\{offset}",
          () => {
            try! id.write_simple(simple, offset~, case~, algorithm~)
            bench.keep(simple)
          },
        )
        bench.bench(
          name="write-hyphenated-\{label}:\{implementation}:16:\{offset}",
          () => {
            try! id.write_hyphenated(canonical, offset~, case~, algorithm~)
            bench.keep(canonical)
          },
        )
      }
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
