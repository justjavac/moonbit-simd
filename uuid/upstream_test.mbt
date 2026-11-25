///|
/// Retains the accepted inputs and expectations from uuid-simd 0.8.0 tests/it.rs.
let upstream_valid : Array[(String, String)] = [
  ("67e5504410b1426f9247bb680e5fe0c8", "67e55044-10b1-426f-9247-bb680e5fe0c8"),
  ("67e5504410b1426f9247bb680e5fe0c8", "67e5504410b1426f9247bb680e5fe0c8"),
  ("67e5504410b1426f9247bb680e5fe0c8", "{67e55044-10b1-426f-9247-bb680e5fe0c8}"),
  (
    "67e5504410b1426f9247bb680e5fe0c8", "urn:uuid:67e55044-10b1-426f-9247-bb680e5fe0c8",
  ),
  ("00000000000000000000000000000000", "00000000000000000000000000000000"),
  ("00000000000000000000000000000000", "00000000-0000-0000-0000-000000000000"),
  ("01020304111221223132414243444546", "01020304-1112-2122-3132-414243444546"),
  ("F9168C5ECEB24faaB6BF329BF39FA1E4", "F9168C5E-CEB2-4faa-B6BF-329BF39FA1E4"),
  ("6d93badebd9f4e1389149474e1e3567b", "{6d93bade-bd9f-4e13-8914-9474e1e3567b}"),
]

///|
/// Retains every malformed upstream test input, including the repeated case.
let upstream_invalid : Array[String] = [
  "", "!", "F9168C5E-CEB2-4faa-B6BF-329BF39FA1E45", "F9168C5E-CEB2-4faa-BBF-329BF39FA1E4",
  "F9168C5E-CEB2-4faa", "{F9168C5E-CEB2-4faa9B6BFF329BF39FA1E41", "67e5504410b1426f9247bb680e5fe0c",
  "67e5504410b1426f9247bb680e5fe0c88", "67e5504410b1426f9247bb680e5fe0cg8", "{00000000000000000000000000000000}",
  "67e5504410b1426f9247bb680e5fe0c", "F9168C5E-CEB2-4faa-B6BF1-02BF39FA1E4", "231231212212423424324323477343246663",
  "01020304-1112-2122-3132-41424344", "F9168C5E-CEB2-4faa-BGBF-329BF39FA1E4", "F9168C5E-CEB2F4faaFB6BFF329BF39FA1E4",
  "F9168C5E-CEB2-4faaFB6BFF329BF39FA1E4", "F9168C5E-CEB2-4faa-B6BFF329BF39FA1E4",
  "F9168C5E-CEB2-4faaXB6BFF329BF39FA1E4", "67e5504410b1426%9247bb680e5fe0c8", "67e550X410b1426f9247bb680e5fe0cd",
  "67e550-4105b1426f9247bb680e5fe0c", "F9168C5E-CEB-24fa-eB6BFF32-BF39FA1E4",
]

///|
test "all upstream accepted and rejected fixtures through both public input types" {
  for algorithm in [@uuid.Scalar, @uuid.Simd] {
    for (expected, input) in upstream_valid {
      assert_eq(
        @uuid.parse(input, algorithm~).format_simple().to_lower(),
        expected.to_lower(),
      )
      assert_eq(
        @uuid.parse_bytes(@utf8.encode(input), algorithm~)
        .format_simple()
        .to_lower(),
        expected.to_lower(),
      )
    }
    for input in upstream_invalid {
      try @uuid.parse(input, algorithm~) catch {
        @uuid.InvalidUuid => ()
        _ => fail("Unexpected upstream text parser error")
      } noraise {
        _ => fail("accepted malformed upstream text")
      }
      try @uuid.parse_bytes(@utf8.encode(input), algorithm~) catch {
        @uuid.InvalidUuid => ()
        _ => fail("Unexpected upstream byte parser error")
      } noraise {
        _ => fail("accepted malformed upstream bytes")
      }
    }
  }
}

///|
test "upstream formatting vectors preserve lower and upper case" {
  for
    (compact, canonical) in [
      (
        "67e5504410b1426f9247bb680e5fe0c8", "67e55044-10b1-426f-9247-bb680e5fe0c8",
      ),
      (
        "01020304111221223132414243444546", "01020304-1112-2122-3132-414243444546",
      ),
      (
        "00000000000000000000000000000000", "00000000-0000-0000-0000-000000000000",
      ),
    ] {
    let id = @uuid.parse(compact)
    for algorithm in [@uuid.Scalar, @uuid.Simd] {
      assert_eq(id.format_simple(algorithm~), compact)
      assert_eq(
        id.format_simple(case=@uuid.Upper, algorithm~),
        compact.to_upper(),
      )
      assert_eq(id.format_hyphenated(algorithm~), canonical)
      assert_eq(
        id.format_hyphenated(case=@uuid.Upper, algorithm~),
        canonical.to_upper(),
      )
    }
  }
}
