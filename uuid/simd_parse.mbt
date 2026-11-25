///|
/// Reverses bytes within each 64-bit lane to move between wire and word order.
#cfg(target="wasm")
#inline
fn reverse_words(value : V128) -> V128 {
  @simd.i8x16_shuffle(
    value, value, 7, 6, 5, 4, 3, 2, 1, 0, 15, 14, 13, 12, 11, 10, 9, 8,
  )
}

///|
/// Reverses eight bytes using fixed-width swaps without optional byte-shuffle ISA.
#cfg(target="native")
#inline
fn swap_bytes(value : UInt64) -> UInt64 {
  let pairs = ((value & 0x00ff00ff00ff00ffUL) << 8) |
    ((value >> 8) & 0x00ff00ff00ff00ffUL)
  let halves = ((pairs & 0x0000ffff0000ffffUL) << 16) |
    ((pairs >> 16) & 0x0000ffff0000ffffUL)
  (halves << 32) | (halves >> 32)
}

///|
/// Extracts native decoded bytes in network order without a generic byte shuffle.
#cfg(target="native")
#inline
fn uuid_from_lanes(value : V128) -> Uuid {
  {
    high: swap_bytes(@simd.i64x2_extract_lane(value, 0)),
    low: swap_bytes(@simd.i64x2_extract_lane(value, 1)),
  }
}

///|
/// Extracts decoded Wasm bytes in network order with one constant shuffle.
#cfg(target="wasm")
#inline
fn uuid_from_lanes(value : V128) -> Uuid {
  let words = reverse_words(value)
  {
    high: @simd.i64x2_extract_lane(words, 0),
    low: @simd.i64x2_extract_lane(words, 1),
  }
}

///|
/// Computes sixteen nibbles and their exact ASCII hexadecimal validity mask.
#cfg(any(target="native", target="wasm"))
#inline
fn decode_nibbles(value : V128) -> (V128, V128) {
  let digits = @simd.i8x16_sub(value, @simd.i8x16_splat(b'0'))
  let letters = @simd.i8x16_sub(
    @simd.v128_or_(value, @simd.i8x16_splat(0x20)),
    @simd.i8x16_splat(b'a'),
  )
  let is_digit = @simd.i8x16_le_u(digits, @simd.i8x16_splat(9))
  let is_letter = @simd.i8x16_le_u(letters, @simd.i8x16_splat(5))
  (
    @simd.v128_bitselect(
      digits,
      @simd.i8x16_add(letters, @simd.i8x16_splat(10)),
      is_digit,
    ),
    @simd.v128_or_(is_digit, is_letter),
  )
}

///|
/// Merges adjacent high/low nibbles into eight unsigned 16-bit byte lanes.
#cfg(any(target="native", target="wasm"))
#inline
fn merge_nibbles(value : V128) -> V128 {
  @simd.v128_and_(
    @simd.v128_or_(@simd.i16x8_shl(value, 4), @simd.i16x8_shr_u(value, 8)),
    @simd.i16x8_splat(255),
  )
}

///|
/// Validates and decodes two vectors of hexadecimal digits to immutable words.
#cfg(any(target="native", target="wasm"))
fn decode_ascii32(first : V128, second : V128) -> Uuid raise UuidError {
  let (a, valid_a) = decode_nibbles(first)
  let (b, valid_b) = decode_nibbles(second)
  guard @simd.i8x16_bitmask(@simd.v128_and_(valid_a, valid_b)) == 65535 else {
    raise InvalidUuid
  }
  let bytes = @simd.i8x16_narrow_i16x8_u(merge_nibbles(a), merge_nibbles(b))
  uuid_from_lanes(bytes)
}

///|
/// Removes four already-checked hyphens with two constant cross-vector shuffles.
#cfg(target="wasm")
#inline
fn decode_hyphenated(
  first : V128,
  second : V128,
  tail : V128,
) -> Uuid raise UuidError {
  decode_ascii32(
    @simd.i8x16_shuffle(
      first, second, 0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 17,
    ),
    @simd.i8x16_shuffle(
      second, tail, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
    ),
  )
}

///|
/// Removes checked native hyphens by packing known byte fields into vector lanes.
#cfg(target="native")
#inline
fn decode_hyphenated(
  first : V128,
  second : V128,
  tail : V128,
) -> Uuid raise UuidError {
  let a0 = @simd.i64x2_extract_lane(first, 0)
  let a1 = @simd.i64x2_extract_lane(first, 1)
  let b0 = @simd.i64x2_extract_lane(second, 0)
  let b1 = @simd.i64x2_extract_lane(second, 1)
  let end = @simd.i64x2_extract_lane(tail, 0)
  // These fields select input positions 0..7, 9..12, 14..17,
  // then 19..22 and 24..35; checked hyphens never become hex digits.
  let first_high = ((a1 >> 8) & 0xffffffffUL) |
    (a1 >> 48 << 32) |
    ((b0 & 0xffffUL) << 48)
  let second_low = ((b0 >> 24) & 0xffffffffUL) | (b1 << 32)
  let second_high = (b1 >> 32) | ((end & 0xffffffffUL) << 32)
  decode_ascii32(
    @simd.i64x2_const(a0, first_high),
    @simd.i64x2_const(second_low, second_high),
  )
}

///|
/// Loads sixteen checked UTF-16 code units and saturates them to ASCII candidates.
#cfg(any(target="native", target="wasm"))
#inline
fn load_text16(input : StringView, offset : Int32) -> V128 {
  let start = input.start_offset() + offset
  // Saturation maps every non-ASCII code unit outside the accepted hex ranges,
  // including negative signed lanes; truncation could incorrectly accept them.
  @simd.i8x16_narrow_i16x8_u(
    @simd.v128_load_i16x8(input.data(), start),
    @simd.v128_load_i16x8(input.data(), start + 8),
  )
}

///|
/// Decodes a length-checked UTF-16 view without materializing UTF-8 input.
#cfg(any(target="native", target="wasm"))
fn parse_text_simd(
  input : StringView,
  hyphenated : Bool,
) -> Uuid raise UuidError {
  let first = load_text16(input, 0)
  let second = load_text16(input, 16)
  if hyphenated {
    // The final load covers code units 28..35, entirely inside a 36-unit body.
    let last = @simd.i8x16_narrow_i16x8_u(
      @simd.v128_load_i16x8(input.data(), input.start_offset() + 28),
      @simd.i16x8_splat(0),
    )
    let tail = @simd.i32x4_const(@simd.i32x4_extract_lane(last, 1), 0, 0, 0)
    decode_hyphenated(first, second, tail)
  } else {
    decode_ascii32(first, second)
  }
}

///|
/// Decodes checked byte views with bounded vector patterns and a four-byte tail.
#cfg(any(target="native", target="wasm"))
fn parse_bytes_simd(
  input : BytesView,
  hyphenated : Bool,
) -> Uuid raise UuidError {
  if hyphenated {
    guard input is [v128le(first), v128le(second), u32le(tail)] else {
      raise InvalidUuid
    }
    decode_hyphenated(first, second, @simd.i32x4_const(tail, 0, 0, 0))
  } else {
    guard input is [v128le(first), v128le(second)] else { raise InvalidUuid }
    decode_ascii32(first, second)
  }
}
