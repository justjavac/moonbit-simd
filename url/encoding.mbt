///|
/// Identifies the WHATWG percent-encode set used by a component.
#derive(Eq)
priv enum EncodeSet {
  Control
  Fragment
  Query
  SpecialQuery
  Path
  Userinfo
  Form
}

///|
/// Determines whether a byte belongs to the selected WHATWG encode set.
#inline
fn needs_encoding(byte : Byte, set : EncodeSet) -> Bool {
  let c = byte.to_int()
  if set == Form {
    return !((c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      (c >= 48 && c <= 57) ||
      c == 42 ||
      c == 45 ||
      c == 46 ||
      c == 95)
  }
  if c <= 31 || c > 126 {
    return true
  }
  match set {
    Control => false
    Fragment => c == 32 || c == 34 || c == 60 || c == 62 || c == 96
    Query => c == 32 || c == 34 || c == 35 || c == 60 || c == 62
    SpecialQuery =>
      c == 32 || c == 34 || c == 35 || c == 39 || c == 60 || c == 62
    Path =>
      c == 32 ||
      c == 34 ||
      c == 35 ||
      c == 60 ||
      c == 62 ||
      c == 63 ||
      c == 94 ||
      c == 96 ||
      c == 123 ||
      c == 125
    Userinfo =>
      needs_encoding(byte, Path) ||
      c == 47 ||
      c == 58 ||
      c == 59 ||
      c == 61 ||
      c == 64 ||
      c == 91 ||
      c == 92 ||
      c == 93 ||
      c == 124
    Form => false
  }
}

///|
/// Holds uppercase hexadecimal digits for percent escapes.
let hex_digits : Bytes = b"0123456789ABCDEF"

///|
/// Encodes a UTF-8 byte view, preserving bytes outside the selected encode set.
fn encode_bytes(input : BytesView, set : EncodeSet) -> String {
  let output = @buffer.Buffer(capacity=input.length())
  for byte in input {
    if set == Form && byte == b' ' {
      output.write_byte(b'+')
    } else if needs_encoding(byte, set) {
      output.write_byte(b'%')
      output.write_byte(hex_digits[byte.to_int() >> 4])
      output.write_byte(hex_digits[byte.to_int() & 15])
    } else {
      output.write_byte(byte)
    }
  }
  @utf8.decode_lossy(output.to_bytes(), ignore_bom=true)
}

///|
/// Converts a hexadecimal ASCII byte to its digit value or minus one.
#inline
fn hex_value(byte : Byte) -> Int32 {
  let c = byte.to_int()
  if c >= 48 && c <= 57 {
    c - 48
  } else if c >= 65 && c <= 70 {
    c - 55
  } else if c >= 97 && c <= 102 {
    c - 87
  } else {
    -1
  }
}

///|
/// Decodes well-formed percent escapes and optionally maps form plus signs to spaces.
fn decode_bytes(input : BytesView, plus : Bool) -> Bytes {
  let output = @buffer.Buffer(capacity=input.length())
  let mut i = 0
  while i < input.length() {
    let c = input[i]
    if c == b'%' && i + 2 < input.length() {
      let a = hex_value(input[i + 1])
      let b = hex_value(input[i + 2])
      if a >= 0 && b >= 0 {
        output.write_byte(((a << 4) | b).to_byte())
        i += 3
        continue
      }
    }
    output.write_byte(if plus && c == b'+' { b' ' } else { c })
    i += 1
  }
  output.to_bytes()
}

///|
/// Encodes a MoonBit string as UTF-8 and applies a component encode set.
fn encode_text(input : StringView, set : EncodeSet) -> String {
  encode_bytes(@utf8.encode(input), set)
}

///|
/// Folds ASCII case eight bytes at a time using Ada's portable SWAR algorithm.
fn lower_ascii(input : BytesView) -> String {
  let output = @buffer.Buffer(capacity=input.length())
  for rest = input {
    match rest {
      [u64le(word), .. tail] => {
        // Each lane is ASCII, so the per-byte additions cannot carry to the
        // next lane before the high-bit mask extracts the A..Z comparison.
        let upper = (
            (word + 0x3F3F3F3F3F3F3F3FUL) ^ (word + 0x2525252525252525UL)
          ) &
          0x8080808080808080UL
        output.write_uint64_le(word ^ (upper >> 2))
        continue tail
      }
      _ => {
        for byte in rest {
          output.write_byte(
            if byte >= b'A' && byte <= b'Z' {
              byte + 32
            } else {
              byte
            },
          )
        }
        break
      }
    }
  }
  @utf8.decode_lossy(output.to_bytes(), ignore_bom=true)
}

///|
/// Removes WHATWG-ignored tabs and newlines and trims leading and trailing C0 space.
fn prepare_input(input : StringView, simd : Bool) -> BytesView {
  let source = @utf8.encode(input)
  let cleaned = if contains_ignored(source, simd) {
    let output = @buffer.Buffer(capacity=source.length())
    for byte in source {
      if byte != b'\t' && byte != b'\r' && byte != b'\n' {
        output.write_byte(byte)
      }
    }
    output.to_bytes()
  } else {
    source
  }
  let mut first = 0
  let mut last = cleaned.length()
  while first < last && cleaned[first] <= 32 {
    first += 1
  }
  while last > first && cleaned[last - 1] <= 32 {
    last -= 1
  }
  cleaned[first:last]
}

///|
/// Removes tabs and newlines for setters without trimming significant spaces.
fn prepare_setter(input : StringView) -> BytesView {
  let bytes = @utf8.encode(input)
  let output = @buffer.Buffer(capacity=bytes.length())
  for byte in bytes {
    if byte != b'\t' && byte != b'\r' && byte != b'\n' {
      output.write_byte(byte)
    }
  }
  output.to_bytes()[:]
}
