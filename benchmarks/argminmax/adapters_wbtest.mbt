///|
/// Computes a separate linear reference using numeric equality to classify NaNs.
fn[T : Compare] reference(
  data : ArrayView[T],
  minimum~ : Bool = true,
  maximum~ : Bool = true,
  propagate~ : Bool = false,
  validity~ : BytesView? = None,
) -> (Int32, Int32)? {
  let mut first = -1
  let mut start = -1
  for i in 0..<data.length() {
    if validity is Some(bits) &&
      (bits[(3 + i) / 8].to_int() & (1 << ((3 + i) % 8))) == 0 {
      continue
    }
    if first < 0 {
      first = i
    }
    if data[i] != data[i] {
      if propagate {
        return Some((i, i))
      }
      continue
    }
    start = i
    break
  }
  guard start >= 0 else {
    return if first >= 0 { Some((first, first)) } else { None }
  }
  let mut low = start
  let mut high = start
  let mut low_value = data[start]
  let mut high_value = low_value
  for i in (start + 1)..<data.length() {
    if validity is Some(bits) &&
      (bits[(3 + i) / 8].to_int() & (1 << ((3 + i) % 8))) == 0 {
      continue
    }
    let value = data[i]
    if value != value {
      if propagate {
        return Some((i, i))
      }
      continue
    }
    if minimum && value < low_value {
      low = i
      low_value = value
    }
    if maximum && value > high_value {
      high = i
      high_value = value
    }
  }
  Some((low, high))
}

///|
/// Selects one public operation before timing, keeping bitmap validation inside it.
fn[T : @ours.Element] own_adapter(
  input : Input,
  data : ArrayView[T],
  validity : Bytes?,
  simd : Bool,
) -> () -> (Int32, Int32)? {
  match (input.operation, validity) {
    ("both", None) => () => @ours.argminmax(data, simd~)
    ("min", None) => () => @ours.argmin(data, simd~).map(i => (i, i))
    ("max", None) => () => @ours.argmax(data, simd~).map(i => (i, i))
    ("nan", None) => () => @ours.nanargminmax(data, simd~)
    ("both", Some(bits)) =>
      () => try! @ours.argminmax_masked(data, bits, offset=3, simd~)
    ("nan", Some(bits)) =>
      () => try! @ours.nanargminmax_masked(data, bits, offset=3, simd~)
    _ => abort("Unknown extrema operation")
  }
}

///|
/// Selects an equivalent reference operation without calling this library's scanner.
fn[T : Compare] baseline_adapter(
  input : Input,
  data : ArrayView[T],
  validity : Bytes?,
) -> () -> (Int32, Int32)? {
  let bits = validity.map(value => value[:])
  match input.operation {
    "both" => () => reference(data, validity=bits)
    "min" =>
      () => {
        reference(data, minimum=true, maximum=false, validity=bits).map(pair => {
          (pair.0, pair.0)
        })
      }
    "max" =>
      () => {
        reference(data, minimum=false, maximum=true, validity=bits).map(pair => {
          (pair.1, pair.1)
        })
      }
    "nan" => () => reference(data, propagate=true, validity=bits)
    _ => abort("Unknown reference operation")
  }
}

///|
/// Validates equivalent results and times three adapters over identical prepared values.
fn[T : @ours.Element] exercise(
  bench : @bench.T?,
  input : Input,
  data : ArrayView[T],
) -> Unit raise {
  let validity = bitmap(input)
  let baseline = baseline_adapter(input, data, validity)
  let scalar = own_adapter(input, data, validity, false)
  let vector = own_adapter(input, data, validity, true)
  let expected = baseline()
  assert_eq(scalar(), expected)
  assert_eq(vector(), expected)
  if bench is Some(runner) {
    for
      (label, call) in [
        ("own-scalar", scalar),
        ("own-simd", vector),
        ("baseline", baseline),
      ] {
      let name = input.label +
        ":" +
        label +
        ":" +
        (input.length * byte_width(input.kind)).to_string() +
        ":" +
        input.offset.to_string()
      runner.bench(name~, () => runner.keep(call()))
    }
  }
}

///|
/// Prepares each numeric representation outside validation and timed callbacks.
fn run_input(bench : @bench.T?, input : Input) -> Unit raise {
  let raw = raw_values(input)
  let start = input.offset
  let end = start + input.length
  match input.kind {
    "u8" => exercise(bench, input, raw.map(word => word.to_byte())[start:end])
    "i8" =>
      exercise(
        bench,
        input,
        raw.map(word => @ours.Int8::from_bits(word.to_byte()))[start:end],
      )
    "u16" =>
      exercise(bench, input, raw.map(word => word.to_uint16())[start:end])
    "i16" =>
      exercise(
        bench,
        input,
        raw.map(word => Int16::reinterpret_from_uint16(word.to_uint16()))[start:end],
      )
    "u32" => exercise(bench, input, raw.map(word => word.to_uint())[start:end])
    "i32" =>
      exercise(
        bench,
        input,
        raw.map(word => word.to_uint().reinterpret_as_int())[start:end],
      )
    "u64" => exercise(bench, input, raw[start:end])
    "i64" =>
      exercise(
        bench,
        input,
        raw.map(word => word.reinterpret_as_int64())[start:end],
      )
    "f32" =>
      exercise(
        bench,
        input,
        double_values(input, raw).map(value => Float::from_double(value))[start:end],
      )
    "f64" => exercise(bench, input, double_values(input, raw)[start:end])
    "f16" =>
      exercise(
        bench,
        input,
        raw.map(word => @ours.Float16::from_bits(word.to_uint16()))[start:end],
      )
    "bf16" =>
      exercise(
        bench,
        input,
        raw.map(word => @ours.BFloat16::from_bits(word.to_uint16()))[start:end],
      )
    "u128" =>
      exercise(
        bench,
        input,
        raw.map(word => {
          @ours.UInt128::from_words(high=word, low=word ^ 0x8000000000000000UL)
        })[start:end],
      )
    "i128" =>
      exercise(
        bench,
        input,
        raw.map(word => {
          @ours.Int128::from_words(
            high=word.reinterpret_as_int64(),
            low=word ^ 0x8000000000000000UL,
          )
        })[start:end],
      )
    _ => abort("Unknown extrema input kind")
  }
}
