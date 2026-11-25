///|
/// A mutable cursor over forward, non-overlapping byte-substring occurrences.
/// Assignment shares progress; `copy()` isolates consumption. Inputs and finder
/// remain immutable. Empty needles enumerate all byte boundaries, not Unicode
/// character boundaries; exhaustion is permanent.
pub struct FindIter {
  priv finder : Finder
  priv haystack : BytesView
  priv mut cursor : Int32?
}

///|
/// Consumes and returns the next non-overlapping view-relative byte offset.
/// After a nonempty match the cursor advances by the entire needle length.
/// Empty matches advance one byte boundary, including a final match at the end.
/// Returns `None` permanently on exhaustion and updates all shared aliases.
pub fn FindIter::next(self : FindIter) -> Int32? {
  guard self.cursor is Some(cursor) else { return None }
  let found = self.finder.find(self.haystack[cursor:])
  match found {
    None => {
      self.cursor = None
      None
    }
    Some(index) => {
      let index = cursor + index
      self.cursor = if self.finder.pattern.is_empty() {
        if index == self.haystack.length() {
          None
        } else {
          Some(index + 1)
        }
      } else {
        Some(index + self.finder.pattern.length())
      }
      Some(index)
    }
  }
}

///|
/// Returns a MoonBit iterator that consumes this cursor's shared progress.
/// Use `copy().iter()` for independent traversal. No match array is allocated;
/// retained byte views stay valid after the caller's local bindings end.
pub fn FindIter::iter(self : FindIter) -> Iter[Int32] {
  Iter(() => self.next())
}

///|
/// Copies current progress into an independent mutable cursor.
/// Immutable finder and haystack storage are shared safely. Consumption of either
/// cursor leaves the other's progress intact, including after empty matches.
pub fn FindIter::copy(self : FindIter) -> FindIter {
  { finder: self.finder, haystack: self.haystack, cursor: self.cursor, }
}

///|
/// A mutable cursor over reverse, non-overlapping substring occurrences.
/// Assignment aliases progress; `copy()` isolates it. Empty needles include every
/// byte boundary from the haystack end through zero. Exhaustion is permanent.
pub struct FindRevIter {
  priv finder : FinderRev
  priv haystack : BytesView
  priv mut cursor : Int32?
}

///|
/// Consumes the rightmost remaining non-overlapping view-relative byte offset.
/// Nonempty matches restrict the next search to bytes before that match. Empty
/// matches move one boundary backward and include zero exactly once. This updates
/// shared cursor aliases, leaves input intact, and returns `None` after exhaustion.
pub fn FindRevIter::next(self : FindRevIter) -> Int32? {
  guard self.cursor is Some(cursor) else { return None }
  let found = self.finder.rfind(self.haystack[:cursor])
  match found {
    None => {
      self.cursor = None
      None
    }
    Some(index) => {
      self.cursor = if self.finder.pattern.is_empty() {
        if index == 0 {
          None
        } else {
          Some(index - 1)
        }
      } else {
        Some(index)
      }
      Some(index)
    }
  }
}

///|
/// Returns an iterator consuming this reverse cursor's shared progress.
/// Use `copy().iter()` to retain independent progress. Search remains lazy and
/// allocates no array of matches; input storage is safely retained.
pub fn FindRevIter::iter(self : FindRevIter) -> Iter[Int32] {
  Iter(() => self.next())
}

///|
/// Copies current reverse progress into an independent mutable cursor.
/// Finder and haystack are immutable and safely shared. Either copy can be
/// exhausted without changing the other, including zero-boundary empty matches.
pub fn FindRevIter::copy(self : FindRevIter) -> FindRevIter {
  { finder: self.finder, haystack: self.haystack, cursor: self.cursor, }
}
