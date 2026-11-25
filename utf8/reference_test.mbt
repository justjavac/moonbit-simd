///|
/// Parses integer code-point prefixes independently of the production range patterns.
fn reference_error(data : BytesView) -> (Int32, Int32?)? {
  let mut offset = 0
  for ; offset < data.length(); {
    let leading = data[offset].to_int()
    if leading < 128 {
      offset = offset + 1
      continue
    }
    let width = if leading >> 5 == 6 && leading > 193 {
      2
    } else if leading >> 4 == 14 {
      3
    } else if leading >> 3 == 30 && leading < 245 {
      4
    } else {
      return Some((offset, Some(1)))
    }
    let mut codepoint = leading & ((1 << (7 - width)) - 1)
    for index in 1..<width {
      if index >= data.length() - offset {
        return Some((offset, None))
      }
      let byte = data[offset + index].to_int()
      if byte >> 6 != 2 {
        return Some((offset, Some(index)))
      }
      codepoint = (codepoint << 6) | (byte & 63)
      if index == 1 {
        let illegal = match width {
          2 => codepoint < 128
          3 => codepoint < 32 || (codepoint >= 864 && codepoint <= 895)
          _ => codepoint < 16 || codepoint > 271
        }
        if illegal {
          return Some((offset, Some(1)))
        }
      }
    }
    offset = offset + width
  }
  None
}

///|
/// Checks both validation requests against the independent code-point parser.
fn check_reference(data : BytesView) -> Unit raise {
  match reference_error(data) {
    None =>
      for simd in [false, true] {
        assert_true(@utf8.is_valid(data, simd~))
        @utf8.validate(data, simd~)
      }
    Some((position, length)) => expect_error(data, position, length)
  }
}

///|
test "every byte pair agrees with an independent code-point oracle across vectors" {
  let prefix = Bytes::make(63, b'a')
  let suffix = Bytes::make(64, b'b')
  for first in 0..<256 {
    for second in 0..<256 {
      let pair : Bytes = [first.to_byte(), second.to_byte()]
      check_reference(pair)
      check_reference(prefix + pair + suffix)
    }
  }
}

///|
test "deterministic byte corpora agree with the independent parser and core decoder" {
  let mut seed = 0xC001D00DU
  for sample in 0..<2400 {
    let length = sample * 73 % 257
    let bytes = Bytes::makei(length, _ => {
      seed = seed * 1664525U + 1013904223U
      (seed >> 24).to_byte()
    })
    let data = Bytes::make(sample % 144, b'a') + bytes
    check_reference(data)
    let core_valid = try @encoding.decode(data, ignore_bom=false) catch {
      _ => false
    } noraise {
      _ => true
    }
    assert_eq(@utf8.is_valid(data), core_valid)
  }
}

///|
test "sampled Unicode scalars validate without relying on a library encoder" {
  let prefix = Bytes::make(63, b'a')
  for codepoint = 0; codepoint <= 0x10FFFF; codepoint = codepoint + 61 {
    if codepoint >= 0xD800 && codepoint <= 0xDFFF {
      continue
    }
    let bytes : Bytes = if codepoint < 128 {
      [codepoint.to_byte()]
    } else if codepoint < 2048 {
      [(192 | (codepoint >> 6)).to_byte(), (128 | (codepoint & 63)).to_byte()]
    } else if codepoint < 65536 {
      [
        (224 | (codepoint >> 12)).to_byte(),
        (128 | ((codepoint >> 6) & 63)).to_byte(),
        (128 | (codepoint & 63)).to_byte(),
      ]
    } else {
      [
        (240 | (codepoint >> 18)).to_byte(),
        (128 | ((codepoint >> 12) & 63)).to_byte(),
        (128 | ((codepoint >> 6) & 63)).to_byte(),
        (128 | (codepoint & 63)).to_byte(),
      ]
    }
    assert_true(@utf8.is_valid(prefix + bytes + prefix))
  }
}
