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
/// Starts an empty counter. `simd` selects the same backend behavior as
/// `count()`, applied independently to each supplied view.
pub fn Counter::new(simd~ : Bool = true) -> Counter {
  { lines: 0, words: 0, bytes: 0, previous_space: 1, simd, }
}

///|
/// Appends `data` to this counter. A word can span any number of updates.
/// Reads only the supplied view and retains no bytes. Empty views leave the
/// state intact. Panics before mutation if the byte total exceeds `UInt64`.
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
/// Returns the totals so far, including a word in progress. The snapshot stays
/// valid across further updates and resets. Reading it leaves the counter usable.
pub fn Counter::counts(self : Counter) -> Counts {
  { lines: self.lines, words: self.words, bytes: self.bytes, }
}

///|
/// Clears all totals and the preceding byte classification while retaining the
/// selected dispatch. Shared references observe the reset.
pub fn Counter::reset(self : Counter) -> Unit {
  self.lines = 0
  self.words = 0
  self.bytes = 0
  self.previous_space = 1
}

///|
/// Forks the current totals, word-boundary state, and dispatch into a counter
/// that can be updated or reset independently of `self`.
pub fn Counter::copy(self : Counter) -> Counter {
  {
    lines: self.lines,
    words: self.words,
    bytes: self.bytes,
    previous_space: self.previous_space,
    simd: self.simd,
  }
}
