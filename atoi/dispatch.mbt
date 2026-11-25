///|
/// Selects digit scanning on vector-capable backends after bounding the view.
#cfg(any(target="native", target="wasm"))
fn digit_length(data : BytesView, limit : Int32, simd~ : Bool) -> Int32 {
  let bounded = data[:limit]
  if simd {
    vector_digit_length(bounded)
  } else {
    scalar_digit_length(bounded)
  }
}

///|
/// Uses scalar/SWAR digit scanning when this backend has no vector path.
#cfg(not(any(target="native", target="wasm")))
fn digit_length(data : BytesView, limit : Int32, simd~ : Bool) -> Int32 {
  let _ = simd
  scalar_digit_length(data[:limit])
}

///|
/// Reduces a validated vector block, falling back for fewer than sixteen digits.
#cfg(any(target="native", target="wasm"))
fn decimal_group(data : BytesView, simd~ : Bool) -> (UInt64, Int32) {
  if simd {
    match data {
      [v128le(block), ..] => return (reduce_sixteen(block), 16)
      _ => ()
    }
  }
  scalar_decimal_group(data)
}

///|
/// Reduces validated digits through SWAR and scalar tails on other backends.
#cfg(not(any(target="native", target="wasm")))
fn decimal_group(data : BytesView, simd~ : Bool) -> (UInt64, Int32) {
  let _ = simd
  scalar_decimal_group(data)
}
