///|
test "prepared public adapters match independent extrema results" {
  assert_eq(inputs().length(), 54)
  let names : Map[String, Unit] = Map([])
  for input in inputs() {
    let name = input.label +
      ":" +
      (input.length * byte_width(input.kind)).to_string() +
      ":" +
      input.offset.to_string()
    assert_true(!names.contains(name))
    names[name] = ()
    run_input(None, input)
  }
}

///|
test "bench extrema indices numeric views NaNs and bitmaps" (bench : @bench.T) {
  for input in inputs() {
    run_input(Some(bench), input)
  }
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}

///|
/// Measures scalar/vector dispatch in both orders over the same input and process.
fn[T : @ours.Element] calibrate(
  bench : @bench.T,
  input : Input,
  data : ArrayView[T],
) -> Unit {
  let scalar = own_adapter(input, data, None, false)
  let vector = own_adapter(input, data, None, true)
  for
    (order, calls) in [
      ("forward", [("scalar", scalar), ("simd", vector)]),
      ("reverse", [("simd", vector), ("scalar", scalar)]),
    ] {
    for (label, call) in calls {
      let name = input.kind +
        ":" +
        label +
        "-" +
        order +
        ":" +
        input.length.to_string() +
        ":0"
      bench.bench(name~, () => bench.keep(call()))
    }
  }
}

///|
test "bench dispatch calibration" (bench : @bench.T) {
  // An explicit local probe; the normal CI inventory remains 162 cases.
  if @env.get_env_var("ARGMINMAX_CALIBRATE") != Some("1") {
    return
  }
  for kind in ["u8", "i32", "f32", "f64"] {
    for length in [33, 4096] {
      let input : Input = {
        kind,
        label: "calibrate",
        length,
        offset: 0,
        operation: "both",
        pattern: "random",
      }
      let raw = raw_values(input)
      match kind {
        "u8" =>
          calibrate(bench, input, raw.map(word => word.to_byte())[0:length])
        "i32" =>
          calibrate(
            bench,
            input,
            raw.map(word => word.to_uint().reinterpret_as_int())[0:length],
          )
        "f32" =>
          calibrate(
            bench,
            input,
            double_values(input, raw).map(value => Float::from_double(value))[0:length],
          )
        "f64" => calibrate(bench, input, double_values(input, raw)[0:length])
        _ => abort("Unknown calibration kind")
      }
    }
  }
  println("CALIBRATION_RESULTS " + bench.dump_summaries())
}
