///|
/// Runs one of the four positive/automatic operations through the public API.
fn[T : @atoi.Parse] positive_operation(
  data : BytesView,
  operation : String,
  skip_zeroes~ : Bool,
  skip_plus~ : Bool,
  simd~ : Bool,
) -> (T, Int32) raise @atoi.ParseError {
  match operation {
    "parse" => (@atoi.parse(data, skip_zeroes~, skip_plus~, simd~), 0)
    "pos" => (@atoi.parse_pos(data, skip_zeroes~, simd~), 0)
    "prefix" => @atoi.parse_prefix(data, skip_zeroes~, skip_plus~, simd~)
    "prefix_pos" => @atoi.parse_prefix_pos(data, skip_zeroes~, simd~)
    _ => abort("Unknown positive operation")
  }
}

///|
/// Adds the two sign-free negative operations for signed result types.
fn[T : @atoi.Parse + @atoi.ParseNeg] signed_operation(
  data : BytesView,
  operation : String,
  skip_zeroes~ : Bool,
  skip_plus~ : Bool,
  simd~ : Bool,
) -> (T, Int32) raise @atoi.ParseError {
  match operation {
    "neg" => (@atoi.parse_neg(data, skip_zeroes~, simd~), 0)
    "prefix_neg" => @atoi.parse_prefix_neg(data, skip_zeroes~, simd~)
    _ => positive_operation(data, operation, skip_zeroes~, skip_plus~, simd~)
  }
}

///|
/// Normalizes recoverable outcomes while retaining exact values and invalid offsets.
fn[T] normalized(
  action : () -> (T, Int32) raise @atoi.ParseError,
  show : (T) -> String,
  prefix~ : Bool,
) -> String {
  try action() catch {
    @atoi.Empty => "empty"
    @atoi.Size(_, _) => "size"
    @atoi.Overflow(_) => "overflow"
    @atoi.Invalid64(value, position, _) => "invalid:\{value}:\{position}"
    @atoi.Invalid128(value, position, _) =>
      "invalid:" + value.to_string() + ":" + position.to_string()
  } noraise {
    (value, consumed) =>
      if prefix {
        "ok:" + show(value) + ":" + consumed.to_string()
      } else {
        "ok:" + show(value)
      }
  }
}

///|
/// Selects a concrete public result type for cross-language fixture replay.
fn replay_case(
  kind : String,
  operation : String,
  input : BytesView,
  skip_zeroes~ : Bool,
  skip_plus~ : Bool,
  simd~ : Bool,
) -> String {
  let prefix = operation.has_prefix("prefix")
  match kind {
    "u8" =>
      normalized(
        () => {
          positive_operation(input, operation, skip_zeroes~, skip_plus~, simd~)
        },
        (value : Byte) => value.to_string(),
        prefix~,
      )
    "i8" =>
      normalized(
        () => {
          signed_operation(input, operation, skip_zeroes~, skip_plus~, simd~)
        },
        (value : @atoi.Int8) => value.to_string(),
        prefix~,
      )
    "u16" =>
      normalized(
        () => {
          positive_operation(input, operation, skip_zeroes~, skip_plus~, simd~)
        },
        (value : UInt16) => value.to_string(),
        prefix~,
      )
    "i16" =>
      normalized(
        () => {
          signed_operation(input, operation, skip_zeroes~, skip_plus~, simd~)
        },
        (value : Int16) => value.to_string(),
        prefix~,
      )
    "u32" =>
      normalized(
        () => {
          positive_operation(input, operation, skip_zeroes~, skip_plus~, simd~)
        },
        (value : UInt32) => value.to_string(),
        prefix~,
      )
    "i32" =>
      normalized(
        () => {
          signed_operation(input, operation, skip_zeroes~, skip_plus~, simd~)
        },
        (value : Int32) => value.to_string(),
        prefix~,
      )
    "u64" =>
      normalized(
        () => {
          positive_operation(input, operation, skip_zeroes~, skip_plus~, simd~)
        },
        (value : UInt64) => value.to_string(),
        prefix~,
      )
    "i64" =>
      normalized(
        () => {
          signed_operation(input, operation, skip_zeroes~, skip_plus~, simd~)
        },
        (value : Int64) => value.to_string(),
        prefix~,
      )
    "u128" =>
      normalized(
        () => {
          positive_operation(input, operation, skip_zeroes~, skip_plus~, simd~)
        },
        (value : @atoi.UInt128) => value.to_string(),
        prefix~,
      )
    "i128" =>
      normalized(
        () => {
          signed_operation(input, operation, skip_zeroes~, skip_plus~, simd~)
        },
        (value : @atoi.Int128) => value.to_string(),
        prefix~,
      )
    _ => abort("Unknown integer fixture type")
  }
}

///|
/// Implements a byte-wise BigInt oracle independent of all SWAR and SIMD logic.
fn decimal_reference(
  input : BytesView,
  positive_max : @bigint.BigInt,
  negative_max : @bigint.BigInt,
  budget : Int32,
  operation : String,
  skip_zeroes~ : Bool,
  skip_plus~ : Bool,
) -> String {
  let automatic = operation == "parse" || operation == "prefix"
  let negative = operation == "neg" ||
    operation == "prefix_neg" ||
    (automatic && negative_max != 0N && input.get(0) == Some(b'-'))
  let sign = if automatic &&
    (
      (negative_max != 0N && input.get(0) == Some(b'-')) ||
      (skip_plus && input.get(0) == Some(b'+'))
    ) {
    1
  } else {
    0
  }
  let mut end = sign
  while end < input.length() && input[end] >= b'0' && input[end] <= b'9' {
    end += 1
  }
  if end == sign {
    return "empty"
  }
  let mut significant_start = sign
  if skip_zeroes {
    while significant_start < end && input[significant_start] == b'0' {
      significant_start += 1
    }
  }
  if budget != 0 && end - significant_start > budget {
    return "size"
  }
  let mut magnitude = 0N
  for index in sign..<end {
    magnitude = magnitude * 10N +
      @bigint.BigInt::from_int(input[index].to_int() - 48)
  }
  if magnitude > (if negative { negative_max } else { positive_max }) {
    return "overflow"
  }
  let prefix = operation.has_prefix("prefix")
  if !prefix && end != input.length() {
    return "invalid:" + magnitude.to_string() + ":" + (end - sign).to_string()
  }
  let value = if negative { -magnitude } else { magnitude }
  if prefix {
    "ok:" + value.to_string() + ":" + end.to_string()
  } else {
    "ok:" + value.to_string()
  }
}

///|
test "scalar and vector public operations match an independent BigInt oracle" {
  let inputs : Array[Bytes] = [
    b"",
    b"+",
    b"-",
    b"-0",
    b"+0",
    b"0x12",
    b"12_3",
    b"12\xFF",
    Bytes::make(80, b'0') + b"42tail",
  ]
  let mut seed = 0xA701B16U
  for sample in 0..<64 {
    let digits = Bytes::makei(sample % 45, _ => {
      seed = seed * 1664525U + 1013904223U
      ((seed >> 16) % 10U + 48U).to_byte()
    })
    let sign = match sample % 4 {
      0 => b"-"
      1 => b"+"
      _ => b""
    }
    let suffix = match sample % 3 {
      0 => b"tail"
      1 => b"\xFF"
      _ => b""
    }
    inputs.push(sign + digits + suffix)
  }
  let configurations : Array[(String, @bigint.BigInt, @bigint.BigInt, Int32)] = [
    ("u8", 255N, 0N, 0),
    ("i8", 127N, 128N, 0),
    ("u16", 65535N, 0N, 0),
    ("i16", 32767N, 32768N, 0),
    ("u32", 4294967295N, 0N, 0),
    ("i32", 2147483647N, 2147483648N, 0),
    ("u64", 18446744073709551615N, 0N, 20),
    ("i64", 9223372036854775807N, 9223372036854775808N, 19),
    ("u128", 340282366920938463463374607431768211455N, 0N, 39),
    (
      "i128", 170141183460469231731687303715884105727N, 170141183460469231731687303715884105728N,
      39,
    ),
  ]
  for (kind, positive_max, negative_max, budget) in configurations {
    let operations = if negative_max == 0N {
      ["parse", "pos", "prefix", "prefix_pos"]
    } else {
      ["parse", "pos", "neg", "prefix", "prefix_pos", "prefix_neg"]
    }
    for input in inputs {
      for operation in operations {
        for skip_zeroes in [false, true] {
          for skip_plus in [false, true] {
            let expected = decimal_reference(
              input,
              positive_max,
              negative_max,
              budget,
              operation,
              skip_zeroes~,
              skip_plus~,
            )
            for simd in [false, true] {
              let actual = replay_case(
                kind,
                operation,
                input,
                skip_zeroes~,
                skip_plus~,
                simd~,
              )
              assert_eq(
                (kind, operation, input, actual),
                (kind, operation, input, expected),
              )
            }
          }
        }
      }
    }
  }
}

///|
test "pinned Rust baseline and SIMD fixtures retain portable overlapping behavior" {
  let vectors = upstream_vectors()
  assert_eq(vectors.length(), 2745)
  for (kind, operation, skip_zeroes, skip_plus, input, expected) in vectors {
    for simd in [false, true] {
      let actual = replay_case(
        kind,
        operation,
        input,
        skip_zeroes~,
        skip_plus~,
        simd~,
      )
      assert_eq(
        (kind, operation, input, actual),
        (kind, operation, input, expected),
      )
    }
  }
}
