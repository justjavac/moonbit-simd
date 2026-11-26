///|
/// Mutable counts for successive views of a single byte stream. Assignment
/// shares the state. Use `copy()` to fork it and `counts()` for a read-only
/// snapshot. The counter retains only totals, dispatch, and the trailing
/// whitespace classification.
struct Counter {
  mut lines : UInt64
  mut words : UInt64
  mut bytes : UInt64
  mut previous_space : Int32
  simd : Bool
}

///|
/// Creates an independent counter with all totals at zero and the first byte
/// treated as the start of a stream. `simd` defaults to true and selects the
/// same backend behavior as `count()` for each supplied view.
pub fn Counter::new(simd~ : Bool = true) -> Counter {
  { lines: 0, words: 0, bytes: 0, previous_space: 1, simd, }
}

///|
/// Appends `data` to the logical byte stream represented by `self`.
/// The previous view's trailing whitespace state carries across updates, so
/// one word can span several chunks. Empty views leave the counter as-is.
/// Aliases observe the update. The input is borrowed for the duration of
/// the call. Panics before mutation if the byte total would overflow `UInt64`.
pub fn Counter::update(self : Counter, data : BytesView) -> Unit {
  let length = data.length().to_uint64()
  guard self.bytes <= 0xFFFFFFFFFFFFFFFFUL - length else {
    abort("Word count byte total exceeds UInt64 capacity")
  }
  let (lines, words, previous_space) = scan(
    data,
    self.previous_space,
    self.simd,
  )
  self.lines += lines.to_uint64()
  self.words += words.to_uint64()
  self.bytes += length
  self.previous_space = previous_space
}

///|
/// Returns the totals for the concatenation of all supplied views, including a
/// word in progress. The snapshot owns its counts and stays valid across later
/// updates and resets. This read leaves the counter usable for further input.
///
/// ```mbt check
/// test {
///   let stream = @wc.Counter::new()
///   stream.update(b"par")
///   let snapshot = stream.counts()
///   stream.update(b"tial\n")
///   assert_eq(snapshot.bytes, 3UL)
///   assert_eq(stream.counts(), @wc.count(b"partial\n"))
/// }
/// ```
pub fn Counter::counts(self : Counter) -> Counts {
  { lines: self.lines, words: self.words, bytes: self.bytes, }
}

///|
/// Resets every total to zero and restores the start-of-stream classification.
/// The same object can receive a new independent byte stream using its original
/// SIMD preference. All aliases of `self` observe the reset.
pub fn Counter::reset(self : Counter) -> Unit {
  self.lines = 0
  self.words = 0
  self.bytes = 0
  self.previous_space = 1
}

///|
/// Creates a new counter with the current totals, word-boundary state, and
/// SIMD preference. Supply different suffixes to the returned counter and
/// `self` to count streams with a shared prefix. Each object can then be
/// updated or reset independently.
pub fn Counter::copy(self : Counter) -> Counter {
  {
    lines: self.lines,
    words: self.words,
    bytes: self.bytes,
    previous_space: self.previous_space,
    simd: self.simd,
  }
}
