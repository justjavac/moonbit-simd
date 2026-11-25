///|
test "portable full-width multiplication agrees with exact BigInt" {
  let mask = (@bigint.BigInt::from_int(1) << 64) - 1
  let mut seed = 0x128525955UL
  for a in [0UL, 1UL, 0xFFFFFFFFUL, 0x100000000UL, 0xFFFFFFFFFFFFFFFFUL] {
    for b in [0UL, 1UL, 0xFFFFFFFFUL, 0x100000000UL, 0xFFFFFFFFFFFFFFFFUL] {
      let (low, high) = multiply128(a, b)
      let expected = @bigint.BigInt::from_uint64(a) *
        @bigint.BigInt::from_uint64(b)
      assert_eq(low, (expected & mask).to_uint64())
      assert_eq(high, (expected >> 64).to_uint64())
    }
  }
  for _ in 0..<1000 {
    seed = seed * 6364136223846793005UL + 1UL
    let a = seed
    seed = seed * 6364136223846793005UL + 1UL
    let b = seed
    let (low, high) = multiply128(a, b)
    let expected = @bigint.BigInt::from_uint64(a) *
      @bigint.BigInt::from_uint64(b)
    assert_eq(low, (expected & mask).to_uint64())
    assert_eq(high, (expected >> 64).to_uint64())
  }
}
