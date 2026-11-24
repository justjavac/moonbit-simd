///|
test "tonyfettes URL adapters match independent expected results" {
  let base = @tony.Url::parse(@cases.base_url())
  @cases.verify(
    input => try! @tony.Url::parse(input),
    url => url.href(),
    input => try! @tony.Url::parse(input, base~),
    input => @tony.UrlSearchParams::from_string(input).to_string(),
  )
}

///|
test "bench tonyfettes absolute parsing" (bench : @bench.T) {
  @cases.absolute_bench(
    bench,
    "tonyfettes",
    input => try! @tony.Url::parse(input),
    url => url.href(),
  )
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench tonyfettes relative parsing" (bench : @bench.T) {
  let base = try! @tony.Url::parse(@cases.base_url())
  @cases.relative_bench(
    bench,
    "tonyfettes",
    input => try! @tony.Url::parse(input, base~),
    url => url.href(),
  )
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench tonyfettes form query" (bench : @bench.T) {
  @cases.form_bench(bench, "tonyfettes", input => {
    @tony.UrlSearchParams::from_string(input).to_string()
  })
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
