///|
/// Checks all byte classifications through the private vector kernel.
#cfg(any(target="native", target="wasm"))
test "vector hexadecimal masks match all independently classified byte values" {
  assert_true(use_simd(Simd))
  assert_true(simd_available())
  for value in 0..<256 {
    let (_, mask) = decode_nibbles(@simd.i8x16_splat(value.to_byte()))
    let valid = (value >= 48 && value <= 57) ||
      (value >= 65 && value <= 70) ||
      (value >= 97 && value <= 102)
    assert_eq(@simd.i8x16_bitmask(mask), if valid { 65535 } else { 0 })
  }
}

///|
/// Confirms scalar-only backend requests cannot claim vector execution.
#cfg(not(any(target="native", target="wasm")))
test "unavailable SIMD requests resolve to the scalar backend" {
  assert_true(!use_simd(Simd))
  assert_true(!simd_available())
}
