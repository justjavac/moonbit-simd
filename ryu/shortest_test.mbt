// Copyright 2018 Ulf Adams. Port copyright 2026 justjavac.
// Upstream regression cases use the Boost Software License 1.0; see LICENSE.

///|
test "binary64 upstream special values and regressions" {
  for
    (value, expected) in [
      (0.0, "0E0"),
      (-0.0, "-0E0"),
      (1.0, "1E0"),
      (-1.0, "-1E0"),
      (2.2250738585072014E-308, "2.2250738585072014E-308"),
      (2.98023223876953125E-8, "2.9802322387695312E-8"),
      (-2.109808898695963E16, "-2.109808898695963E16"),
      (4.940656E-318, "4.940656E-318"),
      (1.18575755E-316, "1.18575755E-316"),
      (2.989102097996E-312, "2.989102097996E-312"),
      (9.0608011534336E15, "9.0608011534336E15"),
      (4.708356024711512E18, "4.708356024711512E18"),
      (9.409340012568248E18, "9.409340012568248E18"),
      (1.2345678, "1.2345678E0"),
    ] {
    assert_eq(@ryu.d2s(value), expected)
  }
  for
    (bits, expected) in [
      (0x7FEFFFFFFFFFFFFFUL, "1.7976931348623157E308"),
      (1UL, "5E-324"),
      (0x4830F0CF064DD592UL, "5.764607523034235E39"),
      (0x4840F0CF064DD592UL, "1.152921504606847E40"),
      (0x4850F0CF064DD592UL, "2.305843009213694E40"),
      (0x7FF0000000000000UL, "Infinity"),
      (0xFFF0000000000000UL, "-Infinity"),
      (0x7FF8000000000000UL, "NaN"),
      (0xFFF8000000000001UL, "NaN"),
      (0x7FF0000000000001UL, "NaN"),
    ] {
    assert_eq(@ryu.d2s(bits.reinterpret_as_double()), expected)
  }
}

///|
test "shortest conversion respects source Float precision" {
  assert_eq(@ryu.f2s(Float::from_double(0.3)), "3E-1")
  assert_eq(
    @ryu.d2s(Float::from_double(0.3).to_double()),
    "3.0000001192092896E-1",
  )
  for
    (bits, expected) in [
      (0U, "0E0"),
      (0x80000000U, "-0E0"),
      (0x3F800000U, "1E0"),
      (1U, "1E-45"),
      (0x7F7FFFFFU, "3.4028235E38"),
      (0x00800000U, "1.1754944E-38"),
      (0x7F800000U, "Infinity"),
      (0xFF800000U, "-Infinity"),
      (0x7FC00000U, "NaN"),
      (0xFFC00001U, "NaN"),
      (0x7F800001U, "NaN"),
    ] {
    assert_eq(@ryu.f2s(Float::reinterpret_from_uint(bits)), expected)
  }
}

///|
test "every exponent boundary round trips through independent core parsing" {
  for exponent in 0..<2047 {
    for mantissa in [0UL, 1UL, 0x000FFFFFFFFFFFFEUL, 0x000FFFFFFFFFFFFFUL] {
      for sign in [0UL, 0x8000000000000000UL] {
        let bits = sign | (exponent.to_uint64() << 52) | mantissa
        let value = bits.reinterpret_as_double()
        let output = @ryu.d2s(value)
        assert_eq(@string.parse_double(output).reinterpret_as_uint64(), bits)
        assert_eq(@ryu.s2d(output).reinterpret_as_uint64(), bits)
      }
    }
  }
  for exponent in 0..<255 {
    for mantissa in [0U, 1U, 0x007FFFFEU, 0x007FFFFFU] {
      for sign in [0U, 0x80000000U] {
        let bits = sign | (exponent.reinterpret_as_uint() << 23) | mantissa
        let value = Float::reinterpret_from_uint(bits)
        let output = @ryu.f2s(value)
        assert_eq(
          Float::from_double(@string.parse_double(output)).reinterpret_as_uint(),
          bits,
        )
        assert_eq(@ryu.s2f(output).reinterpret_as_uint(), bits)
      }
    }
  }
}

///|
test "deterministic nonzero mantissas round trip without decimal snapshots" {
  let mut seed = 0x5259555F504F5254UL
  for _ in 0..<10000 {
    seed = seed * 6364136223846793005UL + 1442695040888963407UL
    let value = seed.reinterpret_as_double()
    if value.is_finite() {
      let output = @ryu.d2s(value)
      assert_eq(@string.parse_double(output).reinterpret_as_uint64(), seed)
      assert_eq(@ryu.s2d(output).reinterpret_as_uint64(), seed)
    }
    let bits = (seed >> 32).to_uint()
    let value = Float::reinterpret_from_uint(bits)
    if value.is_finite() {
      let output = @ryu.f2s(value)
      assert_eq(
        Float::from_double(@string.parse_double(output)).reinterpret_as_uint(),
        bits,
      )
      assert_eq(@ryu.s2f(output).reinterpret_as_uint(), bits)
    }
  }
}
