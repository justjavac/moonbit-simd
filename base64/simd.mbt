// The shuffle, split/merge, and encoding-shift algorithms are adapted from
// base64-simd 0.8.0's portable Wasm/NEON paths. See README.md and LICENSE.

///|
/// Loads sixteen bounded bytes, or packs sixteen bounded UTF-16 code units.
#cfg(any(target="native", target="wasm"))
#inline
fn Input::load16(self : Input, offset : Int32) -> V128 {
  match self {
    Raw(input) =>
      match input[offset:] {
        [v128le(block), ..] => block
        _ => abort("Base64 vector load invariant")
      }
    Text(input) => {
      let start = input.start_offset() + offset
      // Signed-to-unsigned saturation maps non-ASCII to either an invalid
      // high byte or zero, never to a valid Base64 character.
      @simd.i8x16_narrow_i16x8_u(
        @simd.v128_load_i16x8(input.data(), start),
        @simd.v128_load_i16x8(input.data(), start + 8),
      )
    }
    Inplace(data, _) => @simd.v128_load(data, offset)
  }
}

///|
/// Splits twelve source bytes into sixteen sextets with portable shifts.
#cfg(any(target="native", target="wasm"))
#inline
fn split_bits(input : V128) -> V128 {
  let shuffled = @simd.i8x16_shuffle(
    input, input, 1, 0, 2, 1, 4, 3, 5, 4, 7, 6, 8, 7, 10, 9, 11, 10,
  )
  let a = @simd.i16x8_shr_u(
    @simd.v128_and_(shuffled, @simd.i32x4_splat(0x0000fc00)),
    10,
  )
  let b = @simd.i16x8_shl(
    @simd.v128_and_(shuffled, @simd.i32x4_splat(0x000003f0)),
    4,
  )
  let c = @simd.i16x8_shr_u(
    @simd.v128_and_(shuffled, @simd.i32x4_splat(0x0fc00000)),
    6,
  )
  let d = @simd.i16x8_shl(
    @simd.v128_and_(shuffled, @simd.i32x4_splat(0x003f0000)),
    8,
  )
  @simd.v128_or_(@simd.v128_or_(a, b), @simd.v128_or_(c, d))
}

///|
/// Selects the RFC 4648 byte shifts using upstream's thirteen-category lookup.
#cfg(any(target="native", target="wasm"))
#inline
fn encoding_shift(url_safe : Bool) -> V128 {
  @simd.i8x16_const(
    71,
    252,
    252,
    252,
    252,
    252,
    252,
    252,
    252,
    252,
    252,
    if url_safe {
      239
    } else {
      237
    },
    if url_safe {
      32
    } else {
      240
    },
    65,
    128,
    128,
  )
}

///|
/// Translates valid sextets to ASCII without per-lane scalar table lookups.
#cfg(any(target="native", target="wasm"))
#inline
fn encode_values(values : V128, shifts : V128) -> V128 {
  let above51 = @simd.i8x16_sub_sat_u(values, @simd.i8x16_splat(51))
  let below26 = @simd.i8x16_lt_s(values, @simd.i8x16_splat(26))
  let indices = @simd.v128_or_(
    above51,
    @simd.v128_and_(below26, @simd.i8x16_splat(13)),
  )
  @simd.i8x16_add(values, @simd.i8x16_swizzle(shifts, indices))
}

///|
/// Encodes 12 bytes per checked 16-byte load, keeping the final input within its view.
#cfg(any(target="native", target="wasm"))
fn encode_simd(
  input : BytesView,
  output : FixedArray[Byte],
  offset : Int32,
  config : Base64,
) -> Unit {
  let shifts = encoding_shift(config.url_safe)
  let source = input.data()
  let start = input.start_offset()
  let last = input.length() - 16
  for i = 0, j = offset; i <= last; i = i + 12, j = j + 16 {
    // The sixteen-byte load stays inside the view, including at unaligned offsets.
    let block = source.unsafe_extract_v128_aligned(start + i)
    @simd.v128_store(output, j, encode_values(split_bits(block), shifts))
  } nobreak {
    encode_scalar(input[i:], output, j, config)
  }
}

///|
/// Merges sixteen sextets into twelve packed bytes with portable lane shifts.
#cfg(any(target="native", target="wasm"))
#inline
fn merge_bits(values : V128) -> V128 {
  let ac = @simd.v128_and_(values, @simd.i32x4_splat(0x003f003f))
  let bd = @simd.v128_and_(values, @simd.i32x4_splat(0x3f003f00))
  let x = @simd.v128_or_(@simd.i32x4_shl(ac, 18), @simd.i32x4_shr_u(ac, 10))
  let y = @simd.v128_or_(@simd.i32x4_shl(bd, 4), @simd.i32x4_shr_u(bd, 24))
  let packed = @simd.v128_and_(
    @simd.v128_or_(x, y),
    @simd.i32x4_splat(0x00ffffff),
  )
  @simd.i8x16_shuffle(
    packed, packed, 2, 1, 0, 6, 5, 4, 10, 9, 8, 14, 13, 12, 3, 3, 3, 3,
  )
}

///|
/// Validates and optionally writes sixteen characters at a time without overstores.
#cfg(any(target="native", target="wasm"))
fn decode_simd(
  input : Input,
  length : Int32,
  output : FixedArray[Byte],
  offset : Int32,
  config : Base64,
  forgiving : Bool,
  write : Bool,
) -> Unit raise Base64Error {
  let tables = if config.url_safe { url_alsw } else { standard_alsw }
  for i = 0; i <= length - 16; i = i + 16 {
    let values = decode_values(input.load16(i), tables)
    if write {
      let packed = merge_bits(values)
      let j = offset + i / 4 * 3
      // Exactly twelve output bytes are available, even for a final vector.
      // Unlike upstream's overlapping 16-byte stores, these never overstore.
      @simd.v128_store64_lane(output, j, packed, 0)
      @simd.v128_store32_lane(output, j + 8, packed, 2)
    }
  } nobreak {
    decode_scalar(
      input,
      i,
      length,
      output,
      offset + i / 4 * 3,
      config,
      forgiving,
      write,
    )
  }
}
