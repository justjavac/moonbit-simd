///|
/// Returns the width of a legal UTF-8 leading byte, or zero for other bytes.
fn leading_width(byte : Byte) -> Int32 {
  match byte {
    0xC2..<=0xDF => 2
    0xE0..<=0xEF => 3
    0xF0..<=0xF4 => 4
    _ => 0
  }
}

///|
/// Bounds the first continuation to exclude overlongs, surrogates, and U+110000.
fn first_continuation_bounds(leading : Byte) -> (Byte, Byte) {
  match leading {
    0xE0 => (0xA0, 0xBF)
    0xED => (0x80, 0x9F)
    0xF0 => (0x90, 0xBF)
    0xF4 => (0x80, 0x8F)
    _ => (0x80, 0xBF)
  }
}

///|
/// Finds the first scalar error without decoding or allocating valid text.
fn scalar_error(data : BytesView) -> Utf8Error? {
  for rest = data {
    match rest {
      [] => break None
      [
        0..<=0x7F,
        0..<=0x7F,
        0..<=0x7F,
        0..<=0x7F,
        0..<=0x7F,
        0..<=0x7F,
        0..<=0x7F,
        0..<=0x7F,
        .. tail,
      ] => continue tail
      [0..<=0x7F, .. tail] => continue tail
      [0xC2..<=0xDF, 0x80..<=0xBF, .. tail] => continue tail
      [0xE0, 0xA0..<=0xBF, 0x80..<=0xBF, .. tail]
      | [0xE1..<=0xEC, 0x80..<=0xBF, 0x80..<=0xBF, .. tail]
      | [0xED, 0x80..<=0x9F, 0x80..<=0xBF, .. tail]
      | [0xEE..<=0xEF, 0x80..<=0xBF, 0x80..<=0xBF, .. tail] => continue tail
      [0xF0, 0x90..<=0xBF, 0x80..<=0xBF, 0x80..<=0xBF, .. tail]
      | [0xF1..<=0xF3, 0x80..<=0xBF, 0x80..<=0xBF, 0x80..<=0xBF, .. tail]
      | [0xF4, 0x80..<=0x8F, 0x80..<=0xBF, 0x80..<=0xBF, .. tail] =>
        continue tail
      _ => {
        let valid_up_to = data.length() - rest.length()
        let width = leading_width(rest[0])
        if width == 0 {
          break Some(Utf8Error(valid_up_to~, error_len=Some(1)))
        }
        let (lower, upper) = first_continuation_bounds(rest[0])
        let error = for index = 1; index < width; index = index + 1 {
          if index >= rest.length() {
            break Utf8Error(valid_up_to~, error_len=None)
          }
          let byte = rest[index]
          let valid = if index == 1 {
            byte >= lower && byte <= upper
          } else {
            byte >= 0x80 && byte <= 0xBF
          }
          if !valid {
            break Utf8Error(valid_up_to~, error_len=Some(index))
          }
        } nobreak {
          abort("A complete legal UTF-8 sequence matched the error branch")
        }
        break Some(error)
      }
    }
  }
}

///|
/// Locates a potentially incomplete leading byte among a prefix's last three bytes.
fn pending_suffix_start(prefix : BytesView) -> Int32 {
  let length = prefix.length()
  for index = length - 1; index >= 0 && index >= length - 3; index = index - 1 {
    let byte = prefix[index]
    if byte >= 0x80 && byte <= 0xBF {
      continue
    }
    let width = leading_width(byte)
    if byte >= 0xC0 && (width == 0 || width > length - index) {
      break index
    }
    break length
  } nobreak {
    length
  }
}
