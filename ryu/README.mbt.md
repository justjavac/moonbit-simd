# Checked Ryu examples

```mbt check
///|
test "shortest formatting preserves source precision" {
  assert_eq(@ryu.d2s(0.3), "3E-1")
  assert_eq(@ryu.f2s(Float::from_double(0.3)), "3E-1")
  assert_eq(
    @ryu.s2d(@ryu.d2s(-0.0)).reinterpret_as_uint64(),
    0x8000000000000000UL,
  )
}
```

```mbt check
///|
test "Printf rounding and scientific exponents" {
  assert_eq(@ryu.d2fixed(0.1, precision=20), "0.10000000000000000555")
  assert_eq(@ryu.d2exp(9.99, precision=1), "1.0e+01")
}
```
