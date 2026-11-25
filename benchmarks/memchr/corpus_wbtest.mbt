///|
/// Describes a prepared byte-search workload and its optional materialized views.
priv struct ByteInput {
  label : String
  data : Bytes
  partial : Bool
}

///|
/// Supplies empty/short/tail/large byte scans with absent or final-position matches.
fn byte_inputs() -> Array[ByteInput] {
  [
    { label: "empty", data: b"", partial: false, },
    {
      label: "short-hit",
      data: Bytes::make(14, 128) + b"\x00",
      partial: false,
    },
    { label: "short-miss", data: Bytes::make(15, 128), partial: false, },
    { label: "tail-hit", data: Bytes::make(64, 128) + b"\x00", partial: false, },
    { label: "scan-miss", data: Bytes::make(4096, 128), partial: true, },
    {
      label: "scan-hit",
      data: Bytes::make(4095, 128) + b"\x00",
      partial: true,
    },
    {
      label: "huge-hit",
      data: Bytes::make(1048575, 128) + b"\x00",
      partial: false,
    },
  ]
}

///|
/// Supplies full owned views and offset-one/fifteen views with matching sentinels.
fn views(data : Bytes, partial : Bool) -> Array[(BytesView, Int32)] {
  let result = [(data[:], 0)]
  if partial {
    for offset in [1, 15] {
      let backing = Bytes::make(offset, 0) + data + Bytes::make(17, 0)
      result.push((backing[offset:offset + data.length()], offset))
    }
  }
  result
}

///|
/// Describes each byte-search direction and union size without changing input.
fn byte_operations() -> Array[(String, Int32, Bool)] {
  [
    ("memchr1", 1, false),
    ("memrchr1", 1, true),
    ("memchr2", 2, false),
    ("memrchr2", 2, true),
    ("memchr3", 3, false),
    ("memrchr3", 3, true),
  ]
}

///|
/// Selects a core baseline only where core provides the same single-byte operation.
fn byte_implementations(arity : Int32) -> Array[String] {
  if arity == 1 {
    ["own-scalar", "own-simd", "reference", "core"]
  } else {
    ["own-scalar", "own-simd", "reference"]
  }
}

///|
/// Checks membership independently of production word and vector masks.
#inline
fn reference_member(byte : Byte, arity : Int32) -> Bool {
  byte == 0 || (arity >= 2 && byte == 1) || (arity == 3 && byte == 2)
}

///|
/// Computes directional byte matches with an independent per-byte loop.
fn reference_byte(data : BytesView, arity : Int32, reverse : Bool) -> Int32 {
  for offset in 0..<data.length() {
    let index = if reverse { data.length() - offset - 1 } else { offset }
    if reference_member(data[index], arity) {
      return index
    }
  }
  -1
}

///|
/// Adapts equivalent public byte APIs to one observable index, retaining dispatch cost.
fn search_byte(
  data : BytesView,
  arity : Int32,
  reverse : Bool,
  implementation : String,
) -> Int32 {
  if implementation == "reference" {
    return reference_byte(data, arity, reverse)
  }
  if implementation == "core" {
    return (if reverse { data.rev_find(b"\x00") } else { data.find(b"\x00") }).unwrap_or(
      -1,
    )
  }
  let simd = implementation == "own-simd"
  (match (arity, reverse) {
    (1, false) => @bytesearch.memchr(0, data, simd~)
    (1, true) => @bytesearch.memrchr(0, data, simd~)
    (2, false) => @bytesearch.memchr2(0, 1, data, simd~)
    (2, true) => @bytesearch.memrchr2(0, 1, data, simd~)
    (_, false) => @bytesearch.memchr3(0, 1, 2, data, simd~)
    (_, true) => @bytesearch.memrchr3(0, 1, 2, data, simd~)
  }).unwrap_or(-1)
}

///|
/// Supplies full-scan count and iterator workloads with independently known density.
fn iteration_inputs() -> Array[(String, Bytes, Int32, Bool)] {
  [
    ("count1-dense", Bytes::make(65536, 0), 1, true),
    (
      "count3-dense",
      Bytes::makei(65536, index => (index % 3).to_byte()),
      3,
      true,
    ),
    ("iter1-dense", Bytes::make(4096, 0), 1, false),
    (
      "iter3-sparse",
      Bytes::makei(4096, index => {
        if index % 101 == 0 {
          (index % 3).to_byte()
        } else {
          128
        }
      }),
      3,
      false,
    ),
  ]
}

///|
/// Computes an independent count or sum of all matching positions without allocation.
fn reference_iteration(data : BytesView, arity : Int32, count : Bool) -> Int32 {
  let mut result = 0
  for index, byte in data {
    if reference_member(byte, arity) {
      result = result + (if count { 1 } else { index })
    }
  }
  result
}

///|
/// Includes cursor creation and complete consumption in the public iteration adapter.
fn iterate_bytes(
  data : BytesView,
  arity : Int32,
  count : Bool,
  implementation : String,
) -> Int32 {
  if implementation == "reference" {
    return reference_iteration(data, arity, count)
  }
  let simd = implementation == "own-simd"
  let cursor = if arity == 1 {
    @bytesearch.memchr_iter(0, data, simd~)
  } else {
    @bytesearch.memchr3_iter(0, 1, 2, data, simd~)
  }
  if count {
    cursor.count()
  } else {
    cursor.iter().fold(init=0, (total, index) => total + index)
  }
}

///|
/// Describes a prepared substring workload, exact needle, and view offsets.
priv struct SubstringInput {
  label : String
  data : Bytes
  needle : Bytes
  partial : Bool
}

///|
/// Supplies one-byte-boundary, short, long, periodic, and 257-byte needle workloads.
fn substring_inputs() -> Array[SubstringInput] {
  let long = b"ab".repeat(32) + b"z"
  let wide = Bytes::makei(256, index => index.to_byte()) + b"\x00"
  [
    { label: "empty", data: b"\x00\xC3\xA9\xFF", needle: b"", partial: false, },
    {
      label: "short-hit",
      data: b"x".repeat(12) + b"abc",
      needle: b"abc",
      partial: false,
    },
    {
      label: "scan-miss",
      data: b"x".repeat(4096),
      needle: b"abc",
      partial: false,
    },
    {
      label: "scan-hit",
      data: b"x".repeat(4093) + b"abc",
      needle: b"abc",
      partial: true,
    },
    {
      label: "long-hit",
      data: b"x".repeat(8192 - long.length()) + long,
      needle: long,
      partial: false,
    },
    {
      label: "periodic-miss",
      data: b"ab".repeat(2048),
      needle: b"ab".repeat(16) + b"z",
      partial: false,
    },
    {
      label: "wide-hit",
      data: Bytes::make(16384 - wide.length(), 128) + wide,
      needle: wide,
      partial: false,
    },
  ]
}

///|
/// Provides Two-Way alone for forward searches and core for both search directions.
fn substring_implementations(reverse : Bool) -> Array[String] {
  if reverse {
    ["own-scalar", "own-simd", "core"]
  } else {
    ["own-scalar", "own-simd", "own-twoway", "core"]
  }
}

///|
/// Adapts one-off substring search including preprocessing and public-call overhead.
fn search_substring(
  data : BytesView,
  needle : BytesView,
  reverse : Bool,
  implementation : String,
) -> Int32 {
  if implementation == "core" {
    return (if reverse { data.rev_find(needle) } else { data.find(needle) }).unwrap_or(
      -1,
    )
  }
  let simd = implementation == "own-simd"
  if reverse {
    @memmem.rfind(data, needle, simd~).unwrap_or(-1)
  } else {
    @memmem.find(
      data,
      needle,
      simd~,
      prefilter=if implementation == "own-twoway" {
        @memmem.None
      } else {
        @memmem.Auto
      },
    ).unwrap_or(-1)
  }
}

///|
/// Verifies a substring candidate independently with one equality per byte.
fn reference_at(data : BytesView, needle : BytesView, index : Int32) -> Bool {
  for position in 0..<needle.length() {
    if data[index + position] != needle[position] {
      return false
    }
  }
  true
}

///|
/// Computes directional substring matches with an independent candidate loop.
fn reference_substring(
  data : BytesView,
  needle : BytesView,
  reverse : Bool,
) -> Int32 {
  if needle.length() > data.length() {
    return -1
  }
  for offset in 0..<=(data.length() - needle.length()) {
    let position = if reverse {
      data.length() - needle.length() - offset
    } else {
      offset
    }
    if reference_at(data, needle, position) {
      return position
    }
  }
  -1
}

///|
/// Supplies non-overlap and empty-boundary iteration inputs without text conversion.
fn substring_iteration_inputs() -> Array[(String, Bytes, Bytes)] {
  [
    ("overlap", Bytes::makei(4096, index => b"ababa "[index % 6]), b"aba"),
    ("empty", Bytes::makei(256, index => index.to_byte()), b""),
  ]
}

///|
/// Sums independent non-overlapping match offsets without constructing result arrays.
fn reference_substring_iteration(
  data : BytesView,
  needle : BytesView,
  reverse : Bool,
) -> Int32 {
  if needle.is_empty() {
    return data.length() * (data.length() + 1) / 2
  }
  let mut total = 0
  let mut cursor = if reverse { data.length() } else { 0 }
  for ;; {
    let index = reference_substring(
      if reverse {
        data[:cursor]
      } else {
        data[cursor:]
      },
      needle,
      reverse,
    )
    if index < 0 {
      break total
    }
    if reverse {
      total = total + index
      cursor = index
    } else {
      total = total + cursor + index
      cursor = cursor + index + needle.length()
    }
  }
}

///|
/// Includes finder/cursor construction and lazy non-overlapping consumption in timing.
fn iterate_substrings(
  data : BytesView,
  needle : BytesView,
  reverse : Bool,
  implementation : String,
) -> Int32 {
  if implementation == "reference" {
    return reference_substring_iteration(data, needle, reverse)
  }
  let simd = implementation == "own-simd"
  if reverse {
    @memmem.rfind_iter(data, needle, simd~)
    .iter()
    .fold(init=0, (total, index) => total + index)
  } else {
    @memmem.find_iter(data, needle, simd~)
    .iter()
    .fold(init=0, (total, index) => total + index)
  }
}

///|
test "all byte-search and iteration adapters agree with independent public results" {
  for input in byte_inputs() {
    for (data, _) in views(input.data, input.partial) {
      for (_, arity, reverse) in byte_operations() {
        let expected = reference_byte(data, arity, reverse)
        for implementation in byte_implementations(arity) {
          assert_eq(search_byte(data, arity, reverse, implementation), expected)
        }
      }
    }
  }
  for (_, data, arity, count) in iteration_inputs() {
    let expected = reference_iteration(data, arity, count)
    for implementation in ["own-scalar", "own-simd", "reference"] {
      assert_eq(iterate_bytes(data, arity, count, implementation), expected)
    }
  }
}

///|
test "one-off and reused substring adapters preserve canonical byte offsets" {
  for input in substring_inputs() {
    for (data, _) in views(input.data, input.partial) {
      for reverse in [false, true] {
        let expected = reference_substring(data, input.needle, reverse)
        for implementation in substring_implementations(reverse) {
          assert_eq(
            search_substring(data, input.needle, reverse, implementation),
            expected,
          )
          let simd = implementation == "own-simd"
          assert_eq(
            @memmem.Finder::new(
              input.needle,
              simd~,
              prefilter=if implementation == "own-twoway" {
                @memmem.None
              } else {
                @memmem.Auto
              },
            )
            .find(data)
            .unwrap_or(-1),
            reference_substring(data, input.needle, false),
          )
          assert_eq(
            @memmem.FinderRev::new(input.needle, simd~)
            .rfind(data)
            .unwrap_or(-1),
            reference_substring(data, input.needle, true),
          )
        }
      }
    }
  }
  for (_, data, needle) in substring_iteration_inputs() {
    for reverse in [false, true] {
      let expected = reference_substring_iteration(data, needle, reverse)
      for implementation in ["own-scalar", "own-simd", "reference"] {
        assert_eq(
          iterate_substrings(data, needle, reverse, implementation),
          expected,
        )
      }
    }
  }
}
