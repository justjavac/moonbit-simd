///|
/// Rounds a nonnegative rational independently using arbitrary-precision division.
fn rational_round(
  numerator : @bigint.BigInt,
  denominator : @bigint.BigInt,
) -> @bigint.BigInt {
  let quotient = numerator / denominator
  let remainder = numerator % denominator
  if remainder * 2 > denominator ||
    (remainder * 2 == denominator && quotient % 2 != 0) {
    quotient + 1
  } else {
    quotient
  }
}

///|
/// Constructs an exact positive rational from the input's IEEE bits without tables.
fn reference_rational(bits : UInt64) -> (@bigint.BigInt, @bigint.BigInt) {
  let exponent = ((bits >> 52) & 2047UL).to_int()
  let mantissa = bits & 0x000FFFFFFFFFFFFFUL
  let (m2, e2) = if exponent == 0 {
    (mantissa, -1074)
  } else {
    ((1UL << 52) | mantissa, exponent - 1075)
  }
  let numerator = @bigint.BigInt::from_uint64(m2)
  let one = @bigint.BigInt::from_int(1)
  if e2 >= 0 {
    (numerator << e2, one)
  } else {
    (numerator, one << -e2)
  }
}

///|
/// Formats fixed precision by exact rational scaling and ties-to-even division.
fn reference_fixed(bits : UInt64, precision : Int32) -> String {
  let (numerator, denominator) = reference_rational(bits)
  let power = @bigint.BigInt::from_int(10).pow(
    @bigint.BigInt::from_int(precision),
  )
  let decimal = rational_round(numerator * power, denominator).to_string()
  let builder = StringBuilder()
  if bits >> 63 != 0UL {
    builder.write_char('-')
  }
  if precision == 0 {
    builder.write_string(decimal)
  } else if decimal.length() <= precision {
    builder.write_string("0.")
    for _ in 0..<(precision - decimal.length()) {
      builder.write_char('0')
    }
    builder.write_string(decimal)
  } else {
    builder.write_stringview(decimal[:decimal.length() - precision])
    builder.write_char('.')
    builder.write_stringview(decimal[decimal.length() - precision:])
  }
  builder.to_string()
}

///|
/// Formats scientific precision by comparing the rational to exact decimal powers.
fn reference_scientific(bits : UInt64, precision : Int32) -> String {
  let (numerator, denominator) = reference_rational(bits)
  let ten = @bigint.BigInt::from_int(10)
  let mut exponent = 0
  if numerator != 0 {
    if numerator >= denominator {
      for threshold = denominator * 10; numerator >= threshold; {
        exponent += 1
        continue threshold * 10
      }
    } else {
      for scaled = numerator; scaled < denominator; {
        exponent -= 1
        continue scaled * 10
      }
    }
  }
  let places = precision - exponent
  let (scaled, divisor) = if places >= 0 {
    (numerator * ten.pow(@bigint.BigInt::from_int(places)), denominator)
  } else {
    (numerator, denominator * ten.pow(@bigint.BigInt::from_int(-places)))
  }
  let rounded = rational_round(scaled, divisor)
  let digits = rounded.to_string()
  let kept = precision + 1
  let digits = if digits.length() > kept {
    exponent += 1
    digits[:kept].to_owned()
  } else {
    digits
  }
  let builder = StringBuilder()
  if bits >> 63 != 0UL {
    builder.write_char('-')
  }
  builder.write_stringview(digits[:1])
  if precision > 0 {
    builder.write_char('.')
    builder.write_stringview(digits[1:])
    for _ in digits.length()..<kept {
      builder.write_char('0')
    }
  }
  builder.write_char('e')
  builder.write_char(if exponent < 0 { '-' } else { '+' })
  let absolute = if exponent < 0 { -exponent } else { exponent }
  if absolute < 10 {
    builder.write_char('0')
  }
  builder.write_string(absolute.to_string())
  builder.to_string()
}

///|
test "Printf agrees with independent exact rational formatting at block boundaries" {
  for exponent in [0, 1, 2, 100, 1022, 1023, 1075, 1076, 1535, 2046] {
    for mantissa in [0UL, 1UL, 0x0008000000000000UL, 0x000FFFFFFFFFFFFFUL] {
      for sign in [0UL, 0x8000000000000000UL] {
        let bits = sign | (exponent.to_uint64() << 52) | mantissa
        for
          precision in [0, 1, 2, 8, 9, 10, 17, 18, 19, 50, 100, 324, 1074, 1200] {
          assert_eq(
            @ryu.d2fixed(bits.reinterpret_as_double(), precision~),
            reference_fixed(bits, precision),
          )
          assert_eq(
            @ryu.d2exp(bits.reinterpret_as_double(), precision~),
            reference_scientific(bits, precision),
          )
        }
      }
    }
  }
}

///|
test "Printf rounding agrees with an independent rational oracle on random bits" {
  let mut seed = 0x525955UL
  for i in 0..<100 {
    seed = seed * 6364136223846793005UL + 1442695040888963407UL
    if ((seed >> 52) & 2047UL) == 2047UL {
      continue
    }
    let precision = i % 30
    assert_eq(
      @ryu.d2fixed(seed.reinterpret_as_double(), precision~),
      reference_fixed(seed, precision),
    )
    assert_eq(
      @ryu.d2exp(seed.reinterpret_as_double(), precision~),
      reference_scientific(seed, precision),
    )
  }
}
