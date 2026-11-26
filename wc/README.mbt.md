# Word counts

```mbt check
///|
test "count lines, words, and bytes" {
  let counts = @wc.count(b"one\ttwo\nthree")
  assert_eq((counts.lines, counts.words, counts.bytes), (1UL, 3UL, 13UL))
}
```

```mbt check
///|
test "count a word across chunks" {
  let counter = @wc.Counter::new()
  counter.update(b"par")
  counter.update(b"tial\nline")
  assert_eq(counter.counts(), @wc.count(b"partial\nline"))
}
```
