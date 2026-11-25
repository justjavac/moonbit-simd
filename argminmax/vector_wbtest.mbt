///|
#cfg(any(target="native", target="wasm"))
test "unsigned vector indices and lane masks match scalar arithmetic" {
  for lanes in [16, 8, 4, 2] {
    let mut indices = initial_indices(lanes)
    let blocks = if lanes == 16 { 16 } else { 64 }
    for block in 0..<blocks {
      for lane in 0..<lanes {
        assert_eq(index_lane(indices, lane, lanes), block * lanes + lane)
      }
      indices = next_indices(indices, lanes)
    }
    assert_eq(
      lane_mask(@simd.i32x4_splat(0xffffffffU), lanes),
      (1 << lanes) - 1,
    )
    assert_eq(lane_mask(@simd.i32x4_splat(0U), lanes), 0)
  }
}

///|
#cfg(any(target="native", target="wasm"))
test "forced vector search preserves scalar contracts on short views" {
  for length in 0..<35 {
    let values = FixedArray::makei(length + 2, i => (i % 5 - 2).to_double())
    values[0] = @double.not_a_number
    values[length + 1] = @double.not_a_number
    for propagate_nan in [false, true] {
      for (minimum, maximum) in [(true, true), (true, false), (false, true)] {
        assert_eq(
          vector_find(values[1:length + 1], minimum~, maximum~, propagate_nan~),
          scalar_find(values[1:length + 1], minimum~, maximum~, propagate_nan~),
        )
      }
    }
  }
}
