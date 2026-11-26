///|
/// Counts byte matches in four-byte groups on JavaScript for longer inputs.
fn count_fast(data : BytesView, needle : Byte) -> Int32 {
  let length = data.length()
  if length < 128 {
    return naive_count(data, needle)
  }
  let buffer = data.data()
  let start = data.start_offset()
  let end = start + length
  let ones = 0x01010101U
  let needles = needle.to_int().reinterpret_as_uint() * ones
  let low = 0x7F7F7F7FU
  for i = start, total = 0; i <= end - 4; {
    let difference = buffer.unsafe_read_uint32_le(i) ^ needles
    // Masking the high bits prevents carries between the four byte lanes.
    let flags = ((((difference & low) + low) | difference) >> 7).lnot() & ones
    continue i + 4, total + ((flags * ones) >> 24).reinterpret_as_int()
  } nobreak {
    total + count_bytes(buffer, i, end, needle)
  }
}

///|
/// Counts non-continuation bytes with the JavaScript byte loop.
fn num_chars_fast(data : BytesView) -> Int32 {
  naive_num_chars(data)
}
