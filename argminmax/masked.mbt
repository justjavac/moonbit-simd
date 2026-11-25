///|
/// A validity bitmap does not describe the requested input range.
/// Masked searches raise this before reading values or bitmap bits. `offset`
/// counts bits relative to the supplied bitmap view, whose bits are numbered
/// least-significant first. Length calculations use `Int64` to avoid overflow.
#derive(Eq, Debug)
pub(all) suberror BitmapError {
  /// The requested bit offset was negative.
  InvalidOffset(Int32)
  /// The bitmap view has fewer than the required number of bits.
  InsufficientBits(required~ : Int64, available~ : Int64)
}

///|
/// Validates a bitmap range in wide arithmetic before inspecting any element.
fn check_bitmap(
  length : Int32,
  validity : BytesView,
  offset : Int32,
) -> Unit raise BitmapError {
  if offset < 0 {
    raise InvalidOffset(offset)
  }
  let required = offset.to_int64() + length.to_int64()
  let available = validity.length().to_int64() * 8L
  if required > available {
    raise InsufficientBits(required~, available~)
  }
}

///|
/// Reads a checked Arrow bit using separately bounded byte and bit arithmetic.
fn valid_bit(
  validity : BytesView,
  base_byte : Int32,
  base_bit : Int32,
  index : Int32,
) -> Bool {
  // offset and index are nonnegative Int32 values. Their byte parts sum
  // to at most 536870910, with a carry of at most one; no Int32 sum wraps.
  let shift = base_bit + (index & 7)
  let byte = base_byte + (index >> 3) + (shift >> 3)
  (validity[byte].to_int() & (1 << (shift & 7))) != 0
}

///|
/// Enables explicit valid-run vector requests on vector-capable backends.
#cfg(any(target="native", target="wasm"))
fn bitmap_vectors_available() -> Bool {
  true
}

///|
/// Keeps bitmap requests in the direct scalar loop on scalar-only backends.
#cfg(not(any(target="native", target="wasm")))
fn bitmap_vectors_available() -> Bool {
  false
}

///|
/// Scans valid elements directly without creating a view or result for each run.
fn[T : Element] scalar_masked_find(
  data : ArrayView[T],
  validity : BytesView,
  base_byte : Int32,
  base_bit : Int32,
  minimum~ : Bool,
  maximum~ : Bool,
  propagate_nan~ : Bool,
) -> (Int32, Int32)? {
  let mut first_valid = -1
  let mut first_numeric = -1
  for i in 0..<data.length() {
    if !valid_bit(validity, base_byte, base_bit, i) {
      continue
    }
    if first_valid < 0 {
      first_valid = i
    }
    if data[i].is_nan() {
      if propagate_nan {
        return Some((i, i))
      }
    } else {
      first_numeric = i
      break
    }
  }
  guard first_numeric >= 0 else {
    return if first_valid >= 0 {
      Some((first_valid, first_valid))
    } else {
      None
    }
  }
  let mut low = first_numeric
  let mut high = first_numeric
  let mut low_value = data[first_numeric]
  let mut high_value = low_value
  for i in (first_numeric + 1)..<data.length() {
    if !valid_bit(validity, base_byte, base_bit, i) {
      continue
    }
    let value = data[i]
    if value.is_nan() {
      if propagate_nan {
        return Some((i, i))
      }
    } else if minimum && value < low_value {
      low = i
      low_value = value
    } else if maximum && value > high_value {
      high = i
      high_value = value
    }
  }
  Some((low, high))
}

///|
/// Selects a direct scalar scan or searches and merges explicit vector-request runs.
fn[T : Element] masked_find(
  data : ArrayView[T],
  validity : BytesView,
  offset~ : Int32,
  minimum~ : Bool,
  maximum~ : Bool,
  propagate_nan~ : Bool,
  simd~ : Bool?,
) -> (Int32, Int32)? raise BitmapError {
  check_bitmap(data.length(), validity, offset)
  let base_byte = offset >> 3
  let base_bit = offset & 7
  if simd != Some(true) || !bitmap_vectors_available() {
    return scalar_masked_find(
      data,
      validity,
      base_byte,
      base_bit,
      minimum~,
      maximum~,
      propagate_nan~,
    )
  }
  let mut cursor = 0
  let mut first_valid : Int32? = None
  let mut found : (Int32, Int32)? = None
  while cursor < data.length() {
    if !valid_bit(validity, base_byte, base_bit, cursor) {
      cursor += 1
      continue
    }
    let start = cursor
    if first_valid is None {
      first_valid = Some(start)
    }
    while cursor < data.length() &&
          valid_bit(validity, base_byte, base_bit, cursor) {
      cursor += 1
    }
    // Views retain original values, including signed zero and NaN payloads.
    let result = T::find_extrema(
      data[start:cursor],
      minimum~,
      maximum~,
      propagate_nan~,
      simd~,
    )
    guard result is Some((local_low, local_high)) else { continue }
    let low = start + local_low
    let high = start + local_high
    let candidate = if minimum { low } else { high }
    if data[candidate].is_nan() {
      if propagate_nan {
        return Some((candidate, candidate))
      }
      // An all-NaN run is valid, but cannot replace a numeric candidate.
      continue
    }
    match found {
      None => found = Some((low, high))
      Some((previous_low, previous_high)) => {
        let next_low = if minimum && data[low] < data[previous_low] {
          low
        } else {
          previous_low
        }
        let next_high = if maximum && data[high] > data[previous_high] {
          high
        } else {
          previous_high
        }
        found = Some((next_low, next_high))
      }
    }
  }
  match found {
    Some(_) => found
    None => first_valid.map(index => (index, index))
  }
}

///|
/// Returns extrema indices while skipping nulls marked by an Arrow bitmap.
/// Element `i` is valid iff bit `offset + i` of `validity` is set; the least
/// significant bit comes first. `offset` is relative to the bitmap view and
/// independent of the data view's start. Results retain original data-view
/// indices; first ties and NaN ignoring match `argminmax`. No valid elements
/// returns `None`; all valid elements NaN returns their first valid index twice.
/// Negative offsets or insufficient bitmap bits raise `BitmapError`, including
/// for empty input, before reads. Neither input is mutated or copied. `simd`
/// requests the ordinary element kernel within contiguous valid runs; sparse
/// masks use short scalar runs. Omission and `simd=false` use a direct scalar
/// scan without per-run views or results. Scalar-only backends use that same
/// direct scan even for `simd=true`. Bitmap positioning uses overflow-safe
/// byte/bit arithmetic after wide validation; bitmap scanning is scalar.
///
/// ```mbt check
/// test {
///   assert_eq(@argminmax.argminmax_masked([-5, 3, 9, 4], b"\x06"), Some((1, 2)))
/// }
/// ```
pub fn[T : Element] argminmax_masked(
  data : ArrayView[T],
  validity : BytesView,
  offset~ : Int32 = 0,
  simd? : Bool,
) -> (Int32, Int32)? raise BitmapError {
  masked_find(
    data,
    validity,
    offset~,
    minimum=true,
    maximum=true,
    propagate_nan=false,
    simd~,
  )
}

///|
/// Returns the first valid minimum index, ignoring NaNs and preserving view indices.
/// Bitmap bits, first ties, all-null/NaN behavior, read-only ownership, SIMD
/// requests, and `BitmapError` validation match `argminmax_masked`.
/// Tracks only the minimum within each valid run.
/// Automatic single-extremum searches are scalar.
pub fn[T : Element] argmin_masked(
  data : ArrayView[T],
  validity : BytesView,
  offset~ : Int32 = 0,
  simd? : Bool,
) -> Int32? raise BitmapError {
  masked_find(
    data,
    validity,
    offset~,
    minimum=true,
    maximum=false,
    propagate_nan=false,
    simd~,
  ).map(result => result.0)
}

///|
/// Returns the first valid maximum index, ignoring NaNs and preserving view indices.
/// Bitmap bits, first ties, all-null/NaN behavior, read-only ownership, SIMD
/// requests, and `BitmapError` validation match `argminmax_masked`.
/// Tracks only the maximum within each valid run.
/// Automatic single-extremum searches are scalar.
pub fn[T : Element] argmax_masked(
  data : ArrayView[T],
  validity : BytesView,
  offset~ : Int32 = 0,
  simd? : Bool,
) -> Int32? raise BitmapError {
  masked_find(
    data,
    validity,
    offset~,
    minimum=false,
    maximum=true,
    propagate_nan=false,
    simd~,
  ).map(result => result.1)
}

///|
/// Returns valid extrema, or the first valid NaN index in both components.
/// Null NaNs are skipped. Every NaN payload/sign follows the first-index rule.
/// Bitmap semantics, empty/all-null behavior, validation errors, ownership,
/// view-relative indices, and backend fallbacks match `argminmax_masked`.
pub fn[T : Element] nanargminmax_masked(
  data : ArrayView[T],
  validity : BytesView,
  offset~ : Int32 = 0,
  simd? : Bool,
) -> (Int32, Int32)? raise BitmapError {
  masked_find(
    data,
    validity,
    offset~,
    minimum=true,
    maximum=true,
    propagate_nan=true,
    simd~,
  )
}

///|
/// Returns the first valid NaN index, otherwise the first valid minimum index.
/// Nulls, bitmap offsets, errors, immutable inputs, first ties, view-relative
/// indices, and SIMD/fallback behavior match `nanargminmax_masked`.
/// Automatic single-extremum searches are scalar.
pub fn[T : Element] nanargmin_masked(
  data : ArrayView[T],
  validity : BytesView,
  offset~ : Int32 = 0,
  simd? : Bool,
) -> Int32? raise BitmapError {
  masked_find(
    data,
    validity,
    offset~,
    minimum=true,
    maximum=false,
    propagate_nan=true,
    simd~,
  ).map(result => result.0)
}

///|
/// Returns the first valid NaN index, otherwise the first valid maximum index.
/// Nulls, bitmap offsets, errors, immutable inputs, first ties, view-relative
/// indices, and SIMD/fallback behavior match `nanargminmax_masked`.
/// Automatic single-extremum searches are scalar.
pub fn[T : Element] nanargmax_masked(
  data : ArrayView[T],
  validity : BytesView,
  offset~ : Int32 = 0,
  simd? : Bool,
) -> Int32? raise BitmapError {
  masked_find(
    data,
    validity,
    offset~,
    minimum=false,
    maximum=true,
    propagate_nan=true,
    simd~,
  ).map(result => result.1)
}
