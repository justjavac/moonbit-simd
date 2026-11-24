///|
/// Replaces unpaired JSON Unicode escapes with Web IDL's scalar replacement.
fn fixture_json(data : String) -> Json raise {
  let output = StringBuilder(capacity=data.length())
  let mut i = 0
  let mut copied = 0
  while i < data.length() {
    if data[i] == 92 && i + 1 < data.length() && data[i + 1] == 92 {
      i += 2
      continue
    }
    if data[i] == 92 && i + 5 < data.length() && data[i + 1] == 117 {
      let unit = json_hex_unit(data, i + 2)
      if unit >= 0xD800 && unit <= 0xDBFF {
        if i + 11 < data.length() &&
          data[i + 6] == 92 &&
          data[i + 7] == 117 &&
          json_hex_unit(data, i + 8) >= 0xDC00 &&
          json_hex_unit(data, i + 8) <= 0xDFFF {
          i += 12
        } else {
          output.write_view(data[copied:i])
          output.write_string("\\uFFFD")
          i += 6
          copied = i
        }
        continue
      } else if unit >= 0xDC00 && unit <= 0xDFFF {
        output.write_view(data[copied:i])
        output.write_string("\\uFFFD")
        i += 6
        copied = i
        continue
      }
    }
    i += 1
  }
  output.write_view(data[copied:])
  @json.parse(output.to_string())
}

///|
/// Reads four hexadecimal code units from a checked JSON escape.
fn json_hex_unit(data : String, start : Int32) -> Int32 {
  let mut value = 0
  for i in start..<(start + 4) {
    let c = data[i].to_int()
    let digit = if c >= 48 && c <= 57 {
      c - 48
    } else if c >= 65 && c <= 70 {
      c - 55
    } else if c >= 97 && c <= 102 {
      c - 87
    } else {
      return -1
    }
    value = (value << 4) | digit
  }
  value
}

///|
/// Reads the serialized WHATWG getter corresponding to an upstream fixture field.
fn fixture_property(url : @url.Url, key : String) -> String {
  match key {
    "href" => url.href()
    "origin" => url.origin()
    "protocol" => url.protocol().to_owned()
    "username" => url.username().to_owned()
    "password" => url.password().to_owned()
    "host" => url.host().to_owned()
    "hostname" => url.hostname().to_owned()
    "port" => url.port().to_owned()
    "pathname" => url.pathname().to_owned()
    "search" => url.search().to_owned()
    "hash" => url.hash().to_owned()
    _ => ""
  }
}

///|
/// Tests every URL fixture against both scalar and SIMD requests and counts all failures.
fn check_url_fixtures(data : String) -> Unit raise {
  guard fixture_json(data) is Array(cases) else {
    fail("URL fixture must be an array")
  }
  let mut failed = 0
  let mut checked = 0
  for entry in cases {
    guard entry is Object(fields) else { continue }
    guard fields.get("input") is Some(String(input)) else {
      fail("Missing fixture input")
    }
    for simd in [false, true] {
      let result = match fields.get("base") {
        Some(String(base)) =>
          if @url.try_parse(base, simd~) is Some(previous) {
            @url.try_parse(input, base=previous, simd~)
          } else {
            None
          }
        _ => @url.try_parse(input, simd~)
      }
      checked += 1
      if fields.get("failure") is Some(True) {
        if result is Some(value) {
          failed += 1
          if failed <= 160 && !simd {
            println("Unexpected success: \{input.escape()} -> \{value.href()}")
          }
        }
        continue
      }
      guard result is Some(value) else {
        failed += 1
        if failed <= 160 && !simd {
          println(
            "Unexpected failure: \{input.escape()} base=\{Repr(fields.get("base"))}",
          )
        }
        continue
      }
      for (key, expected) in fields {
        if expected is String(text) &&
          [
            "href", "origin", "protocol", "username", "password", "host", "hostname",
            "port", "pathname", "search", "hash",
          ].contains(key) {
          let actual = fixture_property(value, key)
          if actual != text {
            failed += 1
            if failed <= 160 && !simd {
              println(
                "\{input.escape()} \{key}: got \{actual.escape()}, expected \{text.escape()}",
              )
            }
          }
        }
      }
    }
  }
  println("Checked \{checked} URL cases; \{failed} failures")
  assert_eq(failed, 0)
}

///|
/// Applies the upstream setter name using the public MoonBit API.
fn fixture_setter(url : @url.Url, key : String, value : String) -> Unit raise {
  match key {
    "href" => ignore(url.set_href(value))
    "protocol" => ignore(url.set_protocol(value))
    "username" => ignore(url.set_username(value))
    "password" => ignore(url.set_password(value))
    "host" => ignore(url.set_host(value))
    "hostname" => ignore(url.set_hostname(value))
    "port" => ignore(url.set_port(value))
    "pathname" => ignore(url.set_pathname(value))
    "search" => url.set_search(value)
    "hash" => url.set_hash(value)
    _ => fail("Unknown fixture setter: \{key}")
  }
}

///|
/// Validates every getter expectation after each upstream component-setter case.
fn check_setter_fixtures(data : String) -> Unit raise {
  guard fixture_json(data) is Object(groups) else {
    fail("Setter fixture must be an object")
  }
  let mut failed = 0
  let mut checked = 0
  for (setter, group) in groups {
    if setter == "comment" {
      continue
    }
    guard group is Array(cases) else { fail("Setter group must be an array") }
    for entry in cases {
      guard entry
        is {
          "href": String(href),
          "new_value": String(input),
          "expected": Object(expected),
          ..
        } else {
        fail("Malformed setter fixture")
      }
      let value = @url.parse(href)
      fixture_setter(value, setter, input)
      checked += 1
      for (key, wanted) in expected {
        if wanted is String(text) {
          let actual = fixture_property(value, key)
          if actual != text {
            failed += 1
            if failed <= 35 {
              println(
                "\{href.escape()} set \{setter}=\{input.escape()} \{key}: got \{actual.escape()}, expected \{text.escape()}",
              )
            }
          }
        }
      }
    }
  }
  println("Checked \{checked} setter cases; \{failed} failures")
  assert_eq(failed, 0)
}

///|
test "WHATWG URL fixtures from pinned Ada" {
  check_url_fixtures(wpt_url_data)
}

///|
test "Ada additional URL fixtures" {
  check_url_fixtures(ada_url_data)
}

///|
test "Ada long Unicode URL fixture on every backend" {
  check_url_fixtures(long_url_data)
}

///|
test "JavaScript surrogate URL fixtures" {
  check_url_fixtures(javascript_url_data)
}

///|
test "deterministic differential fixtures from Node URL" {
  check_url_fixtures(node_oracle_data)
}

///|
test "WHATWG setter fixtures from pinned Ada" {
  check_setter_fixtures(wpt_setter_data)
}

///|
test "Ada additional setter fixtures" {
  check_setter_fixtures(ada_setter_data)
}

///|
/// Validates upstream IDNA results with complete failure accounting.
fn check_ascii_fixtures(data : String) -> Unit raise {
  guard fixture_json(data) is Array(cases) else {
    fail("ASCII fixture must be an array")
  }
  let mut failed = 0
  let mut checked = 0
  for entry in cases {
    guard entry is { "input": String(input), "output": wanted, .. } else {
      continue
    }
    let result = Some(@url.domain_to_ascii(input)) catch { _ => None }
    let expected = match wanted {
      String(text) => Some(text)
      _ => None
    }
    checked += 1
    if result != expected {
      failed += 1
      if failed <= 35 {
        println(
          "IDNA \{input.escape()}: got \{Repr(result)}, expected \{Repr(expected)}",
        )
      }
    }
  }
  println("Checked \{checked} domain-to-ASCII cases; \{failed} failures")
  assert_eq(failed, 0)
}

///|
test "WHATWG domain-to-ASCII fixtures from pinned Ada" {
  check_ascii_fixtures(wpt_ascii_data)
}

///|
test "Ada complete IDNA Test V2 fixture" {
  check_ascii_fixtures(idna_v2_data)
}

///|
test "DNS length fixtures are an explicit check after URL parsing" {
  guard fixture_json(dns_length_data) is Array(cases) else {
    fail("DNS fixture must be an array")
  }
  for entry in cases {
    guard entry is { "input": String(input), "failure": failure, .. } else {
      continue
    }
    let url = @url.parse(input)
    let expected = !(failure is True)
    assert_eq(@url.verify_dns_length(url.hostname()), expected)
  }
}
