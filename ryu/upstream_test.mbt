///|
/// Checks exact strings and parse bits against one pinned external reference dataset.
fn check_vectors(data : String) -> Unit raise {
  guard @json.parse(data) is Array(records) else {
    fail("Expected an oracle array")
  }
  for record in records {
    guard record
      is [String(kind), String(hex), Number(precision, ..), String(expected)] else {
      fail("Expected a complete oracle record")
    }
    let bits = @string.parse_uint64(hex, radix=16)
    match kind {
      "D" => assert_eq(@ryu.d2s(bits.reinterpret_as_double()), expected)
      "F" =>
        assert_eq(
          @ryu.f2s(Float::reinterpret_from_uint(bits.to_uint())),
          expected,
        )
      "X" =>
        assert_eq(
          @ryu.d2fixed(
            bits.reinterpret_as_double(),
            precision=precision.to_int(),
          ),
          expected,
        )
      "E" =>
        assert_eq(
          @ryu.d2exp(bits.reinterpret_as_double(), precision=precision.to_int()),
          expected,
        )
      "P" => assert_eq(@ryu.s2d(expected).reinterpret_as_uint64(), bits)
      "Q" => assert_eq(@ryu.s2f(expected).reinterpret_as_uint(), bits.to_uint())
      _ => fail("Unknown oracle operation")
    }
  }
}

///|
test "complete upstream expected vectors retain exact strings and bits" {
  check_vectors(upstream_vectors)
}

///|
test "deterministic shortest decimals match the pinned C reference" {
  check_vectors(oracle_shortest_vectors)
}

///|
test "deterministic Printf decimals match the pinned C reference" {
  check_vectors(oracle_printf_vectors)
}

///|
test "deterministic parsed bits match the pinned C reference" {
  check_vectors(oracle_parser_vectors)
}
