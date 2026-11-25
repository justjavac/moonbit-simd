///|
/// Verifies every masked entry point against independently filtered sorted indices.
fn[T : @argminmax.Element] check_masked(
  data : ArrayView[T],
  bits : BytesView,
  offset : Int32,
) -> Unit raise {
  let expected = sorted_reference(data, validity=Some(bits), offset~)
  let propagated = sorted_reference(
    data,
    propagate_nan=true,
    validity=Some(bits),
    offset~,
  )
  assert_eq(@argminmax.argminmax_masked(data, bits, offset~), expected)
  assert_eq(
    @argminmax.argmin_masked(data, bits, offset~),
    expected.map(pair => pair.0),
  )
  assert_eq(
    @argminmax.argmax_masked(data, bits, offset~),
    expected.map(pair => pair.1),
  )
  assert_eq(@argminmax.nanargminmax_masked(data, bits, offset~), propagated)
  assert_eq(
    @argminmax.nanargmin_masked(data, bits, offset~),
    propagated.map(pair => pair.0),
  )
  assert_eq(
    @argminmax.nanargmax_masked(data, bits, offset~),
    propagated.map(pair => pair.1),
  )
  for simd in [false, true] {
    assert_eq(@argminmax.argminmax_masked(data, bits, offset~, simd~), expected)
    assert_eq(
      @argminmax.argmin_masked(data, bits, offset~, simd~),
      expected.map(pair => pair.0),
    )
    assert_eq(
      @argminmax.argmax_masked(data, bits, offset~, simd~),
      expected.map(pair => pair.1),
    )
    assert_eq(
      @argminmax.nanargminmax_masked(data, bits, offset~, simd~),
      propagated,
    )
    assert_eq(
      @argminmax.nanargmin_masked(data, bits, offset~, simd~),
      propagated.map(pair => pair.0),
    )
    assert_eq(
      @argminmax.nanargmax_masked(data, bits, offset~, simd~),
      propagated.map(pair => pair.1),
    )
  }
}

///|
test "upstream Arrow bitmap cases retain original indices" {
  // argminmax 0.7.1 README and src/lib.rs, revision f68aba5c251e9dc093f3939c0f9607c942228311.
  assert_eq(@argminmax.argminmax_masked([-5, 3, 9, 4], b"\x06"), Some((1, 2)))
  assert_eq(
    @argminmax.argminmax_masked([-5, 1, 2, 3, 4, 9], b"\x3c", offset=1),
    Some((1, 4)),
  )
  assert_eq(@argminmax.argminmax_masked([-5, 1, 2, 3, 4, 9], b"\x00"), None)
  check_masked([-5, 1, 2, 3, 4, 9], b"\x3c", 1)
  check_masked(([] : Array[Int32]), b"", 0)
  check_masked([7], b"\xff", 7)
  check_masked([7], b"\x00", 7)
}

///|
test "bitmap offsets byte subviews tails dense and sparse masks" {
  let mut seed = 0xBC57019DA24F6813UL
  for length in [0, 1, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 64, 65, 129, 257] {
    for bit_offset in 0..<24 {
      for pattern in [0x00, 0xff, 0x55, 0x7f, -1] {
        let raw = FixedArray::makei(length + 2, _ => {
          seed = seed ^ (seed << 13)
          seed = seed ^ (seed >> 7)
          seed = seed ^ (seed << 17)
          seed
        })
        let bits = Bytes::makei((length + bit_offset + 7) / 8 + 4, i => {
          if pattern >= 0 {
            pattern.to_byte()
          } else {
            raw[i % raw.length()].to_byte()
          }
        })
        let bitmap = bits[2:bits.length() - 2]
        let view = raw[1:length + 1]
        check_masked(view.map(word => word.to_byte()), bitmap, bit_offset)
        check_masked(
          view.map(word => @argminmax.Int8::from_bits(word.to_byte())),
          bitmap,
          bit_offset,
        )
        check_masked(view.map(word => word.to_uint16()), bitmap, bit_offset)
        check_masked(
          view.map(word => Int16::reinterpret_from_uint16(word.to_uint16())),
          bitmap,
          bit_offset,
        )
        check_masked(view.map(word => word.to_uint()), bitmap, bit_offset)
        check_masked(
          view.map(word => word.to_uint().reinterpret_as_int()),
          bitmap,
          bit_offset,
        )
        check_masked(view, bitmap, bit_offset)
        check_masked(
          view.map(word => word.reinterpret_as_int64()),
          bitmap,
          bit_offset,
        )
        check_masked(
          view.map(word => Float::reinterpret_from_uint(word.to_uint())),
          bitmap,
          bit_offset,
        )
        check_masked(
          view.map(word => word.reinterpret_as_double()),
          bitmap,
          bit_offset,
        )
        check_masked(
          view.map(word => @argminmax.Float16::from_bits(word.to_uint16())),
          bitmap,
          bit_offset,
        )
        check_masked(
          view.map(word => @argminmax.BFloat16::from_bits(word.to_uint16())),
          bitmap,
          bit_offset,
        )
        check_masked(
          view.map(word => {
            @argminmax.Int128::from_words(
              high=word.reinterpret_as_int64(),
              low=word,
            )
          }),
          bitmap,
          bit_offset,
        )
        check_masked(
          view.map(word => @argminmax.UInt128::from_words(high=word, low=word)),
          bitmap,
          bit_offset,
        )
      }
    }
  }
}

///|
test "masked NaN policies all nulls all NaNs infinities and ties" {
  let nan = @double.not_a_number
  for
    values in [
      [nan, nan, nan, nan, nan, nan],
      [nan, @double.infinity, nan, @double.infinity, nan, nan],
      [nan, -@double.infinity, nan, -@double.infinity, nan, nan],
      [nan, -0.0, nan, 0.0, nan, nan],
      [nan, -9.0, 9.0, -9.0, 9.0, nan],
    ] {
    for bits in [b"\x00", b"\xff", b"\x2a", b"\x15", b"\x18"] {
      check_masked(values, bits, 0)
      check_masked(values.map(value => Float::from_double(value)), bits, 0)
    }
  }
  assert_eq(
    @argminmax.argminmax_masked([nan, nan, nan, nan], b"\x0c"),
    Some((2, 2)),
  )
  assert_eq(
    @argminmax.nanargminmax_masked([nan, -1.0, 3.0, nan], b"\x06"),
    Some((1, 2)),
  )
  let values = FixedArray::makei(1024, i => (i % 64).to_double())
  values[0] = nan
  values[511] = nan
  values[700] = 0xfff0000000000001UL.reinterpret_as_double()
  for
    bits in [
      Bytes::make(128, b'\xff'),
      Bytes::make(128, b'\x7f'),
      Bytes::make(128, b'\x55'),
    ] {
    check_masked(values, bits, 0)
  }
}

///|
test "bitmap validation rejects negative missing and overflowing ranges" {
  try @argminmax.argminmax_masked([1], b"\xff", offset=-1) catch {
    error => assert_eq(error, @argminmax.BitmapError::InvalidOffset(-1))
  } noraise {
    _ => fail("Expected invalid offset")
  }
  try @argminmax.argminmax_masked([1, 2], b"\xff", offset=7) catch {
    error =>
      assert_eq(
        error,
        @argminmax.BitmapError::InsufficientBits(required=9L, available=8L),
      )
  } noraise {
    _ => fail("Expected insufficient bits")
  }
  try @argminmax.nanargmax_masked([1.0], b"", offset=2147483647) catch {
    error =>
      assert_eq(
        error,
        @argminmax.BitmapError::InsufficientBits(
          required=2147483648L,
          available=0L,
        ),
      )
  } noraise {
    _ => fail("Expected wide length validation")
  }
  try @argminmax.argmin_masked(([] : Array[Int32]), b"", offset=1) catch {
    error =>
      assert_eq(
        error,
        @argminmax.BitmapError::InsufficientBits(required=1L, available=0L),
      )
  } noraise {
    _ => fail("Expected empty range offset validation")
  }
}
