///|
/// Controls candidate filtering before exact Two-Way verification.
/// Both policies return the same byte offsets. Vector filtering requires
/// `simd=true` on native or linear-memory Wasm.
#derive(Eq, Debug)
pub(all) enum Prefilter {
  /// Uses a ranked byte pair for eligible needles, with a budget of at most
  /// fifty filter calls per search. Two-Way completes the search on exhaustion.
  Auto
  /// Uses exact Two-Way verification directly for multi-byte needles.
  None
}

///|
/// An immutable, reusable forward substring finder retaining its needle view.
/// Construction is O(m), search is O(n + m), and auxiliary storage is O(1).
/// Assignments safely share immutable state. Searches never mutate the finder,
/// needle, or haystack. All offsets count bytes, independently of text encoding.
pub struct Finder {
  priv pattern : BytesView
  priv searcher : Searcher
  priv simd : Bool
  priv prefilter : Prefilter
}

///|
/// Preprocesses arbitrary `needle` bytes without copying their immutable storage.
/// An empty needle matches every byte boundary, including the end.
/// The default options are `simd=true` and `prefilter=Auto`. Vector-capable
/// native and linear-memory Wasm can accelerate eligible candidate filters.
/// `prefilter=None` uses Two-Way directly for multi-byte needles.
/// Retaining a partial view can keep its backing buffer alive; use
/// `needle.to_owned()` before construction to materialize just that view.
pub fn Finder::new(
  needle : BytesView,
  simd~ : Bool = true,
  prefilter~ : Prefilter = Auto,
) -> Finder {
  {
    pattern: needle,
    searcher: preprocess(needle, reverse=false),
    simd,
    prefilter,
  }
}

///|
/// Returns the first occurrence in `haystack`, or `None` if no match exists.
/// Empty needles return `Some(0)` even in empty haystacks. A needle longer than
/// the view cannot match. Results are view-relative byte offsets. Searches retain
/// no haystack state and mutate neither input nor this reusable finder.
pub fn Finder::find(self : Finder, haystack : BytesView) -> Int32? {
  search_forward(
    self.pattern,
    haystack,
    self.searcher,
    simd=self.simd,
    prefilter=self.prefilter == Auto,
  )
}

///|
/// Returns the immutable needle view used to preprocess this finder.
/// This safely retains the original storage and does not consume the finder.
/// The result contains exactly the supplied view, including NUL/high-bit bytes.
pub fn Finder::needle(self : Finder) -> BytesView {
  self.pattern
}

///|
/// Creates an independent forward cursor over non-overlapping occurrences.
/// Empty needles yield every byte boundary, including the end. The cursor
/// retains the haystack view; consuming it does not affect this finder or other
/// cursors. Offsets are bytes relative to the original haystack view.
pub fn Finder::find_iter(self : Finder, haystack : BytesView) -> FindIter {
  { finder: self, haystack, cursor: Some(0), }
}

///|
/// An immutable reusable reverse Two-Way finder retaining its needle view.
/// Reverse searches use distinct backward factorization and periodic memory.
/// Construction is O(m), search O(n + m), and auxiliary storage O(1). Assignments
/// safely share immutable state; searches never mutate either input.
pub struct FinderRev {
  priv pattern : BytesView
  priv searcher : Searcher
  priv simd : Bool
}

///|
/// Preprocesses arbitrary bytes for reverse search without copying the needle.
/// Empty needles match at the haystack end. `simd` accelerates single-byte
/// needles on native/linear-memory Wasm; longer reverse searches use Two-Way
/// on every backend. Partial views retain their backing buffer safely.
pub fn FinderRev::new(needle : BytesView, simd~ : Bool = true) -> FinderRev {
  { pattern: needle, searcher: preprocess(needle, reverse=true), simd, }
}

///|
/// Returns the last occurrence in `haystack`, or `None` if absent/too long.
/// An empty needle returns `Some(haystack.length())`. Offsets are relative bytes,
/// including matches inside UTF-8 sequences. Neither input nor finder is mutated.
pub fn FinderRev::rfind(self : FinderRev, haystack : BytesView) -> Int32? {
  search_reverse(self.pattern, haystack, self.searcher, simd=self.simd)
}

///|
/// Returns the exact original immutable needle view, including empty views,
/// NUL, and high-bit bytes. It shares the backing storage retained during
/// construction and can be kept independently of the finder.
pub fn FinderRev::needle(self : FinderRev) -> BytesView {
  self.pattern
}

///|
/// Creates an independent reverse cursor over non-overlapping occurrences.
/// Empty needles yield every byte boundary from the end through zero. Matches
/// are selected from the right, so overlapping patterns can produce a different
/// set from forward iteration. Finder/input storage remains immutable.
pub fn FinderRev::rfind_iter(
  self : FinderRev,
  haystack : BytesView,
) -> FindRevIter {
  { finder: self, haystack, cursor: Some(haystack.length()), }
}
