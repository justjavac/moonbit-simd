///|
test "bench public Ryu formatting and decimal parsing" (bench : @bench.T) {
  for input in format_cases() {
    let bytes = if input.kind == "float" { 4 } else { 8 }
    let own_name = "\{input.label}:own:\{bytes}:0"
    let core_name = "\{input.label}:core:\{bytes}:0"
    match input.kind {
      "double" => {
        bench.bench(name=own_name, () => bench.keep(@ours.d2s(input.value)))
        bench.bench(name=core_name, () => bench.keep(core_double(input.value)))
      }
      "float" => {
        let value = Float::from_double(input.value)
        bench.bench(name=own_name, () => bench.keep(@ours.f2s(value)))
        bench.bench(name=core_name, () => bench.keep(core_float(value)))
      }
      "fixed" =>
        bench.bench(name=own_name, () => {
          bench.keep(try! @ours.d2fixed(input.value, precision=input.precision))
        })
      "exp" =>
        bench.bench(name=own_name, () => {
          bench.keep(try! @ours.d2exp(input.value, precision=input.precision))
        })
      _ => abort("Unknown formatting operation")
    }
  }
  for input in parse_cases() {
    for (view, offset) in parse_views(input) {
      let own_name = "\{input.label}:own:\{view.length()}:\{offset}"
      let core_name = "\{input.label}:core:\{view.length()}:\{offset}"
      bench.bench(name=own_name, () => bench.keep(own_parse(input, view)))
      bench.bench(name=core_name, () => bench.keep(core_parse(input, view)))
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
