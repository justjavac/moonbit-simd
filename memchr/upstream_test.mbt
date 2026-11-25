///|
/// Checks the original upstream expectations through every compatible byte arity.
fn verify_upstream(
  data : BytesView,
  needles : Array[Byte],
  expected : Array[Int32],
) -> Unit raise {
  let a = needles[0]
  let b = needles.get(1).unwrap_or(a)
  let c = needles.get(2).unwrap_or(a)
  for simd in [false, true] {
    for arity in needles.length()..<=3 {
      let (first, last, forward, reverse) = match arity {
        1 =>
          (
            @memchr.memchr(a, data, simd~),
            @memchr.memrchr(a, data, simd~),
            @memchr.memchr_iter(a, data, simd~),
            @memchr.memrchr_iter(a, data, simd~),
          )
        2 =>
          (
            @memchr.memchr2(a, b, data, simd~),
            @memchr.memrchr2(a, b, data, simd~),
            @memchr.memchr2_iter(a, b, data, simd~),
            @memchr.memrchr2_iter(a, b, data, simd~),
          )
        _ =>
          (
            @memchr.memchr3(a, b, c, data, simd~),
            @memchr.memrchr3(a, b, c, data, simd~),
            @memchr.memchr3_iter(a, b, c, data, simd~),
            @memchr.memrchr3_iter(a, b, c, data, simd~),
          )
      }
      assert_eq(first, expected.get(0))
      assert_eq(last, expected.last())
      assert_eq(forward.copy().count(), expected.length())
      assert_eq(reverse.copy().count(), expected.length())
      assert_eq(forward.iter().to_array(), expected)
      assert_eq(reverse.iter().to_array(), expected.rev())
    }
  }
}

///|
test "all upstream byte-search seeds preserve expectations through padded boundaries" {
  let seeds = upstream_byte_seeds()
  assert_eq(seeds.length(), 27)
  for (data, needles, expected) in seeds {
    for pad in 0..<=34 {
      verify_upstream(
        b"#".repeat(pad) + data,
        needles,
        expected.map(index => pad + index),
      )
      verify_upstream(data + b"#".repeat(pad), needles, expected)
    }
  }
}
