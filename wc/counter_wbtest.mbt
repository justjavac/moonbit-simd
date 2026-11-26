///|
test "counter accepts the full UInt64 byte total" {
  let counter = Counter::new()
  counter.bytes = 0xFFFFFFFFFFFFFFFEUL
  counter.update(b"x")
  counter.update(b"")
  assert_eq(counter.counts().bytes, 0xFFFFFFFFFFFFFFFFUL)
}

///|
test "panic counter rejects byte total overflow" {
  let counter = Counter::new()
  counter.bytes = 0xFFFFFFFFFFFFFFFFUL
  counter.update(b"\n")
}
