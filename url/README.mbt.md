# URL

Portable WHATWG URL parsing and form query parameters, ported from Ada.

```mbt check
///|
test {
  let url = @url.parse("HTTPS://Example.COM:443/a/../b?q=hello world")
  assert_eq(url.href(), "https://example.com/b?q=hello%20world")
  assert_eq(url.join("../next").href(), "https://example.com/next")
}
```

```mbt check
///|
test {
  let params = @url.SearchParams::parse("a=hello+world&a=second")
  assert_eq(params.get_all("a"), ["hello world", "second"])
  params.set("a", "one & two")
  assert_eq(params.to_string(), "a=one+%26+two")
}
```
