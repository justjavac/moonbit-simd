///|
/// Returns named absolute inputs and independently checked canonical results.
/// Each tuple contains a workload label, its input, and the WHATWG serialized URL;
/// long inputs are constructed outside timed callbacks and all callers use this inventory.
pub fn absolute_cases() -> Array[(String, String, String)] {
  let long = "https://example.com/" +
    "segment/".repeat(512) +
    "?x=" +
    "value".repeat(256)
  [
    ("short", "https://example.com/", "https://example.com/"),
    (
      "ascii", "https://example.com/products/widgets?sort=asc&page=2#details", "https://example.com/products/widgets?sort=asc&page=2#details",
    ),
    ("long", long, long),
    (
      "normalize", "HTTP://EXAMPLE.com:80/a/../b/./c?x=1", "http://example.com/b/c?x=1",
    ),
    (
      "unicode", "https://例子.测试/你好?城市=北京#片段", "https://xn--fsqu00a.xn--0zwm56d/%E4%BD%A0%E5%A5%BD?%E5%9F%8E%E5%B8%82=%E5%8C%97%E4%BA%AC#%E7%89%87%E6%AE%B5",
    ),
    ("ipv4", "http://192.168.1.1:8080/a?b=c", "http://192.168.1.1:8080/a?b=c"),
    (
      "ipv6", "http://[2001:db8::1]:8080/a?b=c", "http://[2001:db8::1]:8080/a?b=c",
    ),
    (
      "file", "file:///C:/Users/Alice/Documents/a.txt", "file:///C:/Users/Alice/Documents/a.txt",
    ),
    (
      "credentials", "https://alice:p%40ss@example.com:8443/a?b=c#d", "https://alice:p%40ss@example.com:8443/a?b=c#d",
    ),
  ]
}

///|
/// Returns the shared pre-parsed relative-resolution base as a String.
pub fn base_url() -> String {
  "https://example.com/a/b/index.html?old=1"
}

///|
/// Returns named relative inputs and their expected results against base_url().
pub fn relative_cases() -> Array[(String, String, String)] {
  [
    ("path", "../next?x=1#top", "https://example.com/a/next?x=1#top"),
    (
      "query", "?q=hello world", "https://example.com/a/b/index.html?q=hello%20world",
    ),
    ("authority", "//other.example/x", "https://other.example/x"),
  ]
}

///|
/// Returns a canonical form query with duplicate names, Unicode, and encoded delimiters.
pub fn form_input() -> String {
  "name=hello+world&name=second&empty=&unicode=%E4%BD%A0%E5%A5%BD&escaped=%26%3D"
}

///|
/// Validates a library's adapters against the shared independently normalized corpus.
/// Parsing failures abort the test through the adapter; every serialized result must match.
pub fn[A] verify(
  parse_ : (StringView) -> A,
  href : (A) -> String,
  resolve : (StringView) -> A,
  form : (String) -> String,
) -> Unit raise {
  for (_, input, expected) in absolute_cases() {
    assert_eq(href(parse_(input)), expected)
  }
  for (_, input, expected) in relative_cases() {
    assert_eq(href(resolve(input)), expected)
  }
  let input = form_input()
  assert_eq(form(input), input)
}

///|
/// Measures absolute parsing and parse-plus-serialization with identical inputs.
/// Input generation and subviews are outside timing; adapter calls and keep barriers are inside.
pub fn[A] absolute_bench(
  bench : @bench.T,
  implementation : String,
  parse_ : (StringView) -> A,
  href : (A) -> String,
) -> Unit {
  for (label, input, _) in absolute_cases() {
    let offsets = if label == "short" || label == "long" { [0, 1] } else { [0] }
    for offset in offsets {
      let source = if offset == 0 { input } else { "_" + input }
      let view = source[offset:]
      let bytes = @utf8.encode(view).length()
      for roundtrip in [false, true] {
        let workload = if roundtrip {
          "roundtrip-" + label
        } else {
          "parse-" + label
        }
        bench.bench(name="\{workload}:\{implementation}:\{bytes}:\{offset}", () => {
          let value = parse_(view)
          if roundtrip {
            bench.keep(href(value))
          } else {
            bench.keep(value)
          }
        })
      }
    }
  }
}

///|
/// Measures relative parsing and serialization using a base prepared by the caller.
/// Each callback includes resolution and its API adapter; base construction is not timed.
pub fn[A] relative_bench(
  bench : @bench.T,
  implementation : String,
  resolve : (StringView) -> A,
  href : (A) -> String,
) -> Unit {
  for (label, input, _) in relative_cases() {
    let bytes = @utf8.encode(input).length()
    for roundtrip in [false, true] {
      let workload = if roundtrip {
        "resolve-roundtrip-" + label
      } else {
        "resolve-" + label
      }
      bench.bench(name="\{workload}:\{implementation}:\{bytes}:0", () => {
        let value = resolve(input)
        if roundtrip {
          bench.keep(href(value))
        } else {
          bench.keep(value)
        }
      })
    }
  }
}

///|
/// Measures decoded form query parsing and serialization, including required input conversion.
pub fn form_bench(
  bench : @bench.T,
  implementation : String,
  form : (String) -> String,
) -> Unit {
  let input = form_input()
  bench.bench(name="form-roundtrip:\{implementation}:\{input.length()}:0", () => {
    bench.keep(form(input))
  })
}
