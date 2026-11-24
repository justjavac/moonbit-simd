///|
test "moonbitstack WHATWG URL adapters match independent expected results" {
  let base = @moonurl.Url::decode(@cases.base_url(), syntax=@moonurl.Whatwg)
  @cases.verify(
    input => try! @moonurl.Url::decode(input, syntax=@moonurl.Whatwg),
    url => url.encode(),
    input => try! @moonurl.Url::decode(input, syntax=@moonurl.Whatwg, base~),
    input => (try! @moonurl.Query::decode(@utf8.encode(input))).encode(),
  )
}

///|
test "bench moonbitstack WHATWG absolute parsing" (bench : @bench.T) {
  @cases.absolute_bench(
    bench,
    "moonbitstack",
    input => try! @moonurl.Url::decode(input, syntax=@moonurl.Whatwg),
    url => url.encode(),
  )
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench moonbitstack WHATWG relative parsing" (bench : @bench.T) {
  let base = try! @moonurl.Url::decode(
    @cases.base_url(),
    syntax=@moonurl.Whatwg,
  )
  @cases.relative_bench(
    bench,
    "moonbitstack",
    input => try! @moonurl.Url::decode(input, syntax=@moonurl.Whatwg, base~),
    url => url.encode(),
  )
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
test "bench moonbitstack form query" (bench : @bench.T) {
  @cases.form_bench(bench, "moonbitstack", input => {
    (try! @moonurl.Query::decode(@utf8.encode(input))).encode()
  })
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
