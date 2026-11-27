# StringZilla search for MoonBit

Search, compare, split, and replace with core-compatible `StringView`
signatures and UTF-16 offsets. Long searches on native and linear-memory Wasm
screen 32 candidates at a time, using up to three probes to reject repetitive
candidates before exact matching.

In CI, a 65,536-code-unit search with a match at the end was 21–41% faster
than MoonBit core on native and 22–63% faster on linear-memory Wasm.
[Guide](README.md) · [Benchmarks](BENCHMARK.md)

```mbt check
///|
test "UTF-16 offsets" {
  let input = "x猫😀::犬y"[1:7]
  assert_eq(@string.find(input, "::"), Some(3))
  assert_eq(@string.rev_find_code_unit(input, 0xDE00), Some(2))
}
```

```mbt check
///|
test "view replacement" {
  assert_eq(@string.replace_all("a::b::c", old="::", new="|"), "a|b|c")
}
```
