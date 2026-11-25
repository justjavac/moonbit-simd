///|
/// Defines the reflected IEEE polynomial used by every implementation.
let polynomial : UInt32 = 0xEDB88320

///|
/// Defines the initial and final XOR of CRC-32/ISO-HDLC.
let xor_mask : UInt32 = 0xFFFFFFFF

///|
/// Holds sixteen consecutive zero-byte transformations for both slicing algorithms.
let slicing_table : FixedArray[UInt32] = make_slicing_table()

///|
/// Derives the slicing tables from the reflected polynomial once at startup.
fn make_slicing_table() -> FixedArray[UInt32] {
  let table = FixedArray::make(16 * 256, 0U)
  for byte in 0..<256 {
    let mut crc = byte.reinterpret_as_uint()
    for _ in 0..<8 {
      let feedback = if (crc & 1) == 0 { 0U } else { polynomial }
      crc = (crc >> 1) ^ feedback
    }
    table[byte] = crc
  }
  for slice in 1..<16 {
    for byte in 0..<256 {
      let previous = table[(slice - 1) * 256 + byte]
      table[slice * 256 + byte] = (previous >> 8) ^
        table[(previous & 0xFF).reinterpret_as_int()]
    }
  }
  table
}

///|
/// Extends a finalized checksum with slicing-by-eight and a bytewise tail.
fn update_scalar(initial : UInt32, data : BytesView) -> UInt32 {
  // Little-endian patterns define the input order independently of the host.
  // Every lookup is a fixed slice in 0..7 plus a byte in 0..255, so its
  // index is below 2048 in the immutable 4096-entry table.
  for rest = data, crc = initial ^ xor_mask {
    match rest {
      [u32le(first), u32le(second), .. tail] => {
        let word = first ^ crc
        let next = slicing_table.unsafe_get(
            7 * 256 + (word & 0xFF).reinterpret_as_int(),
          ) ^
          slicing_table.unsafe_get(
            6 * 256 + ((word >> 8) & 0xFF).reinterpret_as_int(),
          ) ^
          slicing_table.unsafe_get(
            5 * 256 + ((word >> 16) & 0xFF).reinterpret_as_int(),
          ) ^
          slicing_table.unsafe_get(4 * 256 + (word >> 24).reinterpret_as_int()) ^
          slicing_table.unsafe_get(
            3 * 256 + (second & 0xFF).reinterpret_as_int(),
          ) ^
          slicing_table.unsafe_get(
            2 * 256 + ((second >> 8) & 0xFF).reinterpret_as_int(),
          ) ^
          slicing_table.unsafe_get(
            256 + ((second >> 16) & 0xFF).reinterpret_as_int(),
          ) ^
          slicing_table.unsafe_get((second >> 24).reinterpret_as_int())
        continue tail, next
      }
      [byte, .. tail] =>
        continue tail,
          (crc >> 8) ^
          slicing_table.unsafe_get(
            ((crc ^ byte.to_uint()) & 0xFF).reinterpret_as_int(),
          )
      [] => break crc ^ xor_mask
    }
  }
}
