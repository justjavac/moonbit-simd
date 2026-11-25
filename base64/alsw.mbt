// Adapted from base64-simd/vsimd 0.8.0 at
// d74c030d9dc4f3cae02146d1f497ff62726ef09a. See LICENSE for attribution.

///|
/// Holds the four reusable ALSW (average, lookup, saturated/wrapping add) vectors.
#cfg(any(target="native", target="wasm"))
priv struct Alsw {
  check_hash : V128
  check_offset : V128
  decode_hash : V128
  decode_offset : V128
}

///|
/// Packs a sixteen-byte generated lookup into a vector outside the hot loop.
#cfg(any(target="native", target="wasm"))
fn table_vector(table : FixedArray[Byte]) -> V128 {
  @simd.i8x16_const(
    table[0],
    table[1],
    table[2],
    table[3],
    table[4],
    table[5],
    table[6],
    table[7],
    table[8],
    table[9],
    table[10],
    table[11],
    table[12],
    table[13],
    table[14],
    table[15],
  )
}

///|
/// Derives upstream ALSW offsets from the alphabet instead of retaining opaque tables.
#cfg(any(target="native", target="wasm"))
fn make_alsw(url_safe : Bool) -> Alsw {
  let check_hash = FixedArray::make(16, b'\x00')
  let decode_hash = FixedArray::make(16, b'\x00')
  for i in 0..<16 {
    let check = if url_safe {
      match i {
        0 => 7
        1..<=9 => 2
        10 => 4
        13 => 8
        _ => 6
      }
    } else {
      match i {
        0 => 5
        1..<=9 => 2
        10 => 4
        11 | 15 => 6
        _ => 8
      }
    }
    let decode = if url_safe {
      if i == 15 {
        5
      } else {
        1
      }
    } else {
      match i {
        11 => 7
        15 => 8
        _ => 1
      }
    }
    check_hash[i] = (check * 2 - 1).to_byte()
    decode_hash[i] = (decode * 2 - 1).to_byte()
  }
  let check_offset = FixedArray::make(16, b'\x80')
  let decode_offset = FixedArray::make(16, b'\x80')
  let table = if url_safe { url_decode_table } else { standard_decode_table }
  for step in 0..<256 {
    let code = 255 - step
    let value = table[code].to_int()
    if value != 255 {
      let high = 0xe0 | (code >> 3)
      let check = (high + check_hash[code & 15].to_int() + 1) / 2
      let decode = (high + decode_hash[code & 15].to_int() + 1) / 2
      check_offset[check & 15] = (0 - code).to_byte()
      decode_offset[decode & 15] = (value - code).to_byte()
    }
  }
  {
    check_hash: table_vector(check_hash),
    check_offset: table_vector(check_offset),
    decode_hash: table_vector(decode_hash),
    decode_offset: table_vector(decode_offset),
  }
}

///|
/// Shares the generated standard alphabet's ALSW lookup vectors.
#cfg(any(target="native", target="wasm"))
let standard_alsw : Alsw = make_alsw(false)

///|
/// Shares the generated URL-safe alphabet's ALSW lookup vectors.
#cfg(any(target="native", target="wasm"))
let url_alsw : Alsw = make_alsw(true)

///|
/// Validates all sixteen bytes and translates them to sextets with upstream ALSW.
#cfg(any(target="native", target="wasm"))
#inline
fn decode_values(input : V128, tables : Alsw) -> V128 raise Base64Error {
  let mask = @simd.i8x16_splat(15)
  let low = @simd.v128_and_(input, mask)
  // Neighbour bits contribute multiples of 16 after averaging; the second
  // low-nibble lookup discards them, matching (0xe0 | (c >> 3)) in setup.
  let shifted = @simd.i32x4_shr_u(input, 3)
  let check_hash = @simd.i8x16_avgr_u(
    shifted,
    @simd.i8x16_swizzle(tables.check_hash, low),
  )
  let checked = @simd.i8x16_add_sat_s(
    input,
    @simd.i8x16_swizzle(tables.check_offset, @simd.v128_and_(check_hash, mask)),
  )
  guard @simd.i8x16_bitmask(checked) == 0 else { raise InvalidInput }
  let decode_hash = @simd.i8x16_avgr_u(
    shifted,
    @simd.i8x16_swizzle(tables.decode_hash, low),
  )
  @simd.i8x16_add(
    input,
    @simd.i8x16_swizzle(
      tables.decode_offset,
      @simd.v128_and_(decode_hash, mask),
    ),
  )
}
