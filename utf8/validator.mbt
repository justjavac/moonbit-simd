///|
/// A mutable strict UTF-8 validator for arbitrarily split byte chunks.
/// Assignment aliases the same state; `copy()` forks independent state. Input
/// views are read synchronously and never retained. Errors are reported only by
/// `finalize()`, as a boolean rather than an offset, like simdutf8 basic streaming.
struct Validator {
  simd : Bool
  mut remaining : Int32
  mut lower : Byte
  mut upper : Byte
  mut failed : Bool
}

///|
/// Creates an independent validator with no pending continuation bytes or
/// errors. It finalizes successfully on empty input.
/// The default `simd=true` requests vector validation of complete portions
/// of updates of at least 64 bytes on native and linear-memory Wasm.
/// Sequence fragments, shorter updates, Wasm GC, and JS use scalar transitions.
pub fn Validator::new(simd~ : Bool = true) -> Validator {
  { simd, remaining: 0, lower: 0x80, upper: 0xBF, failed: false, }
}

///|
/// Advances one byte while enforcing continuation bounds across chunk boundaries.
fn Validator::push_byte(self : Validator, byte : Byte) -> Unit {
  if self.remaining > 0 {
    if byte < self.lower || byte > self.upper {
      self.failed = true
    } else {
      self.remaining = self.remaining - 1
      self.lower = 0x80
      self.upper = 0xBF
    }
  } else if byte >= 0x80 {
    let width = leading_width(byte)
    if width == 0 {
      self.failed = true
    } else {
      let (lower, upper) = first_continuation_bounds(byte)
      self.remaining = width - 1
      self.lower = lower
      self.upper = upper
    }
  }
}

///|
/// Adds `data` to the logical stream without retaining or mutating the bytes.
/// A multibyte sequence may cross any number of updates, including empty ones.
/// Invalid input makes failure sticky until `reset()`. There is no intermediate
/// error result; an incomplete suffix is retained as at most three continuation
/// requirements. Complete large portions use the requested validation backend.
pub fn Validator::update(self : Validator, data : BytesView) -> Unit {
  if self.failed {
    return
  }
  let mut offset = for offset = 0
                       offset < data.length() && self.remaining > 0
                       offset = offset + 1 {
    self.push_byte(data[offset])
    if self.failed {
      return
    }
  } nobreak {
    offset
  }
  if data.length() - offset >= 64 {
    let rest = data[offset:]
    let complete = pending_suffix_start(rest)
    if !is_valid(rest[:complete], simd=self.simd) {
      self.failed = true
      return
    }
    offset = offset + complete
  }
  for index in offset..<data.length() {
    self.push_byte(data[index])
    if self.failed {
      break
    }
  }
}

///|
/// Reports whether all supplied bytes form complete, valid UTF-8.
/// This observes state without consuming or resetting it. Repeated calls agree;
/// after an incomplete result, supplying the missing continuation can make a
/// later result true. A malformed sequence remains false until `reset()`.
///
/// ```mbt check
/// test {
///   let validator = @utf8.Validator::new()
///   validator.update(b"\xE2\x9D")
///   assert_eq(validator.finalize(), false)
///   validator.update(b"\xA4")
///   assert_eq(validator.finalize(), true)
/// }
/// ```
pub fn Validator::finalize(self : Validator) -> Bool {
  !self.failed && self.remaining == 0
}

///|
/// Discards all stream input and errors while preserving the SIMD preference.
/// Aliases observe the reset; independent copies do not.
pub fn Validator::reset(self : Validator) -> Unit {
  self.remaining = 0
  self.lower = 0x80
  self.upper = 0xBF
  self.failed = false
}

///|
/// Copies current validation state into an independent mutable validator.
/// Both branches retain the same backend preference and pending continuation
/// requirements; updating or resetting one branch cannot affect the other.
pub fn Validator::copy(self : Validator) -> Validator {
  {
    simd: self.simd,
    remaining: self.remaining,
    lower: self.lower,
    upper: self.upper,
    failed: self.failed,
  }
}
