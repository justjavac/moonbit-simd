///|
/// Measures one prepared public adapter result without serializing its value.
fn[T] measure(
  bench : @bench.T,
  name : String,
  parse : () -> (T, Int32)?,
) -> Unit {
  bench.bench(name~, () => bench.keep(parse()))
}

///|
test "bench decimal full and prefix public operations" (bench : @bench.T) {
  for input in inputs() {
    for (view, offset) in views(input) {
      for (label, simd) in [("own-scalar", false), ("own-simd", true)] {
        let name = "\{input.label}:\{label}:\{view.length()}:\{offset}"
        match input.kind {
          "u32" =>
            measure(bench, name, () => {
              (own(input, view, simd~) : (UInt32, Int32)?)
            })
          "u64" =>
            measure(bench, name, () => {
              (own(input, view, simd~) : (UInt64, Int32)?)
            })
          "i64" =>
            measure(bench, name, () => {
              (own(input, view, simd~) : (Int64, Int32)?)
            })
          "u128" =>
            measure(bench, name, () => {
              (own(input, view, simd~) : (@ours.UInt128, Int32)?)
            })
          "i128" =>
            measure(bench, name, () => {
              (own(input, view, simd~) : (@ours.Int128, Int32)?)
            })
          _ => abort("Unknown integer kind")
        }
      }
      if input.compare_core {
        let name = "\{input.label}:core:\{view.length()}:\{offset}"
        match input.kind {
          "u32" => measure(bench, name, () => core_u32(input, view))
          "u64" => measure(bench, name, () => core_u64(input, view))
          "i64" => measure(bench, name, () => core_i64(input, view))
          "u128" | "i128" => measure(bench, name, () => core_wide(input, view))
          _ => abort("Unknown integer kind")
        }
      }
    }
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
