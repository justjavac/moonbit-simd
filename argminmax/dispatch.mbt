///|
/// Uses the measured long-view Wasm policy for binary32 elements.
#cfg(target="wasm")
impl VectorElement for Float with fn automatic() {
  true
}

///|
/// Uses the measured long-view Wasm policy for binary64 elements.
#cfg(target="wasm")
impl VectorElement for Double with fn automatic() {
  true
}
