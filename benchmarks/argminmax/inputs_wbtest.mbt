///|
/// Specifies one deterministic extrema workload independently of its adapter.
struct Input {
  kind : String
  label : String
  length : Int32
  offset : Int32
  operation : String
  pattern : String
}

///|
/// Returns the numeric byte width rather than the size of wrapper objects.
fn byte_width(kind : String) -> Int32 {
  match kind {
    "u8" | "i8" => 1
    "u16" | "i16" | "f16" | "bf16" => 2
    "u32" | "i32" | "f32" => 4
    "u64" | "i64" | "f64" => 8
    "u128" | "i128" => 16
    _ => abort("Unknown extrema element kind")
  }
}

///|
/// Defines 54 workloads and their exact element counts, operations, and offsets.
fn inputs() -> Array[Input] {
  let output : Array[Input] = []
  for
    kind in [
      "u8", "i8", "u16", "i16", "u32", "i32", "u64", "i64", "f32", "f64", "f16",
      "bf16", "u128", "i128",
    ] {
    for length in [33, 4096] {
      output.push({
        kind,
        label: "argminmax-" + kind,
        length,
        offset: 0,
        operation: "both",
        pattern: "random",
      })
    }
  }
  for kind in ["i32", "f64"] {
    output.push({
      kind,
      label: "argminmax-" + kind,
      length: 0,
      offset: 0,
      operation: "both",
      pattern: "random",
    })
    for (length, offset) in [(4096, 1), (1048576, 0), (1048576, 1)] {
      output.push({
        kind,
        label: "argminmax-" + kind,
        length,
        offset,
        operation: "both",
        pattern: "random",
      })
    }
    for operation in ["min", "max"] {
      output.push({
        kind,
        label: "arg" + operation + "-" + kind,
        length: 4096,
        offset: 0,
        operation,
        pattern: "random",
      })
    }
  }
  for kind in ["f32", "f64"] {
    for pattern in ["first", "last"] {
      for operation in ["both", "nan"] {
        let prefix = if operation == "nan" { "propagate" } else { "ignore" }
        output.push({
          kind,
          label: prefix + "-nan-" + pattern + "-" + kind,
          length: 4096,
          offset: 0,
          operation,
          pattern,
        })
      }
    }
  }
  for pattern in ["dense", "sparse", "all-null", "nan-null"] {
    output.push({
      kind: "f64",
      label: "masked-" + pattern + "-f64",
      length: 4096,
      offset: 0,
      operation: if pattern == "nan-null" {
        "nan"
      } else {
        "both"
      },
      pattern,
    })
  }
  for kind in ["u8", "u16"] {
    output.push({
      kind,
      label: "index-boundary-" + kind,
      length: 131105,
      offset: 0,
      operation: "both",
      pattern: "boundary",
    })
  }
  output
}

///|
/// Creates reproducible full-width words and sentinel storage outside timed calls.
fn raw_values(input : Input) -> FixedArray[UInt64] {
  let mut seed = 0xC91A27B63ED5408FUL
  let values = FixedArray::makei(input.length + input.offset + 2, _ => {
    seed = seed ^ (seed << 13)
    seed = seed ^ (seed >> 7)
    seed = seed ^ (seed << 17)
    seed
  })
  if input.pattern == "boundary" {
    values.fill(42UL)
    values[input.offset + 65536] = 0UL
    values[input.offset + input.length - 1] = 0xffffffffffffffffUL
  }
  values
}

///|
/// Prepares a scalar floating corpus with NaNs placed outside and inside its view.
fn double_values(input : Input, raw : FixedArray[UInt64]) -> FixedArray[Double] {
  let values = raw.map(word => {
    (word >> 32).to_uint().reinterpret_as_int().to_double() / 64.0
  })
  if input.offset > 0 {
    values[0] = @double.not_a_number
  }
  values[input.offset + input.length] = @double.not_a_number
  if input.pattern == "first" {
    values[input.offset] = @double.not_a_number
  }
  if input.pattern == "last" {
    values[input.offset + input.length - 1] = @double.not_a_number
  }
  if input.pattern == "nan-null" {
    values[input.offset] = @double.not_a_number
    values[input.offset + 2048] = 0xfff0000000000001UL.reinterpret_as_double()
  }
  values
}

///|
/// Prepares an offset-three Arrow bitmap with dense, sparse, or absent validity.
fn bitmap(input : Input) -> Bytes? {
  if !input.label.has_prefix("masked-") {
    return None
  }
  let bits = FixedArray::make((input.length + 3 + 7) / 8, b'\x00')
  for i in 0..<input.length {
    let valid = match input.pattern {
      "all-null" => false
      "sparse" => i % 2 == 0
      "dense" => i != 1023 && i != 3071
      "nan-null" => i != 0
      _ => abort("Unknown validity pattern")
    }
    if valid {
      let position = 3 + i
      bits[position / 8] = (bits[position / 8].to_int() | (1 << (position % 8))).to_byte()
    }
  }
  Some(Bytes::from_array(bits))
}
