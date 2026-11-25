///|
/// A lazy double-ended byte-match cursor retaining an immutable haystack view.
/// Assignment aliases cursor state; `copy()` gives independent consumption.
/// Matches are unique even with duplicate needles. Exhaustion is permanent.
pub struct Matches {
  priv needles : Needles
  priv haystack : BytesView
  priv mut front : Int32
  priv mut back : Int32
  priv reverse : Bool
  priv simd : Bool
}

///|
/// Creates an independent cursor over the supplied view and selected needle union.
fn matches(
  needles : Needles,
  haystack : BytesView,
  reverse~ : Bool,
  simd~ : Bool,
) -> Matches {
  { needles, haystack, front: 0, back: haystack.length(), reverse, simd, }
}

///|
/// Takes a match from one end and updates the remaining half-open byte range.
fn Matches::take(self : Matches, reverse~ : Bool) -> Int32? {
  let found = search_bytes(
    self.needles,
    self.haystack[self.front:self.back],
    reverse~,
    simd=self.simd,
  )
  match found {
    None => {
      self.front = self.back
      None
    }
    Some(index) => {
      let index = self.front + index
      if reverse {
        self.back = index
      } else {
        self.front = index + 1
      }
      Some(index)
    }
  }
}

///|
/// Returns and consumes the next match in this cursor's construction direction.
/// Offsets refer to the original view, even after mixed calls to `next_back()`.
/// Returns `None` when exhausted and mutates shared aliases; input stays intact.
pub fn Matches::next(self : Matches) -> Int32? {
  self.take(reverse=self.reverse)
}

///|
/// Returns and consumes a match from the opposite end of this cursor.
/// Mixed front/back consumption cannot repeat a match. Returns `None` permanently
/// after exhaustion; assignment aliases the same mutable cursor state.
pub fn Matches::next_back(self : Matches) -> Int32? {
  self.take(reverse=!self.reverse)
}

///|
/// Returns an iterator that consumes this cursor in its construction direction.
/// Iterator and cursor aliases share progress. Call `copy().iter()` to iterate
/// independently. The haystack view is retained safely and never modified.
pub fn Matches::iter(self : Matches) -> Iter[Int32] {
  Iter(() => self.next())
}

///|
/// Counts and consumes all remaining unique matching byte positions.
/// The result is at most the remaining byte length. Complete vectors or exact
/// SWAR masks count several matches at once; this exhausts all cursor aliases.
pub fn Matches::count(self : Matches) -> Int32 {
  let count = count_bytes(
    self.needles,
    self.haystack[self.front:self.back],
    simd=self.simd,
  )
  self.front = self.back
  count
}

///|
/// Copies the current progress into an independent mutable cursor.
/// Immutable haystack storage is safely shared; consuming either cursor does not
/// affect the other. Needle values, direction, and SIMD preference are retained.
pub fn Matches::copy(self : Matches) -> Matches {
  {
    needles: self.needles,
    haystack: self.haystack,
    front: self.front,
    back: self.back,
    reverse: self.reverse,
    simd: self.simd,
  }
}

///|
/// Creates a forward double-ended cursor over all occurrences of `needle`.
/// Empty input yields no matches. Offsets are bytes relative to `haystack`.
/// Input is retained without copying/mutation; `simd` follows `memchr` dispatch.
pub fn memchr_iter(
  needle : Byte,
  haystack : BytesView,
  simd~ : Bool = true,
) -> Matches {
  matches(One(needle), haystack, reverse=false, simd~)
}

///|
/// Creates a reverse double-ended cursor over all occurrences of `needle`.
/// `next()` moves backward; `next_back()` moves forward. Empty input has no
/// matches. View retention, byte offsets, and `simd` follow `memchr_iter`.
pub fn memrchr_iter(
  needle : Byte,
  haystack : BytesView,
  simd~ : Bool = true,
) -> Matches {
  matches(One(needle), haystack, reverse=true, simd~)
}

///|
/// Creates a forward double-ended cursor matching either byte exactly once.
/// Needle order/duplicates are accepted. Empty input has no matches; retained
/// input is immutable and offsets are view-relative. `simd` follows `memchr`.
pub fn memchr2_iter(
  needle1 : Byte,
  needle2 : Byte,
  haystack : BytesView,
  simd~ : Bool = true,
) -> Matches {
  matches(Two(needle1, needle2), haystack, reverse=false, simd~)
}

///|
/// Creates a reverse double-ended cursor matching either byte exactly once.
/// `next_back()` consumes the forward end. Empty input and duplicate needles
/// follow `memchr2_iter`; `simd` requests the same bounded search implementation.
pub fn memrchr2_iter(
  needle1 : Byte,
  needle2 : Byte,
  haystack : BytesView,
  simd~ : Bool = true,
) -> Matches {
  matches(Two(needle1, needle2), haystack, reverse=true, simd~)
}

///|
/// Creates a forward double-ended cursor matching any of three bytes once.
/// Duplicate values never repeat a position. Empty input has no matches; bytes
/// and view-relative offsets are retained without mutation. `simd` follows `memchr`.
pub fn memchr3_iter(
  needle1 : Byte,
  needle2 : Byte,
  needle3 : Byte,
  haystack : BytesView,
  simd~ : Bool = true,
) -> Matches {
  matches(Three(needle1, needle2, needle3), haystack, reverse=false, simd~)
}

///|
/// Creates a reverse double-ended cursor matching any of three bytes once.
/// `next_back()` consumes the forward end; duplicates, empty input, safe view
/// retention, and `simd` dispatch follow `memchr3_iter`.
pub fn memrchr3_iter(
  needle1 : Byte,
  needle2 : Byte,
  needle3 : Byte,
  haystack : BytesView,
  simd~ : Bool = true,
) -> Matches {
  matches(Three(needle1, needle2, needle3), haystack, reverse=true, simd~)
}
