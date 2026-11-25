///|
/// Returns the first byte-substring offset, or `None` if `needle` is absent.
/// Empty needles return `Some(0)`. Arbitrary bytes and offset views are accepted
/// without decoding, copying, mutation, or overreads. One-off preprocessing is
/// included; reuse `Finder` when searching for one needle in many haystacks.
/// `simd` and `prefilter` have the same meaning as in `Finder::new`.
///
/// ```mbt check
/// test {
///   assert_eq(@memmem.find(b"foo bar foo", b"foo"), Some(0))
///   assert_eq(@memmem.find(b"foo", b""), Some(0))
/// }
/// ```
pub fn find(
  haystack : BytesView,
  needle : BytesView,
  simd~ : Bool = true,
  prefilter~ : Prefilter = Auto,
) -> Int32? {
  if needle.is_empty() {
    Some(0)
  } else if needle.length() == 1 {
    @bytesearch.memchr(needle[0], haystack, simd~)
  } else {
    Finder::new(needle, simd~, prefilter~).find(haystack)
  }
}

///|
/// Returns the last byte-substring offset, or `None` if absent/too long.
/// Empty needles return `Some(haystack.length())`. Both views remain immutable;
/// offsets count bytes, even inside multibyte text. Preprocessing is included;
/// reuse `FinderRev` for repeated searches. `simd` follows `FinderRev::new`.
pub fn rfind(
  haystack : BytesView,
  needle : BytesView,
  simd~ : Bool = true,
) -> Int32? {
  if needle.is_empty() {
    Some(haystack.length())
  } else if needle.length() == 1 {
    @bytesearch.memrchr(needle[0], haystack, simd~)
  } else {
    FinderRev::new(needle, simd~).rfind(haystack)
  }
}

///|
/// Creates a lazy cursor over forward non-overlapping byte-substring matches.
/// Empty needles match every byte boundary, including the end. Cursor assignments
/// share progress; `copy()` makes it independent. Both input views are retained
/// safely. `simd` and `prefilter` follow `Finder::new`.
pub fn find_iter(
  haystack : BytesView,
  needle : BytesView,
  simd~ : Bool = true,
  prefilter~ : Prefilter = Auto,
) -> FindIter {
  Finder::new(needle, simd~, prefilter~).find_iter(haystack)
}

///|
/// Creates a lazy cursor over reverse non-overlapping byte-substring matches.
/// Empty needles enumerate boundaries from the end through zero. Reverse match
/// selection can differ from reversed forward results for overlapping patterns.
/// Cursor assignment aliases progress; `simd` follows `FinderRev::new`.
pub fn rfind_iter(
  haystack : BytesView,
  needle : BytesView,
  simd~ : Bool = true,
) -> FindRevIter {
  FinderRev::new(needle, simd~).rfind_iter(haystack)
}
