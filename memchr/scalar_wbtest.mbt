///|
#cfg(not(target="js"))
test "exact zero masks reject adjacent borrow false positives in every byte pair" {
  for low in 0..<256 {
    for high in 0..<256 {
      let word = low.to_uint64() |
        (high.to_uint64() << 8) |
        0xFF807F0102010000UL
      let expected = (if low == 0 { 0x80UL } else { 0UL }) |
        (if high == 0 { 0x8000UL } else { 0UL })
      // Fixed upper lanes are all nonzero; only the first two bytes can match.
      assert_eq(zero_bytes(word), expected)
    }
  }
}
