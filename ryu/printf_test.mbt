///|
test "fixed ties to even and decimal carry" {
  for
    (value, precision, expected) in [
      (0.0, 0, "0"),
      (-0.0, 0, "-0"),
      (-0.0, 3, "-0.000"),
      (2.5, 0, "2"),
      (3.5, 0, "4"),
      (-2.5, 0, "-2"),
      (0.5, 0, "0"),
      (-0.5, 0, "-0"),
      (1.5, 0, "2"),
      (1.25, 1, "1.2"),
      (1.75, 1, "1.8"),
      (9.875, 2, "9.88"),
      (9.999, 2, "10.00"),
      (99.999, 2, "100.00"),
      (-9.999, 2, "-10.00"),
      (-0.001, 2, "-0.00"),
      (0.1, 20, "0.10000000000000000555"),
      (1.0, 18, "1.000000000000000000"),
    ] {
    assert_eq(@ryu.d2fixed(value, precision~), expected)
  }
}

///|
test "scientific ties to even and exponent carry" {
  for
    (value, precision, expected) in [
      (0.0, 0, "0e+00"),
      (-0.0, 3, "-0.000e+00"),
      (2.5, 0, "2e+00"),
      (3.5, 0, "4e+00"),
      (1.25, 1, "1.2e+00"),
      (1.75, 1, "1.8e+00"),
      (9.99, 1, "1.0e+01"),
      (-9.99, 1, "-1.0e+01"),
      (0.00999, 1, "1.0e-02"),
      (1.0e100, 0, "1e+100"),
      (1.0e-100, 0, "1e-100"),
      (0.1, 20, "1.00000000000000005551e-01"),
    ] {
    assert_eq(@ryu.d2exp(value, precision~), expected)
  }
  assert_eq(
    @ryu.d2exp(1UL.reinterpret_as_double(), precision=6),
    "4.940656e-324",
  )
}

///|
test "Printf special values and invalid precision are portable" {
  for
    (bits, expected) in [
      (0x7FF0000000000000UL, "Infinity"),
      (0xFFF0000000000000UL, "-Infinity"),
      (0x7FF8000000000000UL, "nan"),
      (0xFFF8000000000001UL, "nan"),
      (0x7FF0000000000001UL, "nan"),
    ] {
    assert_eq(@ryu.d2fixed(bits.reinterpret_as_double(), precision=0), expected)
    assert_eq(@ryu.d2exp(bits.reinterpret_as_double(), precision=100), expected)
  }
  for precision in [-1, 2147483337, 2147483647] {
    try @ryu.d2fixed(1.0, precision~) catch {
      @ryu.InvalidPrecision(observed) => assert_eq(observed, precision)
    } noraise {
      _ => fail("Expected an invalid precision")
    }
    try @ryu.d2exp(1.0, precision~) catch {
      @ryu.InvalidPrecision(observed) => assert_eq(observed, precision)
    } noraise {
      _ => fail("Expected an invalid precision")
    }
  }
}

///|
test "high precision pads after the exact binary expansion" {
  let fixed = @ryu.d2fixed(0.5, precision=10000)
  assert_eq(fixed.length(), 10002)
  assert_eq(fixed[:3].to_owned(), "0.5")
  for c in fixed[3:] {
    assert_eq(c, '0')
  }
  let scientific = @ryu.d2exp(0.5, precision=10000)
  assert_eq(scientific.length(), 10006)
  assert_eq(scientific[:2].to_owned(), "5.")
  assert_eq(scientific[10002:].to_owned(), "e-01")
  for c in scientific[2:10002] {
    assert_eq(c, '0')
  }
}
