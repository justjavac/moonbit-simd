///|
/// Defines a prepared scalar formatting input and exact precision workload.
priv struct FormatCase {
  label : String
  kind : String
  value : Double
  precision : Int32
}

///|
/// Defines a prepared ASCII parse input and its independently specified IEEE bits.
priv struct ParseCase {
  label : String
  kind : String
  text : String
  bits : UInt64?
  partial : Bool
}

///|
/// Builds deterministic shortest and Printf scalar cases outside timed callbacks.
fn format_cases() -> Array[FormatCase] {
  let cases : Array[FormatCase] = []
  for
    (label, kind, value) in [
      ("d2s-zero", "double", -0.0),
      ("d2s-short", "double", 0.3),
      ("d2s-pi", "double", 3.141592653589793),
      ("d2s-smallint", "double", 123456789.0),
      ("d2s-subnormal", "double", 1UL.reinterpret_as_double()),
      ("d2s-max", "double", 0x7FEFFFFFFFFFFFFFUL.reinterpret_as_double()),
      ("d2s-small", "double", 1.0e-100),
      ("d2s-large", "double", 1.0e100),
      ("f2s-zero", "float", -0.0),
      ("f2s-short", "float", 0.3),
      ("f2s-pi", "float", 3.1415927),
      ("f2s-subnormal", "float", Float::reinterpret_from_uint(1U).to_double()),
      (
        "f2s-max",
        "float",
        Float::reinterpret_from_uint(0x7F7FFFFFU).to_double(),
      ),
    ] {
    cases.push({ label, kind, value, precision: 0, })
  }
  for kind in ["fixed", "exp"] {
    for precision in [0, 6, 17, 100, 1000] {
      cases.push({
        label: "\{kind}-short-\{precision}",
        kind,
        value: 1.25,
        precision,
      })
    }
  }
  for
    (label, kind, value, precision) in [
      ("fixed-subnormal-324", "fixed", 1UL.reinterpret_as_double(), 324),
      ("fixed-subnormal-1074", "fixed", 1UL.reinterpret_as_double(), 1074),
      ("fixed-large-0", "fixed", 1.0e100, 0),
      ("fixed-large-6", "fixed", 1.0e100, 6),
      ("fixed-carry-2", "fixed", 9.999, 2),
      ("exp-subnormal-6", "exp", 1UL.reinterpret_as_double(), 6),
      ("exp-subnormal-324", "exp", 1UL.reinterpret_as_double(), 324),
      ("exp-large-6", "exp", 1.0e100, 6),
      ("exp-carry-1", "exp", 9.99, 1),
    ] {
    cases.push({ label, kind, value, precision, })
  }
  cases
}

///|
/// Prepares long leading-zero text without timing construction.
fn zero_prefix(text : String) -> String {
  let builder = StringBuilder()
  for _ in 0..<64 {
    builder.write_char('0')
  }
  builder.write_string(text)
  builder.to_string()
}

///|
/// Defines common parser grammar cases and exact expected Float/Double results.
fn parse_cases() -> Array[ParseCase] {
  [
    {
      label: "s2d-short",
      kind: "double",
      text: "3.141592653589793",
      bits: Some(0x400921FB54442D18UL),
      partial: false,
    },
    {
      label: "s2d-integer",
      kind: "double",
      text: "9007199254740993",
      bits: Some(0x4340000000000000UL),
      partial: false,
    },
    {
      label: "s2d-subnormal",
      kind: "double",
      text: "4.9406564584124654e-324",
      bits: Some(1UL),
      partial: false,
    },
    {
      label: "s2d-max",
      kind: "double",
      text: "1.7976931348623157e308",
      bits: Some(0x7FEFFFFFFFFFFFFFUL),
      partial: false,
    },
    {
      label: "s2d-offset",
      kind: "double",
      text: "1.25e2",
      bits: Some(0x405F400000000000UL),
      partial: true,
    },
    {
      label: "s2d-invalid",
      kind: "double",
      text: "1..2",
      bits: None,
      partial: false,
    },
    {
      label: "s2d-zeroes",
      kind: "double",
      text: zero_prefix("3.141592653589793"),
      bits: Some(0x400921FB54442D18UL),
      partial: false,
    },
    {
      label: "s2f-short",
      kind: "float",
      text: "3.1415927",
      bits: Some(0x40490FDBUL),
      partial: false,
    },
    {
      label: "s2f-integer",
      kind: "float",
      text: "16777217",
      bits: Some(0x4B800000UL),
      partial: false,
    },
    {
      label: "s2f-subnormal",
      kind: "float",
      text: "1.40129846e-45",
      bits: Some(1UL),
      partial: false,
    },
    {
      label: "s2f-max",
      kind: "float",
      text: "3.40282347e38",
      bits: Some(0x7F7FFFFFUL),
      partial: false,
    },
    {
      label: "s2f-offset",
      kind: "float",
      text: "1.25e2",
      bits: Some(0x42FA0000UL),
      partial: true,
    },
    {
      label: "s2f-invalid",
      kind: "float",
      text: "1..2",
      bits: None,
      partial: false,
    },
    {
      label: "s2f-zeroes",
      kind: "float",
      text: zero_prefix("3.1415927"),
      bits: Some(0x40490FDBUL),
      partial: false,
    },
  ]
}

///|
/// Produces actual partial StringViews with rejected characters outside their bounds.
fn parse_views(input : ParseCase) -> Array[(StringView, Int32)] {
  let result = [(input.text[:], 0)]
  if input.partial {
    for offset in [1, 3, 15] {
      let builder = StringBuilder()
      for _ in 0..<offset {
        builder.write_char('!')
      }
      builder.write_string(input.text)
      builder.write_char('?')
      let owned = builder.to_string()
      result.push((owned[offset:offset + input.text.length()], offset))
    }
  }
  result
}

///|
/// Converts core's shortest layout to the exact uppercase Ryu representation.
fn canonical_shortest(text : String, negative_zero : Bool) -> String {
  if text == "NaN" || text == "Infinity" || text == "-Infinity" {
    return text
  }
  let negative = text.has_prefix("-")
  let source = if negative { text[1:].to_owned() } else { text }
  let exponent_start = source.find("e").unwrap_or(source.length())
  let decimal = source[:exponent_start].to_owned()
  let point = decimal.find(".").unwrap_or(decimal.length())
  let digits = decimal.replace(old=".", new="")
  let mut first = 0
  while first < digits.length() && digits[first] == '0' {
    first += 1
  }
  if first == digits.length() {
    return if negative_zero { "-0E0" } else { "0E0" }
  }
  let mut end = digits.length()
  while end > first + 1 && digits[end - 1] == '0' {
    end -= 1
  }
  let mut power = 0
  if exponent_start < source.length() {
    let exponent = source[exponent_start + 1:]
    let signed = exponent[0] == '-'
    let start = if exponent[0] == '+' || signed { 1 } else { 0 }
    for i in start..<exponent.length() {
      power = power * 10 + exponent[i].to_int() - 48
    }
    if signed {
      power = -power
    }
  }
  let builder = StringBuilder(capacity=25)
  if negative {
    builder.write_char('-')
  }
  builder.write_stringview(digits[first:first + 1])
  if end - first > 1 {
    builder.write_char('.')
    builder.write_stringview(digits[first + 1:end])
  }
  builder.write_char('E')
  builder.write_string((power + point - first - 1).to_string())
  builder.to_string()
}

///|
/// Adapts core binary64 formatting, including its omitted negative-zero sign.
fn core_double(value : Double) -> String {
  canonical_shortest(
    value.to_string(),
    value.reinterpret_as_uint64() == 0x8000000000000000UL,
  )
}

///|
/// Adapts core's source-precision Float formatter to Ryu's exact layout.
fn core_float(value : Float) -> String {
  canonical_shortest(
    value.to_string(),
    value.reinterpret_as_uint() == 0x80000000U,
  )
}

///|
/// Measures the port's complete parse plus the same observable optional-bit adapter.
fn own_parse(input : ParseCase, view : StringView) -> UInt64? {
  if input.kind == "double" {
    try @ours.s2d(view) catch {
      _ => None
    } noraise {
      value => Some(value.reinterpret_as_uint64())
    }
  } else {
    try @ours.s2f(view) catch {
      _ => None
    } noraise {
      value => Some(value.reinterpret_as_uint().to_uint64())
    }
  }
}

///|
/// Includes core's required Float narrowing for this corpus of equivalent parse results.
fn core_parse(input : ParseCase, view : StringView) -> UInt64? {
  try @string.parse_double(view) catch {
    _ => None
  } noraise {
    value =>
      Some(
        if input.kind == "double" {
          value.reinterpret_as_uint64()
        } else {
          Float::from_double(value).reinterpret_as_uint().to_uint64()
        },
      )
  }
}

///|
test "shortest adapters produce identical Ryu strings on the measured corpus" {
  for input in format_cases() {
    match input.kind {
      "double" => assert_eq(core_double(input.value), @ours.d2s(input.value))
      "float" => {
        let value = Float::from_double(input.value)
        assert_eq(core_float(value), @ours.f2s(value))
      }
      _ => ()
    }
  }
}

///|
test "parse adapters agree with independent bits including offset views" {
  for input in parse_cases() {
    for (view, _) in parse_views(input) {
      assert_eq(own_parse(input, view), input.bits)
      assert_eq(core_parse(input, view), input.bits)
    }
  }
}
