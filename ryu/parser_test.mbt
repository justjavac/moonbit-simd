///|
test "experimental parser grammar and signed zero compatibility" {
  for text in ["0", ".", "e", "e+", "e-", "000.000e000", ".e2"] {
    assert_eq(@ryu.s2d(text).reinterpret_as_uint64(), 0UL)
    assert_eq(@ryu.s2f(text).reinterpret_as_uint(), 0U)
  }
  for text in ["-", "-0", "-.", "-e", "-000.000e-0"] {
    assert_eq(@ryu.s2d(text).reinterpret_as_uint64(), 0x8000000000000000UL)
    assert_eq(@ryu.s2f(text).reinterpret_as_uint(), 0x80000000U)
  }
  for text in ["1", "1e", "1e+", "1e-", "1.", "1.e", "0001e000"] {
    assert_eq(@ryu.s2d(text), 1.0)
    assert_eq(@ryu.s2f(text).reinterpret_as_uint(), 0x3F800000U)
  }
  for
    text in [
      "+1", " 1", "1 ", "1.2.3", "1ee2", "1e+-2", "NaN", "Infinity", "1\u0000", "１",
      "😀",
    ] {
    try @ryu.s2d(text) catch {
      @ryu.MalformedInput => ()
      _ => fail("Expected malformed input")
    } noraise {
      _ => fail("Expected rejection")
    }
    try @ryu.s2f(text) catch {
      @ryu.MalformedInput => ()
      _ => fail("Expected malformed input")
    } noraise {
      _ => fail("Expected rejection")
    }
  }
  try @ryu.s2d("") catch {
    @ryu.InputTooShort => ()
    _ => fail("Expected empty input")
  } noraise {
    _ => fail("Expected rejection")
  }
}

///|
test "parser digit budgets include trailing significant zeroes" {
  assert_eq(
    @ryu.s2d("00012345678901234567"),
    @string.parse_double("12345678901234567"),
  )
  assert_eq(
    @ryu.s2f("000123456789").reinterpret_as_uint(),
    Float::from_double(123456789.0).reinterpret_as_uint(),
  )
  for text in ["123456789012345678", "100000000000000000", "1e10000", "0e10000"] {
    try @ryu.s2d(text) catch {
      @ryu.InputTooLong => ()
      _ => fail("Expected digit budget")
    } noraise {
      _ => fail("Expected rejection")
    }
  }
  for text in ["1234567890", "1000000000", "1e10000"] {
    try @ryu.s2f(text) catch {
      @ryu.InputTooLong => ()
      _ => fail("Expected digit budget")
    } noraise {
      _ => fail("Expected rejection")
    }
  }
  assert_true(@ryu.s2d("1e9999").is_pos_inf())
  assert_eq(@ryu.s2d("-1e-9999").reinterpret_as_uint64(), 0x8000000000000000UL)
  assert_eq(@ryu.s2f("-1e-9999").reinterpret_as_uint(), 0x80000000U)
  assert_true(@ryu.s2f("1e9999").is_pos_inf())
}

///|
test "parser bounds use actual UTF-16 views" {
  let source = "😀+1.25e2X😀"
  assert_eq(@ryu.s2d(source[3:9]), 125.0)
  assert_eq(@ryu.s2f(source[3:9]).to_double(), 125.0)
  let integer = "!12345678901234567?"
  assert_eq(@ryu.s2d(integer[1:18]), @string.parse_double("12345678901234567"))
  let float = "!123456789?"
  assert_eq(
    @ryu.s2f(float[1:10]).to_double(),
    Float::from_double(123456789.0).to_double(),
  )
}

///|
test "parser agrees with independent core decimal rounding" {
  for
    text in [
      "2.2250738585072014e-308", "2.2250738585072013e-308", "1.7976931348623157e308",
      "5e-324", "2e-324", "3e-324", "1e-323", "-2e-324", "9007199254740993", "9007199254740995",
      "1.0000000000000001", "1e-340", "12345678901234567e-320", "1e-300",
    ] {
    assert_eq(
      @ryu.s2d(text).reinterpret_as_uint64(),
      @string.parse_double(text).reinterpret_as_uint64(),
    )
  }
  assert_eq(@ryu.s2d("1e309").reinterpret_as_uint64(), 0x7FF0000000000000UL)
  assert_eq(
    @ryu.s2d("1.7976931348623159e308").reinterpret_as_uint64(),
    0x7FF0000000000000UL,
  )
  for
    text in [
      "1e-46", "7e-46", "8e-46", "1.17549435e-38", "3.40282347e38", "3.40282357e38",
      "16777217", "16777219",
    ] {
    assert_eq(
      @ryu.s2f(text).reinterpret_as_uint(),
      Float::from_double(@string.parse_double(text)).reinterpret_as_uint(),
    )
  }
}
