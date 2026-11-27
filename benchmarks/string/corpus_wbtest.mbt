///|
/// Describes one prepared search and its view-relative expected result.
struct SearchCase {
  label : String
  text : StringView
  needle : StringView
  offset : Int32
  reverse : Bool
  expected : Int32?
}

///|
/// Creates a view with matching sentinels outside its bounds when offset is nonzero.
fn partial(text : String, offset : Int32) -> StringView {
  if offset == 0 {
    return text
  }
  let backing = "x".repeat(offset) + text + "x"
  backing[offset:offset + text.length()]
}

///|
/// Supplies common forward, reverse, short and periodic substring workloads.
fn searches() -> Array[SearchCase] {
  let needle = "Ab😀"
  let fill = "a".repeat(65532)
  let periodic = "a".repeat(4096)
  let absent = "aba" + "a".repeat(62)
  [
    {
      label: "find-short",
      text: "aaaaaaaaaaaaabc",
      needle: "bc",
      offset: 0,
      reverse: false,
      expected: Some(13),
    },
    {
      label: "find-late",
      text: partial(fill + needle, 1),
      needle,
      offset: 1,
      reverse: false,
      expected: Some(65532),
    },
    {
      label: "rev-find-early",
      text: partial(needle + fill, 3),
      needle,
      offset: 3,
      reverse: true,
      expected: Some(0),
    },
    {
      label: "find-periodic",
      text: periodic,
      needle: absent,
      offset: 0,
      reverse: false,
      expected: None,
    },
    {
      label: "rev-find-periodic",
      text: periodic,
      needle: absent,
      offset: 0,
      reverse: true,
      expected: None,
    },
  ]
}

///|
/// Supplies a partial view ending in a non-ASCII code unit.
fn unit_text() -> StringView {
  partial("a".repeat(4095) + "中", 1)
}

///|
/// Supplies three ASCII fields and two two-unit separators in a partial view.
fn fields_text() -> StringView {
  partial(
    "a".repeat(1024) + "::" + "b".repeat(1024) + "::" + "c".repeat(2044),
    1,
  )
}

///|
/// Supplies equal text in distinct backing strings for a full equality scan.
fn equal_views() -> (StringView, StringView) {
  let body = "a😀b".repeat(16384)
  (partial(body, 1), ("y" + body + "z")[1:65537])
}

///|
test "StringZilla and core adapters produce the same specified results" {
  for input in searches() {
    let ours = if input.reverse {
      @ours.rev_find(input.text, input.needle)
    } else {
      @ours.find(input.text, input.needle)
    }
    let core = if input.reverse {
      input.text.rev_find(input.needle)
    } else {
      input.text.find(input.needle)
    }
    assert_eq(ours, input.expected)
    assert_eq(core, input.expected)
  }
  let units = unit_text()
  assert_eq(@ours.find_code_unit(units, 0x4E2D), Some(4095))
  assert_eq(units.find_code_unit(0x4E2D), Some(4095))
  assert_eq(@ours.rev_find_code_unit(units, 0x0078), None)
  assert_eq(units.rev_find_code_unit(0x0078), None)
  let (left, right) = equal_views()
  assert_true(@ours.equal(left, right))
  assert_true(left.equal(right))
  let text = fields_text()
  let expected : Array[StringView] = [
    "a".repeat(1024),
    "b".repeat(1024),
    "c".repeat(2044),
  ]
  assert_eq(@ours.split(text, "::").collect(), expected)
  assert_eq(text.split("::").collect(), expected)
  let replaced : StringView = "a".repeat(1024) +
    "|" +
    "b".repeat(1024) +
    "|" +
    "c".repeat(2044)
  assert_eq(@ours.replace_all(text, old="::", new="|"), replaced)
  assert_eq(text.replace_all(old="::", new="|"), replaced)
}
