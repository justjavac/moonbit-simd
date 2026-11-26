///|
/// Selects checked 12-to-16 byte vector encoding and a scalar remainder.
#cfg(any(target="native", target="wasm"))
fn encode_dispatch(
  input : BytesView,
  output : FixedArray[Byte],
  offset : Int32,
  config : Base64,
  simd : Bool,
) -> Unit {
  if simd && input.length() >= 16 {
    encode_simd(input, output, offset, config)
  } else {
    encode_scalar(input, output, offset, config)
  }
}

///|
/// Retains the same encoding contract on managed and JavaScript backends.
#cfg(not(any(target="native", target="wasm")))
fn encode_dispatch(
  input : BytesView,
  output : FixedArray[Byte],
  offset : Int32,
  config : Base64,
  _simd : Bool,
) -> Unit {
  encode_scalar(input, output, offset, config)
}

///|
/// Selects 16-to-12 character vector decoding or allocation-free validation.
#cfg(any(target="native", target="wasm"))
fn decode_dispatch(
  input : Input,
  length : Int32,
  output : FixedArray[Byte],
  offset : Int32,
  config : Base64,
  forgiving : Bool,
  write : Bool,
  simd : Bool,
) -> Unit raise Base64Error {
  if simd && length >= 16 {
    decode_simd(input, length, output, offset, config, forgiving, write)
  } else {
    decode_scalar(input, 0, length, output, offset, config, forgiving, write)
  }
}

///|
/// Retains strict or forgiving decoding on managed and JavaScript backends.
#cfg(not(any(target="native", target="wasm")))
fn decode_dispatch(
  input : Input,
  length : Int32,
  output : FixedArray[Byte],
  offset : Int32,
  config : Base64,
  forgiving : Bool,
  write : Bool,
  _simd : Bool,
) -> Unit raise Base64Error {
  decode_scalar(input, 0, length, output, offset, config, forgiving, write)
}
