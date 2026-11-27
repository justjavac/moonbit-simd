///|
test "equality and prefix or suffix compare exact subview contents" {
  assert_true(@string.equal("", "x"[1:1]))
  assert_false(@string.equal("a", "ab"))
  for length in 0..<=65 {
    let body = "a".repeat(length)
    let left = "x" + body + "y"
    let right = "zz" + body + "zz"
    let view = left[1:1 + length]
    let same = right[2:2 + length]
    assert_true(@string.equal(view, view))
    assert_true(@string.equal(view, same))
    assert_true(@string.has_prefix(view, same))
    assert_true(@string.has_suffix(view, same))
    assert_false(@string.has_prefix(view, right))
    assert_false(@string.has_suffix(view, right))
    for position in 0..<length {
      let different = "a".repeat(position) +
        "b" +
        "a".repeat(length - position - 1)
      assert_false(@string.equal(view, different))
      assert_false(@string.has_prefix(view, different))
      assert_false(@string.has_suffix(view, different))
    }
  }
  assert_true(@string.has_prefix("a😀中", "a😀"))
  assert_true(@string.has_suffix("a😀中", "😀中"))
}

///|
test "long equality compares raw surrogate units within view bounds" {
  let body = "😀x".repeat(32)
  let left = "!" + body + "?"
  let right = "zz" + body + "y"
  let changed = "zz" + "😀x".repeat(24) + "😁x" + "😀x".repeat(7) + "y"
  let view = left.unsafe_view(start=2, end=95)
  let same = right.unsafe_view(start=3, end=96)
  let different = changed.unsafe_view(start=3, end=96)
  assert_true(@string.equal(view, same))
  assert_false(@string.equal(view, different))
  assert_true(@string.has_prefix(left.unsafe_view(start=2, end=96), same))
  assert_true(@string.has_suffix(left.unsafe_view(start=1, end=95), same))
  assert_false(@string.has_suffix(left.unsafe_view(start=1, end=95), different))
}

///|
test "split is lazy and preserves empty fields and borrowed view offsets" {
  let text = "x::a😀::::y"[1:10]
  let iter = @string.split(text, "::")
  assert_eq(iter.next(), Some(""))
  guard iter.next() is Some(field) else { fail("Missing second field") }
  assert_eq(field, "a😀")
  assert_eq(field.start_offset(), 3)
  assert_eq(iter.collect(), ["", ""])
  for needle in ["", "::", "a😀", "?", "😀"] {
    assert_eq(
      @string.split(text, needle).collect(),
      text.split(needle).collect(),
    )
    assert_eq(@string.split_once(text, needle), text.split_once(needle))
    assert_eq(@string.rev_split_once(text, needle), text.rev_split_once(needle))
  }
  assert_eq(@string.split("", ",").collect(), [""])
  assert_true(@string.split("", "").collect().is_empty())
}

///|
test "replacement keeps core labels and matches empty, overlapping and partial inputs" {
  let text = "xa😀a😀aa!".exact_view(start=1, end=9)
  for old in ["", "a", "😀", "aa", "a😀", "absent"] {
    for new in ["", "中", "--"] {
      assert_eq(@string.replace(text, old~, new~), text.replace(old~, new~))
      assert_eq(
        @string.replace_all(text, old~, new~),
        text.replace_all(old~, new~),
      )
    }
  }
  assert_eq(@string.replace_all("aaaaa", old="aa", new="x"), "xxa")
  assert_eq(@string.replace_all("😀中", old="", new="/"), "/😀/中/")
  assert_eq(@string.replace_all("", old="", new="/"), "/")
  assert_eq(@string.replace_all(text, old="absent", new="x").start_offset(), 1)
}

///|
test "core parsers and regex types are usable through the compatible package" {
  assert_eq(@string.parse_int("FF", radix=16), 255)
  assert_eq(@string.parse_uint64("18446744073709551615"), 0xFFFFFFFFFFFFFFFFUL)
  assert_eq(@string.parse_double("1.5"), 1.5)
  assert_true(@string.parse_bool("true"))
  assert_eq(@string.parse_bigint("100000").to_string(), "100000")
  let signed : Int64 = @string.from_str("-123")
  assert_eq(signed, -123)
  let regex : @core_string.Regex = @string.Regex("(?<animal>猫)")
  guard regex.execute("小猫") is Some(match_result) else {
    fail("Missing match")
  }
  let same_type : @string.MatchResult = match_result
  assert_eq(same_type.content(), "猫")
  assert_eq(same_type.named_group("animal"), Some("猫"))
}
