///|
/// Keeps byte views, UTF-16 views, and mutable in-place input separate.
priv enum Input {
  Raw(BytesView)
  Text(StringView)
  Inplace(FixedArray[Byte], Int32)
}

///|
/// Returns a byte count or an encoded ASCII UTF-16 code-unit count.
fn Input::length(self : Input) -> Int32 {
  match self {
    Raw(input) => input.length()
    Text(input) => input.length()
    Inplace(_, length) => length
  }
}

///|
/// Reads one bounded byte or UTF-16 code unit without materializing a view.
#inline
fn Input::at(self : Input, index : Int32) -> Int32 {
  match self {
    Raw(input) => input[index].to_int()
    Text(input) => input[index].to_int()
    Inplace(input, _) => input[index].to_int()
  }
}

///|
/// Checks structural padding and returns effective input length and output size.
fn decoded_shape(
  input : Input,
  padding : Bool,
  forgiving : Bool,
) -> (Int32, Int32) raise Base64Error {
  let length = input.length()
  if length == 0 {
    return (0, 0)
  }
  let stripped = if padding {
    guard length % 4 == 0 else { raise InvalidInput }
    true
  } else {
    forgiving && length % 4 == 0
  }
  let n = if stripped && input.at(length - 1) == '=' {
    length - (if input.at(length - 2) == '=' { 2 } else { 1 })
  } else {
    length
  }
  let remainder = n % 4
  guard remainder != 1 else { raise InvalidInput }
  (n, n / 4 * 3 + (if remainder == 0 { 0 } else { remainder - 1 }))
}

///|
/// Checks a destination range before any writes, without overflowing an offset sum.
fn output_range(
  output : FixedArray[Byte],
  offset : Int32,
  length : Int32,
) -> Unit raise Base64Error {
  guard offset >= 0 &&
    offset <= output.length() &&
    length <= output.length() - offset else {
    raise OutputTooSmall
  }
}

///|
/// Validates the requested mutable input prefix before reading or writing it.
fn inplace_input(
  data : FixedArray[Byte],
  length : Int32?,
) -> Input raise Base64Error {
  let length = length.unwrap_or(data.length())
  guard length >= 0 && length <= data.length() else { raise InvalidInput }
  Inplace(data, length)
}
