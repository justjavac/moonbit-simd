///|
/// Builds an independent sort-based oracle without using the library's scanner or NaN classifier.
fn[T : Compare] sorted_reference(
  data : ArrayView[T],
  propagate_nan~ : Bool = false,
  validity~ : BytesView? = None,
  offset~ : Int32 = 0,
) -> (Int32, Int32)? {
  let indices : Array[Int32] = []
  let mut first_valid : Int32? = None
  for i in 0..<data.length() {
    let valid = match validity {
      None => true
      Some(bits) =>
        (bits[(offset + i) / 8].to_int() & (1 << ((offset + i) % 8))) != 0
    }
    if !valid {
      continue
    }
    if first_valid is None {
      first_valid = Some(i)
    }
    if data[i] != data[i] {
      if propagate_nan {
        return Some((i, i))
      }
    } else {
      indices.push(i)
    }
  }
  if indices.is_empty() {
    return first_valid.map(i => (i, i))
  }
  let sorted = FixedArray::from_array(indices)
  sorted.stable_sort_by((left, right) => data[left].compare(data[right]))
  let low = sorted[0]
  let maximum = data[sorted[sorted.length() - 1]]
  let mut high = data.length()
  for i in sorted {
    if data[i] == maximum {
      high = high.min(i)
    }
  }
  Some((low, high))
}

///|
/// Checks all six public searches against the independent sorted oracle.
fn[T : @argminmax.Element] check_searches(data : ArrayView[T]) -> Unit raise {
  let expected = sorted_reference(data)
  let nan_expected = sorted_reference(data, propagate_nan=true)
  assert_eq(@argminmax.argminmax(data), expected)
  assert_eq(@argminmax.argmin(data), expected.map(pair => pair.0))
  assert_eq(@argminmax.argmax(data), expected.map(pair => pair.1))
  assert_eq(@argminmax.nanargminmax(data), nan_expected)
  assert_eq(@argminmax.nanargmin(data), nan_expected.map(pair => pair.0))
  assert_eq(@argminmax.nanargmax(data), nan_expected.map(pair => pair.1))
  for simd in [false, true] {
    assert_eq(@argminmax.argminmax(data, simd~), expected)
    assert_eq(@argminmax.argmin(data, simd~), expected.map(pair => pair.0))
    assert_eq(@argminmax.argmax(data, simd~), expected.map(pair => pair.1))
    assert_eq(@argminmax.nanargminmax(data, simd~), nan_expected)
    assert_eq(
      @argminmax.nanargmin(data, simd~),
      nan_expected.map(pair => pair.0),
    )
    assert_eq(
      @argminmax.nanargmax(data, simd~),
      nan_expected.map(pair => pair.1),
    )
  }
}

///|
test "empty singleton and upstream documented cases" {
  check_searches(([] : Array[Int32]))
  check_searches([7])
  check_searches([0, 1, 2, 3, 4, 5])
  check_searches([3, -2, 9, -2])
  let floats : Array[Float] = [
    @float.not_a_number, 1.0, @float.not_a_number, 3.0, 4.0, 5.0,
  ]
  assert_eq(@argminmax.argminmax(floats), Some((1, 5)))
  assert_eq(@argminmax.nanargminmax(floats), Some((0, 0)))
  check_searches(floats)
  check_searches([@double.not_a_number])
  check_searches([@double.not_a_number, @double.not_a_number])
  check_searches([
    @double.not_a_number, @double.infinity, @double.infinity, @double.not_a_number,
  ])
  check_searches([
    @double.not_a_number,
    -@double.infinity,
    -@double.infinity,
    @double.not_a_number,
  ])
}

///|
test "all numeric types every tail and offset view" {
  let mut seed = 0xA1261743B5CD670FUL
  for length in 0..<100 {
    for offset in [0, 1, 3, 15] {
      let raw = FixedArray::makei(length + offset + 17, _ => {
        seed = seed ^ (seed << 13)
        seed = seed ^ (seed >> 7)
        seed = seed ^ (seed << 17)
        seed
      })
      let end = offset + length
      check_searches(raw.map(word => word.to_byte())[offset:end])
      check_searches(
        raw.map(word => @argminmax.Int8::from_bits(word.to_byte()))[offset:end],
      )
      check_searches(raw.map(word => word.to_uint16())[offset:end])
      check_searches(
        raw.map(word => Int16::reinterpret_from_uint16(word.to_uint16()))[offset:end],
      )
      check_searches(raw.map(word => word.to_uint())[offset:end])
      check_searches(
        raw.map(word => word.to_uint().reinterpret_as_int())[offset:end],
      )
      check_searches(raw[offset:end])
      check_searches(raw.map(word => word.reinterpret_as_int64())[offset:end])
      check_searches(
        raw.map(word => Float::reinterpret_from_uint(word.to_uint()))[offset:end],
      )
      check_searches(raw.map(word => word.reinterpret_as_double())[offset:end])
      check_searches(
        raw.map(word => @argminmax.Float16::from_bits(word.to_uint16()))[offset:end],
      )
      check_searches(
        raw.map(word => @argminmax.BFloat16::from_bits(word.to_uint16()))[offset:end],
      )
      check_searches(
        raw.map(word => {
          @argminmax.UInt128::from_words(
            high=word,
            low=word ^ 0x8000000000000000UL,
          )
        })[offset:end],
      )
      check_searches(
        raw.map(word => {
          @argminmax.Int128::from_words(
            high=word.reinterpret_as_int64(),
            low=word ^ 0x8000000000000000UL,
          )
        })[offset:end],
      )
    }
  }
}

///|
test "automatic long-view dispatch preserves every public result" {
  for length in [4095, 4096, 8192] {
    let values = FixedArray::makei(length, i => i % 17 - 8)
    check_searches(values)
    check_searches(values.map(value => Float::from_double(value.to_double())))
    let doubles = values.map(value => value.to_double())
    doubles[length - 1] = @double.not_a_number
    check_searches(doubles)
  }
  let masked = FixedArray::makei(8192, i => (i % 31 - 15).to_double())
  check_masked(masked, Bytes::make(1025, b'\xff'), 3)
}

///|
test "integer limits ties and indices across lane order" {
  check_searches([-2147483647 - 1, 2147483647, 0, -1])
  check_searches([0U, 0xffffffffU, 0x80000000U, 0x7fffffffU])
  check_searches([
    0UL, 0xffffffffffffffffUL, 0x8000000000000000UL, 0x7fffffffffffffffUL,
  ])
  check_searches([-9223372036854775808L, 9223372036854775807L, 0L, -1L])
  for position in 1..<40 {
    let values = FixedArray::make(97, 0)
    values[position] = -10
    values[position + 40] = -10
    values[position + 1] = 10
    values[position + 41] = 10
    check_searches(values)
    check_searches(values.map(value => value.to_double()))
  }
  check_searches(FixedArray::make(1024, 42))
  check_searches(FixedArray::make(1024, b'\xff'))
}

///|
test "NaN payloads infinities signed zeros and sentinel exclusion" {
  for length in [5, 9, 17, 33, 64, 97, 257] {
    for position in 0..<length {
      let doubles = FixedArray::makei(length + 2, i => (i - 32).to_double())
      doubles[0] = 0xfff8000000000001UL.reinterpret_as_double()
      doubles[length + 1] = 0x7ff0000000000001UL.reinterpret_as_double()
      doubles[position + 1] = 0x7ff8000000000032UL.reinterpret_as_double()
      if position + 1 < length {
        doubles[position + 2] = 0xfff0000000000001UL.reinterpret_as_double()
      }
      let floats = doubles.map(value => Float::from_double(value))
      assert_eq(
        @argminmax.nanargminmax(doubles[1:length + 1]),
        Some((position, position)),
      )
      check_searches(doubles[1:length + 1])
      check_searches(floats[1:length + 1])
    }
  }
  for fill in [0.0, -0.0, @double.infinity, -@double.infinity] {
    let values = FixedArray::make(97, fill)
    values[0] = @double.not_a_number
    assert_eq(@argminmax.argminmax(values), Some((1, 1)))
    check_searches(values)
    check_searches(values.map(value => Float::from_double(value)))
  }
  let zeros = FixedArray::makei(97, i => if i % 2 == 0 { -0.0 } else { 0.0 })
  check_searches(zeros)
  assert_eq(@argminmax.argminmax(zeros), Some((0, 0)))
}

///|
test "byte and short index overflow boundaries" {
  for length in [255, 256, 257, 511, 512, 513, 65535, 65536, 65537, 131105] {
    for position in [1, length / 2, length - 2] {
      let bytes = FixedArray::make(length + 2, b'\x80')
      bytes[0] = b'\x00'
      bytes[length + 1] = b'\xff'
      bytes[position + 1] = b'\x00'
      bytes[length] = b'\xff'
      let shorts = bytes.map(value => value.to_uint16() * 257)
      let signed_bytes = bytes.map(value => {
        @argminmax.Int8::from_bits((value.to_int() ^ 0x80).to_byte())
      })
      let signed_shorts = shorts.map(value => {
        Int16::reinterpret_from_uint16(value ^ 0x8000)
      })
      for simd in [false, true] {
        assert_eq(
          @argminmax.argminmax(bytes[1:length + 1], simd~),
          Some((position, length - 1)),
        )
        assert_eq(
          @argminmax.argminmax(shorts[1:length + 1], simd~),
          Some((position, length - 1)),
        )
        assert_eq(
          @argminmax.argminmax(signed_bytes[1:length + 1], simd~),
          Some((position, length - 1)),
        )
        assert_eq(
          @argminmax.argminmax(signed_shorts[1:length + 1], simd~),
          Some((position, length - 1)),
        )
      }
    }
  }
}

///|
/// A custom ordered type exercises the public scalar extension contract.
#derive(Eq, Compare)
struct Score(Int32)

///|
/// Uses the default scalar search for this user-defined numeric ordering.
impl @argminmax.Element for Score

///|
test "custom element scalar fallback and immutable shared input" {
  let values = [Score(3), Score(-2), Score(9), Score(-2)]
  assert_eq(@argminmax.argminmax(values), Some((1, 2)))
  check_searches(values)
  let raw = [
    @argminmax.Int128::from_int64(-1L),
    @argminmax.Int128::from_int64(1L),
  ]
  let shared = raw
  assert_eq(@argminmax.argminmax(raw), Some((0, 1)))
  assert_eq(shared[0].high(), -1L)
  assert_eq(shared[0].low(), 0xffffffffffffffffUL)
  assert_eq(shared[1].high(), 0L)
  assert_eq(shared[1].low(), 1UL)
}
