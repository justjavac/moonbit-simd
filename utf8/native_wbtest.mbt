///|
#cfg(target="native")
test "native predecessor shifts preserve byte order across UInt64 and vector lanes" {
  let previous = @simd.i8x16_const(
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
  )
  let current = @simd.i8x16_const(
    16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,
  )
  for distance in [1, 2, 3] {
    let shifted = native_previous(current, previous, distance)
    for lane in 0..<16 {
      assert_eq(
        @simd.i8x16_extract_lane_u(shifted, lane),
        (16 + lane - distance).reinterpret_as_uint(),
      )
    }
  }
}
