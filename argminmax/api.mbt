///|
/// A numeric element supported by the extrema searches.
///
/// Built-in implementations cover `Byte`, `Int16`, `UInt16`, `Int`, `UInt`,
/// `Int64`, `UInt64`, `Float`, and `Double`. This package also provides `Int8`,
/// `Int128`, `UInt128`, `Float16`, and `BFloat16`. Custom implementations can
/// use the default scalar search by implementing this trait and `Compare`.
/// Numeric comparisons must be consistent for non-NaN values.
pub(open) trait Element: Compare {
  /// Reports whether this value is NaN; the default is false for integer types.
  /// Searches never compare values for which this method returns true.
  fn is_nan(Self) -> Bool = _

  /// Searches the read-only view without copying or mutation.
  /// `minimum` and `maximum` select the required extrema; at least one must
  /// be true. The unrequested tuple component is unspecified. Results are
  /// relative to the view and use the first index on ties. Empty input returns
  /// `None`; all-NaN input returns `Some((0, 0))`. `propagate_nan` returns the
  /// first NaN index in both components, regardless of its payload or sign.
  /// `simd=Some(true)` requests vectors and `Some(false)` requests scalar
  /// processing. `None` selects this implementation's automatic policy;
  /// the default implementation is scalar on every backend.
  fn find_extrema(
    ArrayView[Self],
    minimum~ : Bool,
    maximum~ : Bool,
    propagate_nan~ : Bool,
    simd~ : Bool?,
  ) -> (Int32, Int32)? = _
}

///|
/// Provides the non-NaN default for integer and user-defined elements.
impl Element with fn is_nan(_self) {
  false
}

///|
/// Provides scalar extrema searches for types without a vector implementation.
impl Element with fn find_extrema(
  data,
  minimum~,
  maximum~,
  propagate_nan~,
  simd~,
) {
  ignore(simd)
  scalar_find(data, minimum~, maximum~, propagate_nan~)
}

///|
/// Returns the first indices of the minimum and maximum elements in `data`.
///
/// Indices are relative to this view, including when it starts inside an array.
/// Equal values retain their first index; positive and negative zero are equal.
/// NaNs are ignored. A nonempty all-NaN view returns `Some((0, 0))`; an empty
/// view returns `None`. Input and element state are never changed or copied.
/// Omitting `simd` selects vectors on linear-memory Wasm for `Float` and
/// `Double` views of at least 4096 elements, following local measurements.
/// Other automatic searches are scalar. `simd=true` explicitly requests
/// portable vectors on native and Wasm for 8–64-bit elements. Short inputs,
/// 128-bit elements, Wasm GC, and JavaScript use scalar processing. Leading
/// NaNs are skipped scalarly; no CPU-specific instruction set is requested.
///
/// ```mbt check
/// test {
///   assert_eq(@argminmax.argminmax([3, -2, 9, -2]), Some((1, 2)))
/// }
/// ```
pub fn[T : Element] argminmax(
  data : ArrayView[T],
  simd? : Bool,
) -> (Int32, Int32)? {
  T::find_extrema(data, minimum=true, maximum=true, propagate_nan=false, simd~)
}

///|
/// Returns the first minimum index relative to `data`, ignoring NaNs.
/// Empty input returns `None`; nonempty all-NaN input returns `Some(0)`.
/// Equal values, including signed zero, retain the first index. Ownership,
/// mutation, vector requests, and backend fallbacks are the same as `argminmax`.
/// Only the minimum is tracked during the search.
/// Automatic searches are scalar; explicit requests follow `argminmax`.
pub fn[T : Element] argmin(data : ArrayView[T], simd? : Bool) -> Int32? {
  T::find_extrema(data, minimum=true, maximum=false, propagate_nan=false, simd~).map(result => {
      result.0
    },
  )
}

///|
/// Returns the first maximum index relative to `data`, ignoring NaNs.
/// Empty input returns `None`; nonempty all-NaN input returns `Some(0)`.
/// Equal values, including signed zero, retain the first index. Ownership,
/// mutation, vector requests, and backend fallbacks are the same as `argminmax`.
/// Only the maximum is tracked during the search.
/// Automatic searches are scalar; explicit requests follow `argminmax`.
pub fn[T : Element] argmax(data : ArrayView[T], simd? : Bool) -> Int32? {
  T::find_extrema(data, minimum=false, maximum=true, propagate_nan=false, simd~).map(result => {
      result.1
    },
  )
}

///|
/// Returns both extrema indices, or the first NaN index in both components.
/// Unlike NumPy's `nanargmin`, the upstream `nan` prefix means propagate NaNs.
/// The first NaN is guaranteed even for differing payloads, signs, or signaling
/// NaNs. Without NaNs, results match `argminmax`; integers also behave that way.
/// Empty input returns `None`. The input is never mutated or copied. View
/// indices, first ties, SIMD requests, and fallbacks match `argminmax`.
/// Automatic NaN-propagating searches are scalar on every backend.
///
/// ```mbt check
/// test {
///   let values : Array[Double] = [1.0, @double.not_a_number, -3.0]
///   assert_eq(@argminmax.nanargminmax(values), Some((1, 1)))
/// }
/// ```
pub fn[T : Element] nanargminmax(
  data : ArrayView[T],
  simd? : Bool,
) -> (Int32, Int32)? {
  T::find_extrema(data, minimum=true, maximum=true, propagate_nan=true, simd~)
}

///|
/// Returns the first NaN index if present, otherwise the first minimum index.
/// Empty input returns `None`. NaN payload guarantees, read-only ownership,
/// view-relative indices, first ties, and backend fallbacks match `nanargminmax`.
/// Only the minimum is tracked when no NaN is encountered.
/// Automatic searches are scalar; explicit requests follow `nanargminmax`.
pub fn[T : Element] nanargmin(data : ArrayView[T], simd? : Bool) -> Int32? {
  T::find_extrema(data, minimum=true, maximum=false, propagate_nan=true, simd~).map(result => {
      result.0
    },
  )
}

///|
/// Returns the first NaN index if present, otherwise the first maximum index.
/// Empty input returns `None`. NaN payload guarantees, read-only ownership,
/// view-relative indices, first ties, and backend fallbacks match `nanargminmax`.
/// Only the maximum is tracked when no NaN is encountered.
/// Automatic searches are scalar; explicit requests follow `nanargminmax`.
pub fn[T : Element] nanargmax(data : ArrayView[T], simd? : Bool) -> Int32? {
  T::find_extrema(data, minimum=false, maximum=true, propagate_nan=true, simd~).map(result => {
      result.1
    },
  )
}
