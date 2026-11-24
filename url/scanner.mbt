///|
/// Finds the next authority delimiter using portable vector scans when requested.
fn authority_end(input : BytesView, special : Bool, simd : Bool) -> Int32 {
  if simd {
    authority_end_wide(input, special)
  } else {
    authority_end_scalar(input, special)
  }
}

///|
/// Scans authority bytes for slash, question mark, or special-scheme backslash.
fn authority_end_scalar(input : BytesView, special : Bool) -> Int32 {
  for i = 0; i < input.length(); i = i + 1 {
    if input[i] == b'/' || input[i] == b'?' || (special && input[i] == b'\\') {
      return i
    }
  }
  input.length()
}

///|
/// Finds authority delimiters in checked sixteen-byte SIMD loads and a scalar tail.
#cfg(any(target="native", target="wasm"))
fn authority_end_wide(input : BytesView, special : Bool) -> Int32 {
  for rest = input, offset = 0 {
    match rest {
      [v128le(word), .. tail] => {
        let matches = @simd.v128_or_(
          @simd.i8x16_eq(word, @simd.i8x16_splat(b'/')),
          @simd.i8x16_eq(word, @simd.i8x16_splat(b'?')),
        )
        let matches = if special {
          @simd.v128_or_(
            matches,
            @simd.i8x16_eq(word, @simd.i8x16_splat(b'\\')),
          )
        } else {
          matches
        }
        let mask = @simd.i8x16_bitmask(matches)
        if mask != 0 {
          return offset + mask.ctz()
        }
        continue tail, offset + 16
      }
      _ => break offset + authority_end_scalar(rest, special)
    }
  }
}

///|
/// Uses scalar authority scanning on backends without supported V128 lowering.
#cfg(any(target="wasm-gc", target="js"))
fn authority_end_wide(input : BytesView, special : Bool) -> Int32 {
  authority_end_scalar(input, special)
}

///|
/// Checks whether an input contains tabs or newlines that WHATWG ignores.
fn contains_ignored(input : BytesView, simd : Bool) -> Bool {
  if simd {
    contains_ignored_wide(input)
  } else {
    input.iter().any(byte => byte == 9 || byte == 10 || byte == 13)
  }
}

///|
/// Accumulates ignored-character comparisons in checked SIMD blocks.
#cfg(any(target="native", target="wasm"))
fn contains_ignored_wide(input : BytesView) -> Bool {
  for rest = input {
    match rest {
      [v128le(word), .. tail] => {
        let matches = @simd.v128_or_(
          @simd.v128_or_(
            @simd.i8x16_eq(word, @simd.i8x16_splat(9)),
            @simd.i8x16_eq(word, @simd.i8x16_splat(10)),
          ),
          @simd.i8x16_eq(word, @simd.i8x16_splat(13)),
        )
        if @simd.i8x16_bitmask(matches) != 0 {
          return true
        }
        continue tail
      }
      _ => break rest.iter().any(byte => byte == 9 || byte == 10 || byte == 13)
    }
  }
}

///|
/// Checks ignored bytes with the scalar implementation on non-vector backends.
#cfg(any(target="wasm-gc", target="js"))
fn contains_ignored_wide(input : BytesView) -> Bool {
  input.iter().any(byte => byte == 9 || byte == 10 || byte == 13)
}
