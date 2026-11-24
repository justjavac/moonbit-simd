///|
test "component views and independent copies survive atomic replacements" {
  let url = @url.parse("https://alice:secret@example.com:8443/a?x=1#top")
  let view = url.hostname()
  let copy = url.copy()
  assert_true(url.set_hostname("Other.Example"))
  assert_eq(view.to_owned(), "example.com")
  assert_eq(copy.hostname().to_owned(), "example.com")
  assert_eq(url.hostname().to_owned(), "other.example")
  let shared = url
  assert_true(shared.set_pathname("/b"))
  assert_eq(url.pathname().to_owned(), "/b")
  let previous = url.href()
  assert_true(!url.set_href("http://[broken"))
  assert_true(!url.set_protocol("data"))
  assert_true(!url.set_port("65536"))
  assert_eq(url.href(), previous)
  assert_eq(
    url.join("../c").href(),
    "https://alice:secret@other.example:8443/c",
  )
}

///|
test "absent and empty query and fragment remain distinct" {
  let url = @url.parse("https://example.com/?#")
  assert_eq(url.query().map(view => view.to_owned()), Some(""))
  assert_eq(url.fragment().map(view => view.to_owned()), Some(""))
  assert_eq(url.search().to_owned(), "")
  assert_eq(url.hash().to_owned(), "")
  url.set_search("")
  assert_eq(url.href(), "https://example.com/#")
  assert_eq(url.query(), None)
  url.set_hash("")
  assert_eq(url.fragment(), None)
  assert_eq(url.href(), "https://example.com/")
}

///|
test "opaque origins and file roots use WHATWG rules" {
  assert_eq(
    @url.parse("blob:https://example.com/id").origin(),
    "https://example.com",
  )
  assert_eq(@url.parse("blob:ftp://example.com/id").origin(), "null")
  let opaque_url = @url.parse("mailto:alice@example.com?subject=hello")
  assert_eq(opaque_url.origin(), "null")
  assert_true(!opaque_url.set_pathname("/new"))
  assert_true(!@url.can_parse("../new", base=opaque_url))
  assert_eq(
    opaque_url.join("#x").href(),
    "mailto:alice@example.com?subject=hello#x",
  )
  let file = @url.parse("file:///C:/a/b")
  assert_eq(file.join("../../../c").href(), "file:///C:/c")
  assert_eq(file.origin(), "null")
}

///|
test "query parameters preserve duplicates and use detached mutable state" {
  let url = @url.parse(
    "https://example.com/?a=hello+world&a=second&empty&bad=%FF",
  )
  let params = url.search_params()
  assert_eq(params.size(), 4)
  assert_eq(params.get_all("a"), ["hello world", "second"])
  assert_eq(params.get("empty"), Some(""))
  assert_eq(params.get("bad"), Some("\uFFFD"))
  assert_true(params.has("a", value="second"))
  let snapshot = params.entries()
  let copied = params.copy()
  params.set("a", "one & two")
  params.append("z", "")
  params.delete("bad", value="\uFFFD")
  assert_eq(snapshot.to_array().length(), 4)
  assert_eq(copied.get_all("a").length(), 2)
  assert_eq(
    url.query().unwrap().to_owned(),
    "a=hello+world&a=second&empty&bad=%FF",
  )
  url.set_search_params(params)
  assert_eq(url.query().unwrap().to_owned(), "a=one+%26+two&empty=&z=")
  assert_eq(params.keys().to_array(), ["a", "empty", "z"])
  assert_eq(params.values().to_array(), ["one & two", "", ""])
  params.reset("?x=1&x=2&&=v&flag")
  assert_eq(params.to_string(), "x=1&x=2&=v&flag=")
  params.delete("x", value="1")
  assert_eq(params.get("x"), Some("2"))
  params.delete("x")
  assert_true(!params.has("x"))
  params.reset("")
  url.set_search_params(params)
  assert_eq(url.query(), None)
}

///|
test "parameter sorting is stable and compares UTF-16 code units" {
  let params = @url.SearchParams::from_pairs([
    ("\uE000", "one"),
    ("😀", "first"),
    ("a", "x"),
    ("😀", "second"),
    ("a", "y"),
  ])
  params.sort()
  assert_eq(params.keys().to_array(), ["a", "a", "😀", "😀", "\uE000"])
  assert_eq(params.get_all("😀"), ["first", "second"])
  assert_eq(@url.SearchParams::new().size(), 0)
}

///|
test "domain conversion handles Unicode, mapping, and ASCII compatibility" {
  assert_eq(@url.domain_to_ascii("例子.测试"), "xn--fsqu00a.xn--0zwm56d")
  assert_eq(@url.domain_to_unicode("xn--fsqu00a.xn--0zwm56d"), "例子.测试")
  assert_eq(@url.domain_to_ascii("XN--"), "xn--")
  assert_eq(@url.domain_to_ascii("ＦＯＯ。example"), "foo.example")
  assert_eq(@url.domain_to_ascii("x..ß"), "x..xn--zca")
  try @url.domain_to_ascii("a b") catch {
    _ => ()
  } noraise {
    _ => fail("Invalid domain accepted")
  }
}
