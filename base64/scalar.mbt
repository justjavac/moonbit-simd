///|
/// Stores a complete triple as four ASCII bytes using two packed pair lookups.
#inline
fn encode_triple(
  bits : UInt32,
  output : FixedArray[Byte],
  offset : Int32,
  pairs : FixedArray[UInt16],
) -> Unit {
  // The caller supplies 24 input bits and reserves all four output bytes.
  // Both halves index the fixed 4096-entry table with exactly twelve bits.
  let high = pairs
    .unsafe_get(((bits >> 12) & 0xFFF).reinterpret_as_int())
    .to_uint()
  let low = pairs.unsafe_get((bits & 0xFFF).reinterpret_as_int()).to_uint()
  output.unsafe_write_uint32_le(offset, high | (low << 16))
}

///|
/// Encodes complete triples and a padded or unpadded scalar remainder.
fn encode_scalar(
  input : BytesView,
  output : FixedArray[Byte],
  offset : Int32,
  config : Base64,
) -> Unit {
  let pairs = if config.url_safe {
    url_encode_pairs
  } else {
    standard_encode_pairs
  }
  let length = input.length()
  let source = input.data()
  let start = input.start_offset()
  let (i, j) = for i = 0, j = offset; i <= length - 4; i = i + 3, j = j + 4 {
    // The fourth byte is inside the view and its bits are discarded.
    let word = source.unsafe_read_uint32_be(start + i)
    encode_triple(word >> 8, output, j, pairs)
  } nobreak {
    (i, j)
  }
  let alphabet = config.charset()
  match length - i {
    3 => {
      let bits = (input[i].to_uint() << 16) |
        (input[i + 1].to_uint() << 8) |
        input[i + 2].to_uint()
      encode_triple(bits, output, j, pairs)
    }
    1 => {
      let byte = input[i].to_int()
      output[j] = alphabet[byte >> 2]
      output[j + 1] = alphabet[(byte & 3) << 4]
      if config.padding {
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
      if config.padding {
        output[j + 3] = b'='
      }
    }
    _ => ()
  }
}

///|
/// Combines the four byte-indexed sections of a 1024-entry decode table.
#inline
fn lookup_quartet(
  a : Int32,
  b : Int32,
  c : Int32,
  d : Int32,
  words : FixedArray[UInt32],
) -> UInt32 {
  // Callers supply four byte values, so each index is within its section.
  words.unsafe_get(a) |
  words.unsafe_get(256 + b) |
  words.unsafe_get(512 + c) |
  words.unsafe_get(768 + d)
}

///|
/// Loads and translates a bounded quartet, marking non-ASCII text as invalid.
#inline
fn Input::decode_quartet(
  self : Input,
  index : Int32,
  words : FixedArray[UInt32],
) -> UInt32 {
  // The full-group loop bounds all four reads inside the effective input.
  match self {
    Raw(input) =>
      lookup_quartet(
        input.unsafe_get(index).to_int(),
        input.unsafe_get(index + 1).to_int(),
        input.unsafe_get(index + 2).to_int(),
        input.unsafe_get(index + 3).to_int(),
        words,
      )
    Text(input) => {
      let a = input.unsafe_get(index).to_int()
      let b = input.unsafe_get(index + 1).to_int()
      let c = input.unsafe_get(index + 2).to_int()
      let d = input.unsafe_get(index + 3).to_int()
      if (a | b | c | d) < 256 {
        lookup_quartet(a, b, c, d, words)
      } else {
        INVALID_WORD
      }
    }
    Inplace(input, _) =>
      lookup_quartet(
        input.unsafe_get(index).to_int(),
        input.unsafe_get(index + 1).to_int(),
        input.unsafe_get(index + 2).to_int(),
        input.unsafe_get(index + 3).to_int(),
        words,
      )
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
/// Checks complete byte quartets using the smaller sextet table and returns the tail offset.
fn check_byte_quartets(
  view : BytesView,
  start : Int32,
  length : Int32,
  table : FixedArray[Byte],
) -> Int32 raise Base64Error {
  let data = view.data()
  let base = view.start_offset()
  for i = start; i <= length - 4; i = i + 4 {
    // The loop bounds all reads, and each byte indexes the 256-entry table.
    // The OR is 0xff if any input mapped to the invalid sentinel.
    let position = base + i
    let values = table.unsafe_get(data.unsafe_get(position).to_int()) |
      table.unsafe_get(data.unsafe_get(position + 1).to_int()) |
      table.unsafe_get(data.unsafe_get(position + 2).to_int()) |
      table.unsafe_get(data.unsafe_get(position + 3).to_int())
    guard values != b'\xff' else { raise InvalidInput }
  } nobreak {
    i
  }
}

///|
/// Decodes or checks complete quartets and canonical tail bits after a vector prefix.
fn decode_scalar(
  input : Input,
  start : Int32,
  length : Int32,
  output : FixedArray[Byte],
  offset : Int32,
  config : Base64,
  forgiving : Bool,
  write : Bool,
) -> Unit raise Base64Error {
  let table = config.decode_table()
  let (i, j) = if !write && input is Raw(view) {
    (check_byte_quartets(view, start, length, table), offset)
  } else {
    let words = if config.url_safe {
      url_decode_words
    } else {
      standard_decode_words
    }
    for i = start, j = offset; i <= length - 4; i = i + 4, j = j + 3 {
      let packed = input.decode_quartet(i, words)
      guard (packed & INVALID_WORD) == 0 else { raise InvalidInput }
      if write {
        // The caller reserves three bytes per group. Store exactly those bytes.
        output.unsafe_write_uint16_le(j, packed.to_uint16())
        output.unsafe_set(j + 2, (packed >> 16).to_byte())
      }
    } nobreak {
      (i, j)
    }
  }
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
