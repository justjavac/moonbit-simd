///|
test "bench UTF-16 operations against bundled core" (bench : @bench.T) {
  let units = unit_text()
  let fields = fields_text()
  let (left, right) = equal_views()
  let inputs = searches()
  for
    implementation in (if @env.get_env_var("STRING_BENCHMARK_REVERSE") ==
      Some("1") {
      ["core", "ours"]
    } else {
      ["ours", "core"]
    }) {
    let ours = implementation == "ours"
    for input in inputs {
      let name = "\{input.label}:\{implementation}:\{input.text.length()}:\{input.offset}"
      let search : (StringView, StringView) -> Int32? = match
        (ours, input.reverse) {
        (true, false) => @ours.find
        (true, true) => @ours.rev_find
        (false, false) => StringView::find
        (false, true) => StringView::rev_find
      }
      bench.bench(name~, () => bench.keep(search(input.text, input.needle)))
    }
    let find_unit = if ours {
      @ours.find_code_unit
    } else {
      StringView::find_code_unit
    }
    let rev_find_unit = if ours {
      @ours.rev_find_code_unit
    } else {
      StringView::rev_find_code_unit
    }
    bench.bench(name="find-unit-late:\{implementation}:4096:1", () => {
      bench.keep(find_unit(units, 0x4E2D))
    })
    bench.bench(name="rev-find-unit-miss:\{implementation}:4096:1", () => {
      bench.keep(rev_find_unit(units, 0x0078))
    })
    let equal = if ours { @ours.equal } else { StringView::equal }
    bench.bench(name="equal-long:\{implementation}:65536:1", () => {
      bench.keep(equal(left, right))
    })
    let split = if ours { @ours.split } else { StringView::split }
    bench.bench(name="split-sparse:\{implementation}:4096:1", () => {
      for field in split(fields, "::") {
        bench.keep(field)
      }
    })
    bench.bench(name="replace-all-sparse:\{implementation}:4096:1", () => {
      let result = if ours {
        @ours.replace_all(fields, old="::", new="|")
      } else {
        fields.replace_all(old="::", new="|")
      }
      bench.keep(result)
    })
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
