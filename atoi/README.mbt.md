# Checked examples

```mbt check
///|
test "signed limits and prefix byte counts" {
  let minimum : Int64 = @atoi.parse(b"-9223372036854775808")
  assert_eq(minimum, -9223372036854775808L)
  let prefix : (UInt64, Int32) = @atoi.parse_prefix(
    b"+000000000000000000001234tail",
    skip_zeroes=true,
    skip_plus=true,
  )
  assert_eq(prefix, (1234UL, 25))
}
```

```mbt check
///|
test "exact 128-bit decimal output" {
  let maximum : @atoi.UInt128 = @atoi.parse(
    b"340282366920938463463374607431768211455",
  )
  assert_eq(maximum.to_words(), (0xFFFFFFFFFFFFFFFFUL, 0xFFFFFFFFFFFFFFFFUL))
  let minimum : @atoi.Int128 = @atoi.parse(
    b"-170141183460469231731687303715884105728",
  )
  assert_eq(minimum.to_string(), "-170141183460469231731687303715884105728")
}
```
