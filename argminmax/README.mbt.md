# ArgMinMax checked examples

The indices are relative to the view, with first-index ties.

```mbt check
///|
test "extrema indices and partial views" {
  let values = [3, -2, 9, -2]
  assert_eq(@argminmax.argminmax(values), Some((1, 2)))
  assert_eq(@argminmax.argminmax(values[2:]), Some((1, 0)))
  assert_eq(@argminmax.argmin(([] : Array[Int32])), None)
}
```

NaN propagation and Arrow validity bitmaps retain original indices.

```mbt check
///|
test "NaN policies and valid elements" {
  let values = [1.0, @double.not_a_number, -3.0]
  assert_eq(@argminmax.argminmax(values), Some((2, 0)))
  assert_eq(@argminmax.nanargminmax(values), Some((1, 1)))
  assert_eq(@argminmax.argminmax_masked([-5, 3, 9, 4], b"\x06"), Some((1, 2)))
}
```
