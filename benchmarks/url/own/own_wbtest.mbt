///|
test "URL benchmark adapters match independent expected results" {
  let base = @ours.parse(@cases.base_url())
  for simd in [false, true] {
    @cases.verify(
      input => try! @ours.parse(input, simd~),
      url => url.href(),
      input => try! @ours.parse(input, base~, simd~),
      input => @ours.SearchParams::parse(input).to_string(),
    )
  }
}

///|
test "bench own absolute parsing" (bench : @bench.T) {
  for simd in [false, true] {
    let implementation = if simd {
      "justjavac-simd"
    } else {
      "justjavac-scalar"
    }
    @cases.absolute_bench(
      bench,
      implementation,
      input => try! @ours.parse(input, simd~),
      url => url.href(),
    )
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench own relative parsing" (bench : @bench.T) {
  let base = try! @ours.parse(@cases.base_url())
  for simd in [false, true] {
    let implementation = if simd {
      "justjavac-simd"
    } else {
      "justjavac-scalar"
    }
    @cases.relative_bench(
      bench,
      implementation,
      input => try! @ours.parse(input, base~, simd~),
      url => url.href(),
    )
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench own form query" (bench : @bench.T) {
  @cases.form_bench(bench, "justjavac", input => {
    @ours.SearchParams::parse(input).to_string()
  })
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
