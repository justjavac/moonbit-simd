///|
/// Defines numeric vector operations while keeping public element state separate.
#cfg(any(target="native", target="wasm"))
priv trait VectorElement: Element {
  fn lanes() -> Int32
  fn automatic() -> Bool = _
  fn word(Self) -> UInt64
  fn from_word(UInt64) -> Self
  fn load(ArrayView[Self], Int32) -> V128 = _
  fn splat(Self) -> V128 = _
  fn less(V128, V128) -> V128
  fn greater(V128, V128) -> V128 = _
  fn ordered(V128) -> V128 = _
  fn extract(V128, Int32) -> Self = _
}

///|
/// Keeps automatic vector selection conservative for unmeasured types and native.
#cfg(any(target="native", target="wasm"))
impl VectorElement with fn automatic() {
  false
}

///|
/// Gathers only the proven complete lanes of a typed view into a portable vector.
#cfg(any(target="native", target="wasm"))
impl VectorElement with fn load(data, offset) {
  let half = Self::lanes() / 2
  let width = 64 / half
  let mut low = 0UL
  let mut high = 0UL
  for i in 0..<half {
    low = low | (Self::word(data[offset + i]) << (width * i))
    high = high | (Self::word(data[offset + half + i]) << (width * i))
  }
  @simd.i64x2_replace_lane(@simd.i64x2_splat(low), high, 1)
}

///|
/// Broadcasts a numeric bit representation without converting floating values.
#cfg(any(target="native", target="wasm"))
impl VectorElement with fn splat(value) {
  let word = Self::word(value)
  match Self::lanes() {
    16 => @simd.i8x16_splat(word.to_byte())
    8 => @simd.i16x8_splat(word.to_uint16())
    4 => @simd.i32x4_splat(word.to_uint())
    _ => @simd.i64x2_splat(word)
  }
}

///|
/// Reverses the strict comparison so the same numeric ordering drives both ends.
#cfg(any(target="native", target="wasm"))
impl VectorElement with fn greater(left, right) {
  Self::less(right, left)
}

///|
/// Marks every lane ordered for integer elements.
#cfg(any(target="native", target="wasm"))
impl VectorElement with fn ordered(_value) {
  @simd.i32x4_splat(0xffffffffU)
}

///|
/// Converts a constant-selector lane back to a scalar only during chunk reduction.
#cfg(any(target="native", target="wasm"))
impl VectorElement with fn extract(value, lane) {
  let word = match Self::lanes() {
    16 => byte_lane(value, lane).to_uint64()
    8 => short_lane(value, lane).to_uint64()
    4 => word_lane(value, lane).to_uint64()
    _ => long_lane(value, lane)
  }
  Self::from_word(word)
}

///|
/// Returns an unsigned byte lane using constant intrinsic lane selectors.
#cfg(any(target="native", target="wasm"))
fn byte_lane(value : V128, lane : Int32) -> Byte {
  let word = match lane {
    0 => @simd.i8x16_extract_lane_u(value, 0)
    1 => @simd.i8x16_extract_lane_u(value, 1)
    2 => @simd.i8x16_extract_lane_u(value, 2)
    3 => @simd.i8x16_extract_lane_u(value, 3)
    4 => @simd.i8x16_extract_lane_u(value, 4)
    5 => @simd.i8x16_extract_lane_u(value, 5)
    6 => @simd.i8x16_extract_lane_u(value, 6)
    7 => @simd.i8x16_extract_lane_u(value, 7)
    8 => @simd.i8x16_extract_lane_u(value, 8)
    9 => @simd.i8x16_extract_lane_u(value, 9)
    10 => @simd.i8x16_extract_lane_u(value, 10)
    11 => @simd.i8x16_extract_lane_u(value, 11)
    12 => @simd.i8x16_extract_lane_u(value, 12)
    13 => @simd.i8x16_extract_lane_u(value, 13)
    14 => @simd.i8x16_extract_lane_u(value, 14)
    _ => @simd.i8x16_extract_lane_u(value, 15)
  }
  word.to_byte()
}

///|
/// Returns an unsigned 16-bit lane with constant intrinsic lane selectors.
#cfg(any(target="native", target="wasm"))
fn short_lane(value : V128, lane : Int32) -> UInt16 {
  let word = match lane {
    0 => @simd.i16x8_extract_lane_u(value, 0)
    1 => @simd.i16x8_extract_lane_u(value, 1)
    2 => @simd.i16x8_extract_lane_u(value, 2)
    3 => @simd.i16x8_extract_lane_u(value, 3)
    4 => @simd.i16x8_extract_lane_u(value, 4)
    5 => @simd.i16x8_extract_lane_u(value, 5)
    6 => @simd.i16x8_extract_lane_u(value, 6)
    _ => @simd.i16x8_extract_lane_u(value, 7)
  }
  word.to_uint16()
}

///|
/// Returns an unsigned 32-bit lane with constant intrinsic lane selectors.
#cfg(any(target="native", target="wasm"))
fn word_lane(value : V128, lane : Int32) -> UInt32 {
  match lane {
    0 => @simd.i32x4_extract_lane(value, 0)
    1 => @simd.i32x4_extract_lane(value, 1)
    2 => @simd.i32x4_extract_lane(value, 2)
    _ => @simd.i32x4_extract_lane(value, 3)
  }
}

///|
/// Returns a 64-bit lane with a constant intrinsic selector.
#cfg(any(target="native", target="wasm"))
fn long_lane(value : V128, lane : Int32) -> UInt64 {
  if lane == 0 {
    @simd.i64x2_extract_lane(value, 0)
  } else {
    @simd.i64x2_extract_lane(value, 1)
  }
}

///|
/// Initializes view-relative narrow indices for one overflow-bounded chunk.
#cfg(any(target="native", target="wasm"))
fn initial_indices(lanes : Int32) -> V128 {
  match lanes {
    16 =>
      @simd.i8x16_const(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15)
    8 => @simd.i16x8_const(0, 1, 2, 3, 4, 5, 6, 7)
    4 => @simd.i32x4_const(0U, 1U, 2U, 3U)
    _ => @simd.i64x2_const(0UL, 1UL)
  }
}

///|
/// Advances all chunk-local indices; any final wrap is discarded before reuse.
#cfg(any(target="native", target="wasm"))
fn next_indices(indices : V128, lanes : Int32) -> V128 {
  match lanes {
    16 => @simd.i8x16_add(indices, @simd.i8x16_splat(16))
    8 => @simd.i16x8_add(indices, @simd.i16x8_splat(8))
    4 => @simd.i32x4_add(indices, @simd.i32x4_splat(4U))
    _ => @simd.i64x2_add(indices, @simd.i64x2_splat(2UL))
  }
}

///|
/// Extracts an unsigned chunk-local index without signed narrowing.
#cfg(any(target="native", target="wasm"))
fn index_lane(indices : V128, lane : Int32, lanes : Int32) -> Int32 {
  match lanes {
    16 => byte_lane(indices, lane).to_int()
    8 => short_lane(indices, lane).to_int()
    4 => word_lane(indices, lane).reinterpret_as_int()
    _ => long_lane(indices, lane).to_int()
  }
}

///|
/// Reduces a numeric lane mask to an ascending bitset for first-NaN selection.
#cfg(any(target="native", target="wasm"))
fn lane_mask(mask : V128, lanes : Int32) -> Int32 {
  match lanes {
    16 => @simd.i8x16_bitmask(mask)
    8 => @simd.i16x8_bitmask(mask)
    4 => @simd.i32x4_bitmask(mask)
    _ => @simd.i64x2_bitmask(mask)
  }
}

///|
/// Tracks values and earliest indices in parallel lanes with bounded gathers.
#cfg(any(target="native", target="wasm"))
fn[T : VectorElement] vector_find(
  data : ArrayView[T],
  minimum~ : Bool,
  maximum~ : Bool,
  propagate_nan~ : Bool,
) -> (Int32, Int32)? {
  guard !data.is_empty() else { return None }
  let mut first = 0
  while first < data.length() && Element::is_nan(data[first]) {
    if propagate_nan {
      return Some((first, first))
    }
    first += 1
  }
  guard first < data.length() else { return Some((0, 0)) }
  let lanes = T::lanes()
  // Unsigned 8/16-bit indices restart before their next value would wrap.
  // Int-sized views bound every 32/64-bit index. Limits are lane multiples.
  let limit = match lanes {
    16 => 256
    8 => 65536
    4 => 2147483644
    _ => 2147483646
  }
  let mut low = first
  let mut high = first
  let mut cursor = first + 1
  while data.length() - cursor >= lanes {
    let available = (data.length() - cursor).min(limit)
    let chunk_length = available - available % lanes
    let mut low_values = T::splat(data[low])
    let mut high_values = T::splat(data[high])
    let mut low_indices = @simd.i32x4_splat(0U)
    let mut high_indices = low_indices
    let mut indices = initial_indices(lanes)
    for offset = 0; offset < chunk_length; offset = offset + lanes {
      // cursor + offset + lanes <= data.length(), including partial views.
      let values = T::load(data, cursor + offset)
      let ordered = T::ordered(values)
      if propagate_nan {
        let nan_bits = lane_mask(@simd.v128_not(ordered), lanes)
        if nan_bits != 0 {
          let index = cursor + offset + nan_bits.ctz()
          return Some((index, index))
        }
      }
      if minimum {
        let mask = @simd.v128_and_(T::less(values, low_values), ordered)
        low_values = @simd.v128_bitselect(values, low_values, mask)
        low_indices = @simd.v128_bitselect(indices, low_indices, mask)
      }
      if maximum {
        let mask = @simd.v128_and_(T::greater(values, high_values), ordered)
        high_values = @simd.v128_bitselect(values, high_values, mask)
        high_indices = @simd.v128_bitselect(indices, high_indices, mask)
      }
      indices = next_indices(indices, lanes)
    }
    // Seed lanes that never improved have later indices than the retained
    // global seed, so the strict comparisons and first-tie merge keep it.
    for lane in 0..<lanes {
      if minimum {
        let value = T::extract(low_values, lane)
        let index = cursor + index_lane(low_indices, lane, lanes)
        if value < data[low] || (value == data[low] && index < low) {
          low = index
        }
      }
      if maximum {
        let value = T::extract(high_values, lane)
        let index = cursor + index_lane(high_indices, lane, lanes)
        if value > data[high] || (value == data[high] && index < high) {
          high = index
        }
      }
    }
    cursor += chunk_length
  }
  for i in cursor..<data.length() {
    let value = data[i]
    if Element::is_nan(value) {
      if propagate_nan {
        return Some((i, i))
      }
    } else {
      if minimum && value < data[low] {
        low = i
      }
      if maximum && value > data[high] {
        high = i
      }
    }
  }
  Some((low, high))
}

///|
/// Dispatches a vector request only when at least two full vectors can follow.
#cfg(any(target="native", target="wasm"))
fn[T : VectorElement] dispatch_find(
  data : ArrayView[T],
  minimum~ : Bool,
  maximum~ : Bool,
  propagate_nan~ : Bool,
  simd~ : Bool?,
) -> (Int32, Int32)? {
  let requested = simd.unwrap_or(
    minimum &&
    maximum &&
    !propagate_nan &&
    T::automatic() &&
    data.length() >= 4096,
  )
  if requested && data.length() > T::lanes() * 2 {
    vector_find(data, minimum~, maximum~, propagate_nan~)
  } else {
    scalar_find(data, minimum~, maximum~, propagate_nan~)
  }
}

///|
/// Keeps the same numeric contract on backends without the vector representation.
#cfg(not(any(target="native", target="wasm")))
fn[T : Element] dispatch_find(
  data : ArrayView[T],
  minimum~ : Bool,
  maximum~ : Bool,
  propagate_nan~ : Bool,
  simd~ : Bool?,
) -> (Int32, Int32)? {
  ignore(simd)
  scalar_find(data, minimum~, maximum~, propagate_nan~)
}
