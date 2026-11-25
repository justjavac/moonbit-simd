///|
/// Computes finite 16-bit floating values by the independent IEEE exponent formula.
fn half_reference(bits : Int32, fraction_bits : Int32, bias : Int32) -> Double {
  let exponent_mask = if fraction_bits == 10 { 31 } else { 255 }
  let exponent = (bits >> fraction_bits) & exponent_mask
  let fraction = bits & ((1 << fraction_bits) - 1)
  let sign = if (bits & 0x8000) == 0 { 1.0 } else { -1.0 }
  if exponent == exponent_mask {
    if fraction == 0 {
      sign * @double.infinity
    } else {
      @double.not_a_number
    }
  } else if exponent == 0 {
    sign *
    fraction.to_double() *
    @math.pow(2.0, (1 - bias - fraction_bits).to_double())
  } else {
    sign *
    ((1 << fraction_bits) + fraction).to_double() *
    @math.pow(2.0, (exponent - bias - fraction_bits).to_double())
  }
}

///|
/// Checks half searches against the independently verified widened IEEE values.
fn[T : @argminmax.Element] check_ieee_searches(
  data : ArrayView[T],
  widened : ArrayView[Double],
) -> Unit raise {
  let ordinary = sorted_reference(widened)
  let propagated = sorted_reference(widened, propagate_nan=true)
  for simd in [false, true] {
    assert_eq(@argminmax.argminmax(data, simd~), ordinary)
    assert_eq(@argminmax.argmin(data, simd~), ordinary.map(pair => pair.0))
    assert_eq(@argminmax.argmax(data, simd~), ordinary.map(pair => pair.1))
    assert_eq(@argminmax.nanargminmax(data, simd~), propagated)
    assert_eq(@argminmax.nanargmin(data, simd~), propagated.map(pair => pair.0))
    assert_eq(@argminmax.nanargmax(data, simd~), propagated.map(pair => pair.1))
  }
}

///|
test "all binary16 and bfloat16 encodings match IEEE formulas" {
  let binary = FixedArray::makei(65536, bits => {
    @argminmax.Float16::from_bits(bits.to_uint16())
  })
  let bfloat = FixedArray::makei(65536, bits => {
    @argminmax.BFloat16::from_bits(bits.to_uint16())
  })
  for bits in 0..<65536 {
    for
      (actual, expected) in [
        (binary[bits].to_double(), half_reference(bits, 10, 15)),
        (bfloat[bits].to_double(), half_reference(bits, 7, 127)),
      ] {
      if expected.is_nan() {
        assert_true(actual.is_nan())
      } else {
        assert_eq(
          actual.reinterpret_as_uint64(),
          expected.reinterpret_as_uint64(),
        )
      }
    }
    assert_eq(binary[bits].to_bits(), bits.to_uint16())
    assert_eq(bfloat[bits].to_bits(), bits.to_uint16())
    assert_eq(binary[bits].is_nan(), half_reference(bits, 10, 15).is_nan())
    assert_eq(bfloat[bits].is_nan(), half_reference(bits, 7, 127).is_nan())
  }
  for simd in [false, true] {
    assert_eq(@argminmax.argminmax(binary, simd~), Some((0xfc00, 0x7c00)))
    assert_eq(@argminmax.nanargminmax(binary, simd~), Some((0x7c01, 0x7c01)))
    assert_eq(@argminmax.argminmax(bfloat, simd~), Some((0xff80, 0x7f80)))
    assert_eq(@argminmax.nanargminmax(bfloat, simd~), Some((0x7f81, 0x7f81)))
  }
  for block in 0..<64 {
    let start = block * 1024
    let end = start + 1024
    check_ieee_searches(
      binary[start:end],
      binary[start:end].map(value => value.to_double()),
    )
    check_ieee_searches(
      bfloat[start:end],
      bfloat[start:end].map(value => value.to_double()),
    )
  }
}

///|
test "half signed zeros NaN payloads and view boundaries" {
  for length in [0, 1, 16, 17, 97, 257] {
    let bits = FixedArray::makei(length + 2, i => {
      if i % 2 == 0 {
        0x8000
      } else {
        0
      }
    })
    bits[0] = 0xffff
    bits[length + 1] = 0x7fff
    check_searches(
      bits.map(word => @argminmax.Float16::from_bits(word.to_uint16()))[1:length +
      1],
    )
    check_searches(
      bits.map(word => @argminmax.BFloat16::from_bits(word.to_uint16()))[1:length +
      1],
    )
  }
  for position in 0..<97 {
    let bits = FixedArray::make(99, 0x3c00)
    bits[0] = 0xffff
    bits[position + 1] = 0x7fff
    bits[98] = 0x7c01
    check_searches(
      bits.map(word => @argminmax.Float16::from_bits(word.to_uint16()))[1:98],
    )
    check_searches(
      bits.map(word => @argminmax.BFloat16::from_bits(word.to_uint16()))[1:98],
    )
  }
  let mut seed = 0xD5A90763U
  for _ in 0..<32 {
    let words = FixedArray::makei(257, _ => {
      seed = seed ^ (seed << 13)
      seed = seed ^ (seed >> 17)
      seed = seed ^ (seed << 5)
      seed.to_uint16()
    })
    let binary = words.map(word => @argminmax.Float16::from_bits(word))
    let bfloat = words.map(word => @argminmax.BFloat16::from_bits(word))
    check_ieee_searches(
      binary,
      words.map(word => half_reference(word.to_int(), 10, 15)),
    )
    check_ieee_searches(
      bfloat,
      words.map(word => half_reference(word.to_int(), 7, 127)),
    )
  }
}

///|
test "wide integer construction and exact word ordering" {
  assert_true(@argminmax.Int8::from_int(-129) is None)
  assert_true(@argminmax.Int8::from_int(128) is None)
  for value in -128..<=127 {
    let narrow = @argminmax.Int8::from_int(value).unwrap()
    assert_eq(narrow.to_int(), value)
    assert_eq(@argminmax.Int8::from_bits(narrow.to_bits()), narrow)
  }
  let unsigned = [
    @argminmax.UInt128::from_words(high=0x8000000000000000UL, low=0UL),
    @argminmax.UInt128::from_words(high=0UL, low=0xffffffffffffffffUL),
    @argminmax.UInt128::from_words(
      high=0xffffffffffffffffUL,
      low=0xffffffffffffffffUL,
    ),
    @argminmax.UInt128::from_uint64(0UL),
    @argminmax.UInt128::from_words(high=1UL, low=0UL),
  ]
  assert_eq(@argminmax.argminmax(unsigned), Some((3, 2)))
  assert_eq(unsigned[2].high(), 0xffffffffffffffffUL)
  assert_eq(unsigned[2].low(), 0xffffffffffffffffUL)
  let signed = [
    @argminmax.Int128::from_words(high=-9223372036854775808L, low=0UL),
    @argminmax.Int128::from_words(
      high=9223372036854775807L,
      low=0xffffffffffffffffUL,
    ),
    @argminmax.Int128::from_words(high=-1L, low=1UL),
    @argminmax.Int128::from_words(high=-1L, low=0UL),
    @argminmax.Int128::from_words(high=0L, low=0xffffffffffffffffUL),
    @argminmax.Int128::from_words(high=0L, low=1UL),
  ]
  assert_eq(@argminmax.argminmax(signed), Some((0, 1)))
  check_searches(signed)
  check_searches(unsigned)
}
