///|
/// Selects requested vector processing for complete blocks on linear-memory backends.
#cfg(any(target="native", target="wasm"))
fn update_dispatch(initial : UInt32, data : BytesView, simd : Bool) -> UInt32 {
  if simd && data.length() >= 16 {
    update_simd(initial, data)
  } else {
    update_scalar(initial, data)
  }
}

///|
/// Uses the scalar algorithm on managed-memory and JavaScript backends.
#cfg(not(any(target="native", target="wasm")))
fn update_dispatch(initial : UInt32, data : BytesView, _simd : Bool) -> UInt32 {
  update_scalar(initial, data)
}
