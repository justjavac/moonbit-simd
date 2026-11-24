///|
test "connect0459 URL adapters match independent expected results" {
  let base = @urllib.parse(@cases.base_url())
  @cases.verify(
    input => try! @urllib.parse(input.to_owned()),
    url => url.href(),
    input => try! @urllib.parse_with_base(input.to_owned(), Some(base)),
    input => @urllib.UrlSearchParams::from_string(input).to_string(),
  )
}

///|
test "bench connect0459 absolute parsing" (bench : @bench.T) {
  @cases.absolute_bench(
    bench,
    "connect0459",
    input => try! @urllib.parse(input.to_owned()),
    url => url.href(),
  )
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench connect0459 relative parsing" (bench : @bench.T) {
  let base = try! @urllib.parse(@cases.base_url())
  @cases.relative_bench(
    bench,
    "connect0459",
    input => try! @urllib.parse_with_base(input.to_owned(), Some(base)),
    url => url.href(),
  )
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench connect0459 form query" (bench : @bench.T) {
  @cases.form_bench(bench, "connect0459", input => {
    @urllib.UrlSearchParams::from_string(input).to_string()
  })
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
