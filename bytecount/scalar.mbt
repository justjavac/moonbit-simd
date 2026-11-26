///|
/// Counts byte matches in a range already bounded by the input view.
#inline
fn count_bytes(
  buffer : Bytes,
  start : Int32,
  end : Int32,
  needle : Byte,
) -> Int32 {
  for i = start, total = 0; i < end; {
    continue i + 1, total + (buffer.unsafe_get(i) == needle).to_int()
  } nobreak {
    total
  }
}

///|
/// Counts non-continuation bytes in a range already bounded by the input view.
#inline
fn count_chars(buffer : Bytes, start : Int32, end : Int32) -> Int32 {
  for i = start, total = 0; i < end; {
    continue i + 1, total + (buffer.unsafe_get(i).to_int() >> 6 != 2).to_int()
  } nobreak {
    total
  }
}

///|
/// Counts byte matches in eight-byte groups using bytecount's exact SWAR mask.
#cfg(not(target="js"))
fn count_words(data : BytesView, needle : Byte) -> Int32 {
  let buffer = data.data()
  let start = data.start_offset()
  let end = start + data.length()
  let ones = 0x0101010101010101UL
  let needles = needle.to_uint64() * ones
  let low = 0x7F7F7F7F7F7F7F7FUL
  for i = start, total = 0; i <= end - 8; {
    let difference = buffer.unsafe_read_uint64_le(i) ^ needles
    // The addition stays within each lane and sets its high bit for 1..127.
    let flags = ((((difference & low) + low) | difference) >> 7).lnot() & ones
    continue i + 8, total + ((flags * ones) >> 56).to_int()
  } nobreak {
    total + count_bytes(buffer, i, end, needle)
  }
}

///|
/// Counts UTF-8 non-continuation bytes in eight-byte groups using SWAR.
#cfg(not(target="js"))
fn num_chars_words(data : BytesView) -> Int32 {
  let buffer = data.data()
  let start = data.start_offset()
  let end = start + data.length()
  let ones = 0x0101010101010101UL
  for i = start, total = 0; i <= end - 8; {
    let word = buffer.unsafe_read_uint64_le(i)
    // A lane contributes one when its high bit is clear or its next bit is set.
    let flags = ((word >> 7).lnot() | (word >> 6)) & ones
    continue i + 8, total + ((flags * ones) >> 56).to_int()
  } nobreak {
    total + count_chars(buffer, i, end)
  }
}
