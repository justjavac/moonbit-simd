///|
/// Describes a prepared decimal workload and its exact public result contract.
priv struct Input {
  label : String
  kind : String
  data : Bytes
  prefix : Bool
  skip_zeroes : Bool
  skip_plus : Bool
  expected : String?
  consumed : Int32
  partial : Bool
  compare_core : Bool
}

///|
/// Builds an ordinary full or prefix workload outside timed callbacks.
fn input(
  label : String,
  kind : String,
  data : Bytes,
  expected : String?,
  prefix~ : Bool = false,
  consumed~ : Int32 = 0,
  skip_zeroes~ : Bool = false,
  skip_plus~ : Bool = false,
  partial~ : Bool = false,
  compare_core~ : Bool = true,
) -> Input {
  {
    label,
    kind,
    data,
    expected,
    prefix,
    consumed: if prefix {
      consumed
    } else {
      data.length()
    },
    skip_zeroes,
    skip_plus,
    partial,
    compare_core,
  }
}

///|
/// Supplies canonical decimal inputs, prefixes, limits, long zeroes, and failures.
fn inputs() -> Array[Input] {
  [
    input("parse-u32-short", "u32", b"7", Some("7")),
    input("parse-u32-max", "u32", b"4294967295", Some("4294967295")),
    input("parse-u64-short", "u64", b"7", Some("7")),
    input("parse-u64-eight", "u64", b"12345678", Some("12345678")),
    input(
      "parse-u64-sixteen",
      "u64",
      b"1234567890123456",
      Some("1234567890123456"),
      partial=true,
    ),
    input(
      "parse-u64-max",
      "u64",
      b"18446744073709551615",
      Some("18446744073709551615"),
      partial=true,
    ),
    input("parse-i64-short", "i64", b"-7", Some("-7")),
    input(
      "parse-i64-sixteen",
      "i64",
      b"-1234567890123456",
      Some("-1234567890123456"),
      partial=true,
    ),
    input(
      "parse-i64-max",
      "i64",
      b"9223372036854775807",
      Some("9223372036854775807"),
    ),
    input(
      "parse-i64-min",
      "i64",
      b"-9223372036854775808",
      Some("-9223372036854775808"),
      partial=true,
    ),
    input(
      "parse-u128-sixteen",
      "u128",
      b"1234567890123456",
      Some("1234567890123456"),
    ),
    input(
      "parse-u128-thirtytwo",
      "u128",
      b"12345678901234567890123456789012",
      Some("12345678901234567890123456789012"),
      partial=true,
    ),
    input(
      "parse-u128-max",
      "u128",
      b"340282366920938463463374607431768211455",
      Some("340282366920938463463374607431768211455"),
      partial=true,
    ),
    input("parse-i128-short", "i128", b"-7", Some("-7")),
    input(
      "parse-i128-thirtytwo",
      "i128",
      b"-12345678901234567890123456789012",
      Some("-12345678901234567890123456789012"),
      partial=true,
    ),
    input(
      "parse-i128-min",
      "i128",
      b"-170141183460469231731687303715884105728",
      Some("-170141183460469231731687303715884105728"),
      partial=true,
    ),
    input(
      "parse-u64-plus-zeroes",
      "u64",
      b"+" + Bytes::make(80, b'0') + b"42",
      Some("42"),
      skip_zeroes=true,
      skip_plus=true,
    ),
    input(
      "parse-i128-plus-zeroes",
      "i128",
      b"+" + Bytes::make(80, b'0') + b"42",
      Some("42"),
      skip_zeroes=true,
      skip_plus=true,
    ),
    input(
      "parse-u64-zeroes-4k",
      "u64",
      Bytes::make(4096, b'0'),
      Some("0"),
      skip_zeroes=true,
    ),
    input(
      "parse-u64-zeroes-1m",
      "u64",
      Bytes::make(1048576, b'0'),
      Some("0"),
      skip_zeroes=true,
    ),
    input(
      "prefix-u64-sixteen",
      "u64",
      b"1234567890123456,rest",
      Some("1234567890123456"),
      prefix=true,
      consumed=16,
      partial=true,
    ),
    input(
      "prefix-i64-min",
      "i64",
      b"-9223372036854775808,rest",
      Some("-9223372036854775808"),
      prefix=true,
      consumed=20,
    ),
    input(
      "prefix-u128-max",
      "u128",
      b"340282366920938463463374607431768211455,rest",
      Some("340282366920938463463374607431768211455"),
      prefix=true,
      consumed=39,
    ),
    input(
      "prefix-i128-min",
      "i128",
      b"-170141183460469231731687303715884105728,rest",
      Some("-170141183460469231731687303715884105728"),
      prefix=true,
      consumed=40,
    ),
    input("invalid-u64-empty", "u64", b"", None),
    input("invalid-u64-start", "u64", b"x123", None),
    input("invalid-u64-end", "u64", b"1234567890123456x", None),
    input("invalid-u64-byte", "u64", b"1234567890123456\xFF", None),
    input("overflow-u64", "u64", b"18446744073709551616", None),
    input("overflow-u32-large", "u32", Bytes::make(65536, b'9'), None),
    input(
      "overflow-u128",
      "u128",
      b"340282366920938463463374607431768211456",
      None,
    ),
    input("size-u64", "u64", Bytes::make(64, b'9'), None, compare_core=false),
  ]
}

///|
/// Adds rejected sentinels around selected partial views without timing construction.
fn views(input : Input) -> Array[(BytesView, Int32)] {
  let result = [(input.data[:], 0)]
  if input.partial {
    for offset in [1, 3, 15] {
      let backing = Bytes::make(offset, b'\xFF') + input.data + b"\xFF"
      result.push((backing[offset:offset + input.data.length()], offset))
    }
  }
  result
}

///|
/// Calls this library's full or prefix API, normalizing recoverable failures.
fn[T : @ours.Parse] own(
  input : Input,
  view : BytesView,
  simd~ : Bool,
) -> (T, Int32)? {
  try {
    if input.prefix {
      @ours.parse_prefix(
        view,
        skip_zeroes=input.skip_zeroes,
        skip_plus=input.skip_plus,
        simd~,
      )
    } else {
      (
        @ours.parse(
          view,
          skip_zeroes=input.skip_zeroes,
          skip_plus=input.skip_plus,
          simd~,
        ),
        view.length(),
      )
    }
  } catch {
    _ => None
  } noraise {
    result => Some(result)
  }
}

///|
/// Supplies the missing prefix API with a bounded per-byte decimal scan.
fn prefix_end(view : BytesView) -> Int32 {
  let sign = if view.get(0) == Some(b'+') || view.get(0) == Some(b'-') {
    1
  } else {
    0
  }
  for index = sign
      index < view.length() && view[index] >= b'0' && view[index] <= b'9'
      index = index + 1 {

  } nobreak {
    index
  }
}

///|
/// Converts a measured full input or digit prefix to UTF-16 for core parsers.
fn core_text(input : Input, view : BytesView) -> (String, Int32) raise {
  let end = if input.prefix { prefix_end(view) } else { view.length() }
  let start = if input.skip_plus && view.get(0) == Some(b'+') { 1 } else { 0 }
  (@utf8.decode(view[start:end], ignore_bom=false), end)
}

///|
/// Parses an equivalent unsigned 64-bit core result with UTF-8 conversion timed.
fn core_u64(input : Input, view : BytesView) -> (UInt64, Int32)? {
  try {
    let (text, consumed) = core_text(input, view)
    (@string.parse_uint64(text, radix=10), consumed)
  } catch {
    _ => None
  } noraise {
    result => Some(result)
  }
}

///|
/// Adds the required 32-bit range validation to the core unsigned parser.
fn core_u32(input : Input, view : BytesView) -> (UInt32, Int32)? {
  match core_u64(input, view) {
    Some((value, consumed)) if value <= 4294967295UL =>
      Some((value.to_uint(), consumed))
    _ => None
  }
}

///|
/// Parses an equivalent signed 64-bit core result with UTF-8 conversion timed.
fn core_i64(input : Input, view : BytesView) -> (Int64, Int32)? {
  try {
    let (text, consumed) = core_text(input, view)
    (@string.parse_int64(text, radix=10), consumed)
  } catch {
    _ => None
  } noraise {
    result => Some(result)
  }
}

///|
/// Stores immutable wide-range bounds outside measured adapter calls.
let wide_signed_minimum : @bigint.BigInt = -170141183460469231731687303715884105728N

///|
/// Stores the signed wide maximum once for measured core range checks.
let wide_signed_maximum : @bigint.BigInt = 170141183460469231731687303715884105727N

///|
/// Stores the unsigned wide maximum once for measured core range checks.
let wide_unsigned_maximum : @bigint.BigInt = 340282366920938463463374607431768211455N

///|
/// Stores the unsigned wide lower bound once for measured core range checks.
let wide_unsigned_minimum : @bigint.BigInt = 0N

///|
/// Adapts core BigInt to the same signed or unsigned 128-bit range inside timing.
fn core_wide(input : Input, view : BytesView) -> (@bigint.BigInt, Int32)? {
  try {
    let (text, consumed) = core_text(input, view)
    let value = @string.parse_bigint(text, radix=10)
    let (minimum, maximum) = if input.kind == "i128" {
      (wide_signed_minimum, wide_signed_maximum)
    } else {
      (wide_unsigned_minimum, wide_unsigned_maximum)
    }
    if value < minimum || value > maximum {
      None
    } else {
      Some((value, consumed))
    }
  } catch {
    _ => None
  }
}

///|
/// Serializes adapter values only during equivalence tests, outside benchmark timers.
fn[T] display(result : (T, Int32)?, show : (T) -> String) -> String? {
  result.map(pair => show(pair.0) + ":" + pair.1.to_string())
}

///|
/// Checks the exact integer and consumed bytes for one public adapter result.
fn[T] verify(
  input : Input,
  result : (T, Int32)?,
  show : (T) -> String,
) -> Unit raise {
  let expected = input.expected.map(value => {
    value + ":" + input.consumed.to_string()
  })
  assert_eq((input.label, display(result, show)), (input.label, expected))
}

///|
test "integer comparison adapters return identical values and prefix boundaries" {
  let mut cases = 0
  for input in inputs() {
    for (view, _) in views(input) {
      for simd in [false, true] {
        match input.kind {
          "u32" =>
            verify(input, own(input, view, simd~), (value : UInt32) => {
              value.to_string()
            })
          "u64" =>
            verify(input, own(input, view, simd~), (value : UInt64) => {
              value.to_string()
            })
          "i64" =>
            verify(input, own(input, view, simd~), (value : Int64) => {
              value.to_string()
            })
          "u128" =>
            verify(input, own(input, view, simd~), (value : @ours.UInt128) => {
              value.to_string()
            })
          "i128" =>
            verify(input, own(input, view, simd~), (value : @ours.Int128) => {
              value.to_string()
            })
          _ => fail("Unknown integer kind")
        }
        cases += 1
      }
      if input.compare_core {
        match input.kind {
          "u32" =>
            verify(input, core_u32(input, view), value => value.to_string())
          "u64" =>
            verify(input, core_u64(input, view), value => value.to_string())
          "i64" =>
            verify(input, core_i64(input, view), value => value.to_string())
          "u128" | "i128" =>
            verify(input, core_wide(input, view), value => value.to_string())
          _ => fail("Unknown integer kind")
        }
        cases += 1
      }
    }
  }
  assert_eq(cases, 176)
}
