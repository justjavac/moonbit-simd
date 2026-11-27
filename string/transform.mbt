///|
/// Lazily splits `text` on non-overlapping exact occurrences of `separator`.
/// A nonempty separator preserves empty fields, including the last one.
/// An empty separator yields one view per Unicode scalar value.
pub fn split(text : StringView, separator : StringView) -> Iter[StringView] {
  let separator_length = separator.length()
  if separator_length == 0 {
    return text.split(separator)
  }
  let mut remaining = Some(text)
  Iter(() => {
    guard remaining is Some(view) else { None }
    guard find(view, separator) is Some(index) else {
      remaining = None
      Some(view)
    }
    remaining = Some(
      view.unsafe_view(start=index + separator_length, end=view.length()),
    )
    Some(view.unsafe_view(start=0, end=index))
  })
}

///|
/// Returns the two borrowed views around the first exact `separator`, or
/// `None` on a miss. An empty separator splits at the beginning.
pub fn split_once(
  text : StringView,
  separator : StringView,
) -> (StringView, StringView)? {
  find(text, separator).map(index => {
    (
      text.unsafe_view(start=0, end=index),
      text.unsafe_view(start=index + separator.length(), end=text.length()),
    )
  })
}

///|
/// Returns the two borrowed views around the last exact `separator`, or
/// `None` on a miss. An empty separator splits at the end.
pub fn rev_split_once(
  text : StringView,
  separator : StringView,
) -> (StringView, StringView)? {
  rev_find(text, separator).map(index => {
    (
      text.unsafe_view(start=0, end=index),
      text.unsafe_view(start=index + separator.length(), end=text.length()),
    )
  })
}

///|
/// Replaces the first exact occurrence of `old` with `new`. An empty `old`
/// prepends `new`. The original view is returned on a miss.
pub fn replace(
  text : StringView,
  old~ : StringView,
  new~ : StringView,
) -> StringView {
  guard split_once(text, old) is Some((before, after)) else { text }
  [..before, ..new, ..after]
}

///|
/// Replaces non-overlapping matches of `old` from left to right. If `old` is
/// empty, inserts `new` at Unicode scalar boundaries including both ends.
/// The original view is returned when there is no match.
pub fn replace_all(
  text : StringView,
  old~ : StringView,
  new~ : StringView,
) -> StringView {
  let old_length = old.length()
  if old_length == 0 {
    return text.replace_all(old~, new~)
  }
  guard find(text, old) is Some(first) else { text }
  let builder = StringBuilder(capacity=text.length())
  for remaining = text, index = first {
    builder.write_view(remaining.unsafe_view(start=0, end=index))
    builder.write_view(new)
    let tail = remaining.unsafe_view(
      start=index + old_length,
      end=remaining.length(),
    )
    guard find(tail, old) is Some(next) else {
      builder.write_view(tail)
      break builder.to_string()
    }
    continue tail, next
  }
}
