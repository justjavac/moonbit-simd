///|
test "all upstream substring seeds retain original forward and reverse expectations" {
  let seeds = upstream_substring_seeds()
  assert_eq(seeds.length(), 37)
  for (needle, original, first, last) in seeds {
    for pad in 0..<=34 {
      for prefix in [false, true] {
        let data = if prefix {
          b"#".repeat(pad) + original
        } else {
          original + b"#".repeat(pad)
        }
        let first = if needle.is_empty() {
          Some(0)
        } else {
          first.map(index => index + (if prefix { pad } else { 0 }))
        }
        let last = if needle.is_empty() {
          Some(data.length())
        } else {
          last.map(index => index + (if prefix { pad } else { 0 }))
        }
        for simd in [false, true] {
          for prefilter in [@memmem.Auto, @memmem.None] {
            assert_eq(@memmem.find(data, needle, simd~, prefilter~), first)
            assert_eq(
              @memmem.Finder::new(needle, simd~, prefilter~).find(data),
              first,
            )
          }
          assert_eq(@memmem.rfind(data, needle, simd~), last)
          assert_eq(@memmem.FinderRev::new(needle, simd~).rfind(data), last)
        }
      }
    }
  }
}
