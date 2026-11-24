///|
/// Encodes complete triples and a padded or unpadded scalar remainder.
fn encode_scalar(
  input : BytesView,
  output : FixedArray[Byte],
  offset : Int32,
  alphabet : BytesView,
  padding : Bool,
) -> Unit {
  let triples = input.length() / 3
  for group in 0..<triples {
    let i = group * 3
    let j = offset + group * 4
    let bits = (input[i].to_int() << 16) |
      (input[i + 1].to_int() << 8) |
      input[i + 2].to_int()
    output[j] = alphabet[(bits >> 18) & 63]
    output[j + 1] = alphabet[(bits >> 12) & 63]
    output[j + 2] = alphabet[(bits >> 6) & 63]
    output[j + 3] = alphabet[bits & 63]
  }
  let i = triples * 3
  let j = offset + triples * 4
  match input.length() - i {
    1 => {
      let byte = input[i].to_int()
      output[j] = alphabet[byte >> 2]
      output[j + 1] = alphabet[(byte & 3) << 4]
      if padding {
        output[j + 2] = b'='
        output[j + 3] = b'='
      }
    }
    2 => {
      let first = input[i].to_int()
      let second = input[i + 1].to_int()
      output[j] = alphabet[first >> 2]
      output[j + 1] = alphabet[((first & 3) << 4) | (second >> 4)]
      output[j + 2] = alphabet[(second & 15) << 2]
      if padding {
        output[j + 3] = b'='
      }
    }
    _ => ()
  }
}

///|
/// Rejects non-ASCII UTF-16 code units before indexing the byte lookup.
#inline
fn sextet(
  input : Input,
  index : Int32,
  table : FixedArray[Byte],
) -> Int32 raise Base64Error {
  let code = input.at(index)
  guard code < 256 else { raise InvalidInput }
  let value = table[code].to_int()
  guard value != 255 else { raise InvalidInput }
  value
}

///|
/// Decodes or checks complete quartets and canonical tail bits after a vector prefix.
fn decode_scalar(
  input : Input,
  start : Int32,
  length : Int32,
  output : FixedArray[Byte],
  offset : Int32,
  table : FixedArray[Byte],
  forgiving : Bool,
  write : Bool,
) -> Unit raise Base64Error {
  let groups = (length - start) / 4
  for group in 0..<groups {
    let i = start + group * 4
    let x0 = input.at(i)
    let x1 = input.at(i + 1)
    let x2 = input.at(i + 2)
    let x3 = input.at(i + 3)
    guard (x0 | x1 | x2 | x3) < 256 else { raise InvalidInput }
    let a = table[x0].to_int()
    let b = table[x1].to_int()
    let c = table[x2].to_int()
    let d = table[x3].to_int()
    // Valid sextets have only six bits. One sentinel makes the OR exactly
    // 255, combining upstream's quartet validation without per-byte raises.
    guard (a | b | c | d) != 255 else { raise InvalidInput }
    if write {
      let j = offset + group * 3
      output[j] = ((a << 2) | (b >> 4)).to_byte()
      output[j + 1] = ((b << 4) | (c >> 2)).to_byte()
      output[j + 2] = ((c << 6) | d).to_byte()
    }
  }
  let i = start + groups * 4
  let j = offset + groups * 3
  match length - i {
    2 => {
      let a = sextet(input, i, table)
      let b = sextet(input, i + 1, table)
      guard forgiving || (b & 15) == 0 else { raise InvalidInput }
      if write {
        output[j] = ((a << 2) | (b >> 4)).to_byte()
      }
    }
    3 => {
      let a = sextet(input, i, table)
      let b = sextet(input, i + 1, table)
      let c = sextet(input, i + 2, table)
      guard forgiving || (c & 3) == 0 else { raise InvalidInput }
      if write {
        output[j] = ((a << 2) | (b >> 4)).to_byte()
        output[j + 1] = ((b << 4) | (c >> 2)).to_byte()
      }
    }
    _ => ()
  }
}
