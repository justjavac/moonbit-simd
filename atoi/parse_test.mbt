///|
/// Checks a precise typed parsing failure without aborting on recoverable errors.
fn[T] expect_error(
  action : () -> T raise @atoi.ParseError,
  expected : @atoi.ParseError,
) -> Unit raise {
  try action() catch {
    error => assert_eq(error, expected)
  } noraise {
    _ => fail("Expected a decimal parsing failure")
  }
}

///|
test "all fixed-width types retain exact bounds" {
  for simd in [false, true] {
    let byte : Byte = @atoi.parse(b"255", simd~)
    let int8 : @atoi.Int8 = @atoi.parse(b"-128", simd~)
    let uint16 : UInt16 = @atoi.parse(b"65535", simd~)
    let int16 : Int16 = @atoi.parse(b"-32768", simd~)
    let uint : UInt32 = @atoi.parse(b"4294967295", simd~)
    let int : Int32 = @atoi.parse(b"-2147483648", simd~)
    let uint64 : UInt64 = @atoi.parse(b"18446744073709551615", simd~)
    let int64 : Int64 = @atoi.parse(b"-9223372036854775808", simd~)
    let uint128 : @atoi.UInt128 = @atoi.parse(
      b"340282366920938463463374607431768211455",
      simd~,
    )
    let int128 : @atoi.Int128 = @atoi.parse(
      b"-170141183460469231731687303715884105728",
      simd~,
    )
    assert_eq(byte, 255)
    assert_eq(int8.to_int(), -128)
    assert_eq(int8.to_string(), "-128")
    assert_eq(uint16, 65535)
    assert_eq(int16, -32768)
    assert_eq(uint, 4294967295U)
    assert_eq(int, -2147483648)
    assert_eq(uint64, 18446744073709551615UL)
    assert_eq(int64, -9223372036854775808L)
    assert_eq(uint128.to_words(), (0xFFFFFFFFFFFFFFFFUL, 0xFFFFFFFFFFFFFFFFUL))
    assert_eq(int128.to_bits().to_words(), (0x8000000000000000UL, 0UL))
    assert_true(int128.is_negative())
    let max8 : @atoi.Int8 = @atoi.parse_pos(b"127", simd~)
    let max16 : Int16 = @atoi.parse_pos(b"32767", simd~)
    let max32 : Int32 = @atoi.parse_pos(b"2147483647", simd~)
    let max64 : Int64 = @atoi.parse_pos(b"9223372036854775807", simd~)
    let max128 : @atoi.Int128 = @atoi.parse_pos(
      b"170141183460469231731687303715884105727",
      simd~,
    )
    assert_eq(max8.to_int(), 127)
    assert_eq(max16, 32767)
    assert_eq(max32, 2147483647)
    assert_eq(max64, 9223372036854775807L)
    assert_eq(max128.to_string(), "170141183460469231731687303715884105727")
  }
}

///|
test "one beyond each bound raises overflow instead of wrapping" {
  for simd in [false, true] {
    expect_error(
      () => (@atoi.parse(b"256", simd~) : Byte),
      @atoi.Overflow(b"256"),
    )
    expect_error(
      () => (@atoi.parse(b"128", simd~) : @atoi.Int8),
      @atoi.Overflow(b"128"),
    )
    expect_error(
      () => (@atoi.parse(b"-129", simd~) : @atoi.Int8),
      @atoi.Overflow(b"129"),
    )
    expect_error(
      () => (@atoi.parse(b"65536", simd~) : UInt16),
      @atoi.Overflow(b"65536"),
    )
    expect_error(
      () => (@atoi.parse(b"32768", simd~) : Int16),
      @atoi.Overflow(b"32768"),
    )
    expect_error(
      () => (@atoi.parse(b"-32769", simd~) : Int16),
      @atoi.Overflow(b"32769"),
    )
    expect_error(
      () => (@atoi.parse(b"4294967296", simd~) : UInt32),
      @atoi.Overflow(b"4294967296"),
    )
    expect_error(
      () => (@atoi.parse(b"2147483648", simd~) : Int32),
      @atoi.Overflow(b"2147483648"),
    )
    expect_error(
      () => (@atoi.parse(b"-2147483649", simd~) : Int32),
      @atoi.Overflow(b"2147483649"),
    )
    expect_error(
      () => (@atoi.parse(b"18446744073709551616", simd~) : UInt64),
      @atoi.Overflow(b"18446744073709551616"),
    )
    expect_error(
      () => (@atoi.parse(b"9223372036854775808", simd~) : Int64),
      @atoi.Overflow(b"9223372036854775808"),
    )
    expect_error(
      () => (@atoi.parse(b"-9223372036854775809", simd~) : Int64),
      @atoi.Overflow(b"9223372036854775809"),
    )
    expect_error(
      () => {
        (
          @atoi.parse(b"340282366920938463463374607431768211456", simd~) :
          @atoi.UInt128)
      },
      @atoi.Overflow(b"340282366920938463463374607431768211456"),
    )
    expect_error(
      () => {
        (
          @atoi.parse(b"170141183460469231731687303715884105728", simd~) :
          @atoi.Int128)
      },
      @atoi.Overflow(b"170141183460469231731687303715884105728"),
    )
    expect_error(
      () => {
        (
          @atoi.parse(b"-170141183460469231731687303715884105729", simd~) :
          @atoi.Int128)
      },
      @atoi.Overflow(b"170141183460469231731687303715884105729"),
    )
  }
}

///|
test "sign-free negative operations include the minimum and negative zero" {
  for simd in [false, true] {
    let small : @atoi.Int8 = @atoi.parse_neg(b"128", simd~)
    let int16 : Int16 = @atoi.parse_neg(b"32768", simd~)
    let int : Int32 = @atoi.parse_neg(b"2147483648", simd~)
    let word : Int64 = @atoi.parse_neg(b"9223372036854775808", simd~)
    let wide : @atoi.Int128 = @atoi.parse_neg(
      b"170141183460469231731687303715884105728",
      simd~,
    )
    assert_eq(small.to_int(), -128)
    assert_eq(int16, -32768)
    assert_eq(int, -2147483648)
    assert_eq(word, -9223372036854775808L)
    assert_eq(wide.to_string(), "-170141183460469231731687303715884105728")
    let zero : @atoi.Int128 = @atoi.parse_neg(b"000", simd~)
    assert_eq(zero.to_string(), "0")
    assert_true(!zero.is_negative())
    let prefix : (Int64, Int32) = @atoi.parse_prefix_neg(b"123tail", simd~)
    assert_eq(prefix, (-123L, 3))
    expect_error(() => (@atoi.parse_neg(b"-1", simd~) : Int64), @atoi.Empty)
    expect_error(() => (@atoi.parse_neg(b"+1", simd~) : Int64), @atoi.Empty)
    expect_error(() => (@atoi.parse_pos(b"-0", simd~) : Int32), @atoi.Empty)
    expect_error(() => (@atoi.parse_pos(b"+0", simd~) : Int32), @atoi.Empty)
  }
}

///|
test "prefix counts include plus minus and all leading zeroes" {
  for simd in [false, true] {
    let unsigned : (UInt64, Int32) = @atoi.parse_prefix(
      b"+00123rest",
      skip_plus=true,
      simd~,
    )
    let signed : (Int64, Int32) = @atoi.parse_prefix(b"-00123rest", simd~)
    let positive : (UInt32, Int32) = @atoi.parse_prefix_pos(b"00123rest", simd~)
    assert_eq(unsigned, (123UL, 6))
    assert_eq(signed, (-123L, 6))
    assert_eq(positive, (123U, 5))
    let padded = b"+" + Bytes::make(100, b'0') + b"42rest"
    let prefix : (UInt64, Int32) = @atoi.parse_prefix(
      padded,
      skip_plus=true,
      skip_zeroes=true,
      simd~,
    )
    assert_eq(prefix, (42UL, 103))
    let zeroes = Bytes::make(128, b'0') + b"x"
    let zero : (Int64, Int32) = @atoi.parse_prefix(
      zeroes,
      skip_zeroes=true,
      simd~,
    )
    assert_eq(zero, (0L, 128))
    let long_small = Bytes::make(64, b'0') + b"255rest"
    let small : (Byte, Int32) = @atoi.parse_prefix(long_small, simd~)
    assert_eq(small, (255, 67))
    let too_large = Bytes::make(16, b'0') + b"256rest"
    expect_error(
      () => (@atoi.parse_prefix(too_large, simd~) : (Byte, Int32)),
      @atoi.Overflow(too_large),
    )
  }
}

///|
test "empty and malformed first bytes require an initial digit" {
  for
    data in [
      b"", b" ", b"a", b"+", b"-", b"++1", b"--1", b"+-1", b"-+1", b"\x00", b"\xFF",
    ] {
    for simd in [false, true] {
      expect_error(
        () => (@atoi.parse(data, skip_plus=true, simd~) : Int64),
        @atoi.Empty,
      )
      expect_error(
        () => (@atoi.parse_prefix(data, skip_plus=true, simd~) : (Int64, Int32)),
        @atoi.Empty,
      )
    }
  }
  expect_error(() => (@atoi.parse(b"+1") : Int64), @atoi.Empty)
  expect_error(() => (@atoi.parse(b"-0") : UInt64), @atoi.Empty)
}

///|
test "invalid suffix errors preserve magnitude byte index and the sign-free view" {
  for simd in [false, true] {
    expect_error(
      () => (@atoi.parse(b"-123x", simd~) : Int64),
      @atoi.Invalid64(123UL, 3, b"123x"),
    )
    expect_error(
      () => (@atoi.parse(b"+123x", skip_plus=true, simd~) : UInt64),
      @atoi.Invalid64(123UL, 3, b"123x"),
    )
    for
      suffix in [
        b" ",
        b"\n",
        b"_1",
        b".0",
        b"e1",
        b"\x00",
        b"\x80",
        b"\xFF",
        @utf8.encode("９"),
      ] {
      let input = b"123" + suffix
      expect_error(
        () => (@atoi.parse(input, simd~) : UInt64),
        @atoi.Invalid64(123UL, 3, input),
      )
      let prefix : (UInt64, Int32) = @atoi.parse_prefix(input, simd~)
      assert_eq(prefix, (123UL, 3))
    }
    let padded = Bytes::make(80, b'0') + b"123x"
    expect_error(
      () => (@atoi.parse(padded, skip_zeroes=true, simd~) : UInt64),
      @atoi.Invalid64(123UL, 83, padded),
    )
    let wide : @atoi.UInt128 = @atoi.parse(
      b"123456789012345678901234567890123456789",
      simd~,
    )
    let input = b"123456789012345678901234567890123456789x"
    expect_error(
      () => (@atoi.parse(input, simd~) : @atoi.UInt128),
      @atoi.Invalid128(wide, 39, input),
    )
    expect_error(
      () => (@atoi.parse(b"256x", simd~) : Byte),
      @atoi.Overflow(b"256x"),
    )
  }
}

///|
test "long narrow integer prefixes reject overflow without truncating" {
  let input = Bytes::make(65536, b'9')
  for simd in [false, true] {
    expect_error(
      () => (@atoi.parse(input, simd~) : Byte),
      @atoi.Overflow(input),
    )
    expect_error(
      () => (@atoi.parse_prefix(input, simd~) : (UInt32, Int32)),
      @atoi.Overflow(input),
    )
    expect_error(
      () => (@atoi.parse_neg(input, simd~) : Int32),
      @atoi.Overflow(input),
    )
  }
}

///|
test "portable size budgets distinguish length from arithmetic overflow" {
  for simd in [false, true] {
    for length in [20, 21, 24, 32, 64] {
      let input = Bytes::make(length, b'0')
      expect_error(
        () => (@atoi.parse(input, simd~) : Int64),
        @atoi.Size(20, input),
      )
      let value : Int64 = @atoi.parse(input, skip_zeroes=true, simd~)
      assert_eq(value, 0L)
    }
    for length in [21, 24, 32, 64] {
      let input = Bytes::make(length, b'9')
      expect_error(
        () => (@atoi.parse_prefix(input, simd~) : (UInt64, Int32)),
        @atoi.Size(21, input),
      )
    }
    let wide = Bytes::make(40, b'0')
    expect_error(
      () => (@atoi.parse(wide, simd~) : @atoi.UInt128),
      @atoi.Size(40, wide),
    )
    let value : @atoi.UInt128 = @atoi.parse(wide, skip_zeroes=true, simd~)
    assert_eq(value.to_string(), "0")
    let input = b"0" + b"18446744073709551615"
    expect_error(
      () => (@atoi.parse(input, simd~) : UInt64),
      @atoi.Size(21, input),
    )
    let value : UInt64 = @atoi.parse(input, skip_zeroes=true, simd~)
    assert_eq(value, 18446744073709551615UL)
  }
}
