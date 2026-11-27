///|
/// Finds a literal needle by independently comparing every eligible start.
fn naive_find(
  text : StringView,
  needle : StringView,
  reverse~ : Bool,
) -> Int32? {
  if needle.is_empty() {
    return Some(if reverse { text.length() } else { 0 })
  }
  let last = text.length() - needle.length()
  for delta in 0..<=last {
    let start = if reverse { last - delta } else { delta }
    let mut matched = true
    for index in 0..<needle.length() {
      if text[start + index] != needle[index] {
        matched = false
        break
      }
    }
    if matched {
      return Some(start)
    }
  }
  None
}

///|
test "literal searches match core and a code unit oracle" {
  let alphabet : ReadOnlyArray[Char] = [
    'a', 'a', 'b', '中', '😀', '😊', '\u0000',
  ]
  let mut random = 0xD15EA5EU
  for length in 0..<=48 {
    let chars = Array::makei(length, _ => {
      random = random * 1664525U + 1013904223U
      alphabet[((random >> 16) % 7U).reinterpret_as_int()]
    })
    let body = String::from_array(chars)
    let backing = "😀!" + body + "中!"
    let text = backing[3:3 + body.length()]
    for
      needle in [
        "", "a", "中", "😀", "a中", "😀😊", "\u0000", "!", "中!", "aaaaaaaa",
      ] {
      assert_eq(
        @string.find(text, needle),
        naive_find(text, needle, reverse=false),
      )
      assert_eq(
        @string.rev_find(text, needle),
        naive_find(text, needle, reverse=true),
      )
      assert_eq(@string.find(text, needle), text.find(needle))
      assert_eq(@string.rev_find(text, needle), text.rev_find(needle))
      assert_eq(@string.contains(text, needle), text.contains(needle))
    }
    let partial_needle = backing[3:3 + length / 2]
    assert_eq(
      @string.find(text, partial_needle),
      naive_find(text, partial_needle, reverse=false),
    )
    assert_eq(
      @string.rev_find(text, partial_needle),
      naive_find(text, partial_needle, reverse=true),
    )
  }
}

///|
test "every lane and scalar tail stays inside unaligned views" {
  for length in 0..<=65 {
    let missing_backing = "x" + "a".repeat(length) + "x"
    let missing = missing_backing[1:1 + length]
    assert_eq(@string.find_code_unit(missing, 0x78), None)
    assert_eq(@string.rev_find_code_unit(missing, 0x78), None)
    assert_eq(@string.find(missing, "ax"), None)
    assert_eq(@string.rev_find(missing, "xa"), None)
    for start in 0..<length {
      let body = "a".repeat(start) + "x" + "a".repeat(length - start - 1)
      let backing = "xxx" + body + "x"
      let text = backing[3:3 + length]
      assert_eq(@string.find_code_unit(text, 0x78), Some(start))
      assert_eq(@string.rev_find_code_unit(text, 0x78), Some(start))
      if start + 1 < length {
        assert_eq(@string.find(text, "xa"), Some(start))
        assert_eq(@string.rev_find(text, "xa"), Some(start))
      }
    }
  }
}

///|
test "Unicode offsets refer to raw UTF-16 code units" {
  let text = "x😀z😀x"[1:6]
  assert_eq(@string.find(text, "😀"), Some(0))
  assert_eq(@string.rev_find(text, "😀"), Some(3))
  assert_eq(@string.find_code_unit(text, 0xD83D), Some(0))
  assert_eq(@string.rev_find_code_unit(text, 0xDE00), Some(4))
  let low = "😀".unsafe_view(start=1, end=2)
  let backing = "😀😀😀😀😀😀😀😀😀😀"
  let wide = backing[2:18]
  assert_eq(@string.find(wide, low), Some(1))
  assert_eq(@string.rev_find(wide, low), Some(15))
  assert_eq(@string.find(wide, ""), Some(0))
  assert_eq(@string.rev_find(wide, ""), Some(16))
  assert_eq(@string.rev_find("aaaa", "aaa"), Some(1))
}

///|
test "periodic false positives hand off the correct remaining range" {
  let run = "a".repeat(1537)
  let needle = "a".repeat(20) + "b" + "a".repeat(44)
  assert_eq(@string.find(run, needle), None)
  assert_eq(@string.rev_find(run, needle), None)
  let middle = run + needle + run
  let backing = "x" + middle + "x"
  let text = backing[1:1 + middle.length()]
  assert_eq(@string.find(text, needle), Some(1537))
  assert_eq(@string.rev_find(text, needle), Some(1537))
}

///|
test "wide probes preserve match order across both halves of a block" {
  let needle : StringView = "a😀b"
  for
    (first, last, tail) in [
      (7, 15, 49),
      (15, 31, 32),
      (31, 63, 31),
      (63, 94, 16),
      (95, 127, 7),
    ] {
    let body = "x".repeat(first) +
      needle.to_owned() +
      "x".repeat(last - first - needle.length()) +
      needle.to_owned() +
      "x".repeat(tail)
    let backing = "a😀b" + body + "a😀b"
    let view = backing[4:4 + body.length()]
    assert_eq(@string.find(view, needle), Some(first))
    assert_eq(@string.rev_find(view, needle), Some(last))
  }
}
