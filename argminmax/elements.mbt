///|
/// Dispatches Byte searches to bounded vectors or the scalar contract.
pub impl Element for Byte with fn find_extrema(
  data,
  minimum~,
  maximum~,
  propagate_nan~,
  simd~,
) {
  dispatch_find(data, minimum~, maximum~, propagate_nan~, simd~)
}

///|
/// Specifies the number of packed numeric lanes.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Byte with fn lanes() {
  16
}

///|
/// Preserves the low lane bits without numeric rounding.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Byte with fn word(value) {
  value.to_uint64()
}

///|
/// Recovers a scalar value from one packed numeric lane.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Byte with fn from_word(word) {
  word.to_byte()
}

///|
/// Compares numeric lanes in their signed, unsigned, or floating order.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Byte with fn less(left, right) {
  @simd.i8x16_lt_u(left, right)
}

///|
/// Dispatches Int8 searches to bounded vectors or the scalar contract.
pub impl Element for Int8 with fn find_extrema(
  data,
  minimum~,
  maximum~,
  propagate_nan~,
  simd~,
) {
  dispatch_find(data, minimum~, maximum~, propagate_nan~, simd~)
}

///|
/// Specifies the number of packed numeric lanes.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Int8 with fn lanes() {
  16
}

///|
/// Preserves the low lane bits without numeric rounding.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Int8 with fn word(value) {
  value.to_bits().to_uint64()
}

///|
/// Recovers a scalar value from one packed numeric lane.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Int8 with fn from_word(word) {
  Int8::from_bits(word.to_byte())
}

///|
/// Compares numeric lanes in their signed, unsigned, or floating order.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Int8 with fn less(left, right) {
  @simd.i8x16_lt_s(left, right)
}

///|
/// Dispatches UInt16 searches to bounded vectors or the scalar contract.
pub impl Element for UInt16 with fn find_extrema(
  data,
  minimum~,
  maximum~,
  propagate_nan~,
  simd~,
) {
  dispatch_find(data, minimum~, maximum~, propagate_nan~, simd~)
}

///|
/// Specifies the number of packed numeric lanes.
#cfg(any(target="native", target="wasm"))
impl VectorElement for UInt16 with fn lanes() {
  8
}

///|
/// Preserves the low lane bits without numeric rounding.
#cfg(any(target="native", target="wasm"))
impl VectorElement for UInt16 with fn word(value) {
  value.to_uint64()
}

///|
/// Recovers a scalar value from one packed numeric lane.
#cfg(any(target="native", target="wasm"))
impl VectorElement for UInt16 with fn from_word(word) {
  word.to_uint16()
}

///|
/// Compares numeric lanes in their signed, unsigned, or floating order.
#cfg(any(target="native", target="wasm"))
impl VectorElement for UInt16 with fn less(left, right) {
  @simd.i16x8_lt_u(left, right)
}

///|
/// Dispatches Int16 searches to bounded vectors or the scalar contract.
pub impl Element for Int16 with fn find_extrema(
  data,
  minimum~,
  maximum~,
  propagate_nan~,
  simd~,
) {
  dispatch_find(data, minimum~, maximum~, propagate_nan~, simd~)
}

///|
/// Specifies the number of packed numeric lanes.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Int16 with fn lanes() {
  8
}

///|
/// Preserves the low lane bits without numeric rounding.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Int16 with fn word(value) {
  value.reinterpret_as_uint16().to_uint64()
}

///|
/// Recovers a scalar value from one packed numeric lane.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Int16 with fn from_word(word) {
  Int16::reinterpret_from_uint16(word.to_uint16())
}

///|
/// Compares numeric lanes in their signed, unsigned, or floating order.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Int16 with fn less(left, right) {
  @simd.i16x8_lt_s(left, right)
}

///|
/// Dispatches UInt searches to bounded vectors or the scalar contract.
pub impl Element for UInt32 with fn find_extrema(
  data,
  minimum~,
  maximum~,
  propagate_nan~,
  simd~,
) {
  dispatch_find(data, minimum~, maximum~, propagate_nan~, simd~)
}

///|
/// Specifies the number of packed numeric lanes.
#cfg(any(target="native", target="wasm"))
impl VectorElement for UInt32 with fn lanes() {
  4
}

///|
/// Preserves the low lane bits without numeric rounding.
#cfg(any(target="native", target="wasm"))
impl VectorElement for UInt32 with fn word(value) {
  value.to_uint64()
}

///|
/// Recovers a scalar value from one packed numeric lane.
#cfg(any(target="native", target="wasm"))
impl VectorElement for UInt32 with fn from_word(word) {
  word.to_uint()
}

///|
/// Compares numeric lanes in their signed, unsigned, or floating order.
#cfg(any(target="native", target="wasm"))
impl VectorElement for UInt32 with fn less(left, right) {
  @simd.i32x4_lt_u(left, right)
}

///|
/// Dispatches Int searches to bounded vectors or the scalar contract.
pub impl Element for Int32 with fn find_extrema(
  data,
  minimum~,
  maximum~,
  propagate_nan~,
  simd~,
) {
  dispatch_find(data, minimum~, maximum~, propagate_nan~, simd~)
}

///|
/// Specifies the number of packed numeric lanes.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Int32 with fn lanes() {
  4
}

///|
/// Preserves the low lane bits without numeric rounding.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Int32 with fn word(value) {
  value.reinterpret_as_uint().to_uint64()
}

///|
/// Recovers a scalar value from one packed numeric lane.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Int32 with fn from_word(word) {
  word.to_uint().reinterpret_as_int()
}

///|
/// Compares numeric lanes in their signed, unsigned, or floating order.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Int32 with fn less(left, right) {
  @simd.i32x4_lt_s(left, right)
}

///|
/// Dispatches UInt64 searches to bounded vectors or the scalar contract.
pub impl Element for UInt64 with fn find_extrema(
  data,
  minimum~,
  maximum~,
  propagate_nan~,
  simd~,
) {
  dispatch_find(data, minimum~, maximum~, propagate_nan~, simd~)
}

///|
/// Specifies the number of packed numeric lanes.
#cfg(any(target="native", target="wasm"))
impl VectorElement for UInt64 with fn lanes() {
  2
}

///|
/// Preserves the low lane bits without numeric rounding.
#cfg(any(target="native", target="wasm"))
impl VectorElement for UInt64 with fn word(value) {
  value
}

///|
/// Recovers a scalar value from one packed numeric lane.
#cfg(any(target="native", target="wasm"))
impl VectorElement for UInt64 with fn from_word(word) {
  word
}

///|
/// Compares numeric lanes in their signed, unsigned, or floating order.
#cfg(any(target="native", target="wasm"))
impl VectorElement for UInt64 with fn less(left, right) {
  @simd.i64x2_lt_s(
    @simd.v128_xor(left, @simd.i64x2_splat(0x8000000000000000UL)),
    @simd.v128_xor(right, @simd.i64x2_splat(0x8000000000000000UL)),
  )
}

///|
/// Dispatches Int64 searches to bounded vectors or the scalar contract.
pub impl Element for Int64 with fn find_extrema(
  data,
  minimum~,
  maximum~,
  propagate_nan~,
  simd~,
) {
  dispatch_find(data, minimum~, maximum~, propagate_nan~, simd~)
}

///|
/// Specifies the number of packed numeric lanes.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Int64 with fn lanes() {
  2
}

///|
/// Preserves the low lane bits without numeric rounding.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Int64 with fn word(value) {
  value.reinterpret_as_uint64()
}

///|
/// Recovers a scalar value from one packed numeric lane.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Int64 with fn from_word(word) {
  word.reinterpret_as_int64()
}

///|
/// Compares numeric lanes in their signed, unsigned, or floating order.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Int64 with fn less(left, right) {
  @simd.i64x2_lt_s(left, right)
}

///|
/// Dispatches Float searches to bounded vectors or the scalar contract.
pub impl Element for Float with fn find_extrema(
  data,
  minimum~,
  maximum~,
  propagate_nan~,
  simd~,
) {
  dispatch_find(data, minimum~, maximum~, propagate_nan~, simd~)
}

///|
/// Classifies NaNs before numeric comparisons for Float elements.
pub impl Element for Float with fn is_nan(value) {
  Float::is_nan(value)
}

///|
/// Specifies the number of packed numeric lanes.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Float with fn lanes() {
  4
}

///|
/// Preserves the low lane bits without numeric rounding.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Float with fn word(value) {
  value.reinterpret_as_uint().to_uint64()
}

///|
/// Recovers a scalar value from one packed numeric lane.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Float with fn from_word(word) {
  Float::reinterpret_from_uint(word.to_uint())
}

///|
/// Compares numeric lanes in their signed, unsigned, or floating order.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Float with fn less(left, right) {
  @simd.f32x4_lt(left, right)
}

///|
/// Marks non-NaN lanes without relying on NaN payload ordering.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Float with fn ordered(value) {
  @simd.f32x4_eq(value, value)
}

///|
/// Dispatches Double searches to bounded vectors or the scalar contract.
pub impl Element for Double with fn find_extrema(
  data,
  minimum~,
  maximum~,
  propagate_nan~,
  simd~,
) {
  dispatch_find(data, minimum~, maximum~, propagate_nan~, simd~)
}

///|
/// Classifies NaNs before numeric comparisons for Double elements.
pub impl Element for Double with fn is_nan(value) {
  Double::is_nan(value)
}

///|
/// Specifies the number of packed numeric lanes.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Double with fn lanes() {
  2
}

///|
/// Preserves the low lane bits without numeric rounding.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Double with fn word(value) {
  value.reinterpret_as_uint64()
}

///|
/// Recovers a scalar value from one packed numeric lane.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Double with fn from_word(word) {
  word.reinterpret_as_double()
}

///|
/// Compares numeric lanes in their signed, unsigned, or floating order.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Double with fn less(left, right) {
  @simd.f64x2_lt(left, right)
}

///|
/// Marks non-NaN lanes without relying on NaN payload ordering.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Double with fn ordered(value) {
  @simd.f64x2_eq(value, value)
}

///|
/// Dispatches Float16 searches to bounded vectors or the scalar contract.
pub impl Element for Float16 with fn find_extrema(
  data,
  minimum~,
  maximum~,
  propagate_nan~,
  simd~,
) {
  dispatch_find(data, minimum~, maximum~, propagate_nan~, simd~)
}

///|
/// Classifies NaNs before numeric comparisons for Float16 elements.
pub impl Element for Float16 with fn is_nan(value) {
  Float16::is_nan(value)
}

///|
/// Specifies the number of packed numeric lanes.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Float16 with fn lanes() {
  8
}

///|
/// Preserves the low lane bits without numeric rounding.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Float16 with fn word(value) {
  half_order(value.to_bits()).to_uint16().to_uint64()
}

///|
/// Recovers a scalar value from one packed numeric lane.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Float16 with fn from_word(word) {
  Float16::from_bits(half_bits(word.to_uint16()))
}

///|
/// Compares numeric lanes in their signed, unsigned, or floating order.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Float16 with fn less(left, right) {
  @simd.i16x8_lt_s(left, right)
}

///|
/// Marks non-NaN lanes without relying on NaN payload ordering.
#cfg(any(target="native", target="wasm"))
impl VectorElement for Float16 with fn ordered(value) {
  @simd.i16x8_lt_u(@simd.i16x8_abs(value), @simd.i16x8_splat(0x7c01))
}

///|
/// Dispatches BFloat16 searches to bounded vectors or the scalar contract.
pub impl Element for BFloat16 with fn find_extrema(
  data,
  minimum~,
  maximum~,
  propagate_nan~,
  simd~,
) {
  dispatch_find(data, minimum~, maximum~, propagate_nan~, simd~)
}

///|
/// Classifies NaNs before numeric comparisons for BFloat16 elements.
pub impl Element for BFloat16 with fn is_nan(value) {
  BFloat16::is_nan(value)
}

///|
/// Specifies the number of packed numeric lanes.
#cfg(any(target="native", target="wasm"))
impl VectorElement for BFloat16 with fn lanes() {
  8
}

///|
/// Preserves the low lane bits without numeric rounding.
#cfg(any(target="native", target="wasm"))
impl VectorElement for BFloat16 with fn word(value) {
  half_order(value.to_bits()).to_uint16().to_uint64()
}

///|
/// Recovers a scalar value from one packed numeric lane.
#cfg(any(target="native", target="wasm"))
impl VectorElement for BFloat16 with fn from_word(word) {
  BFloat16::from_bits(half_bits(word.to_uint16()))
}

///|
/// Compares numeric lanes in their signed, unsigned, or floating order.
#cfg(any(target="native", target="wasm"))
impl VectorElement for BFloat16 with fn less(left, right) {
  @simd.i16x8_lt_s(left, right)
}

///|
/// Marks non-NaN lanes without relying on NaN payload ordering.
#cfg(any(target="native", target="wasm"))
impl VectorElement for BFloat16 with fn ordered(value) {
  @simd.i16x8_lt_u(@simd.i16x8_abs(value), @simd.i16x8_splat(0x7f81))
}
