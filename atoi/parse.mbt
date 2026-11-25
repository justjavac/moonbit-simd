///|
/// Selects automatic sign recognition or one of the two sign-free operations.
priv enum SignMode {
  Automatic
  Positive
  Negative
}

///|
/// Removes at most one permitted sign while retaining an immutable input view.
fn signed_input(
  data : BytesView,
  mode : SignMode,
  signed~ : Bool,
  skip_plus~ : Bool,
) -> (BytesView, Bool, Int32) {
  match (mode, data) {
    (Automatic, [b'-', .. tail]) if signed => (tail, true, 1)
    (Automatic, [b'+', .. tail]) if skip_plus => (tail, false, 1)
    (Negative, _) => (data, true, 0)
    _ => (data, false, 0)
  }
}

///|
/// Enforces a portable digit budget and returns the significant digit view.
fn significant_digits(
  data : BytesView,
  budget : Int32,
  skip_zeroes~ : Bool,
  simd~ : Bool,
) -> (BytesView, Int32) raise ParseError {
  let skipped = if skip_zeroes || budget == 0 {
    scalar_zero_length(data)
  } else {
    0
  }
  let rest = data[skipped:]
  // An over-budget prefix is already invalid; observe one extra digit rather
  // than traversing an arbitrarily long rejected input.
  // Budget zero identifies at most 32-bit types. Their leading zeroes were
  // removed, so one sixteen-byte block already proves every longer prefix
  // overflows; successful prefixes still have their complete consumed size.
  let limit = if budget == 0 { 16 } else { budget + 1 }
  let length = digit_length(rest, limit, simd~)
  guard length > 0 || skipped > 0 else { raise Empty }
  if budget != 0 && length > budget {
    raise Size(skipped + length, data)
  }
  (rest[:length], skipped + length)
}

///|
/// Parses a bounded unsigned magnitude and rejects arithmetic overflow before mutation.
fn magnitude64(
  data : BytesView,
  maximum : UInt64,
  budget : Int32,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  simd~ : Bool,
) -> (UInt64, Int32) raise ParseError {
  let (digits, consumed) = significant_digits(data, budget, skip_zeroes~, simd~)
  let value = for rest = digits, value = 0UL; !rest.is_empty(); {
    let (group, count) = decimal_group(rest, simd~)
    let multiplier = decimal_powers[count]
    let quotient = maximum / multiplier
    guard value < quotient ||
      (value == quotient && group <= maximum % multiplier) else {
      raise Overflow(data)
    }
    continue rest[count:], value * multiplier + group
  } nobreak {
    value
  }
  if !prefix && consumed != data.length() {
    raise Invalid64(value, consumed, data)
  }
  (value, consumed)
}

///|
/// Adapts sign recognition, range limits, and consumed offsets for 64-bit words.
fn parse_word(
  data : BytesView,
  mode : SignMode,
  positive_max : UInt64,
  negative_max : UInt64,
  budget : Int32,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  skip_plus~ : Bool,
  simd~ : Bool,
) -> (UInt64, Int32) raise ParseError {
  let (digits, negative, sign_length) = signed_input(
    data,
    mode,
    signed=negative_max != 0,
    skip_plus~,
  )
  let (magnitude, consumed) = magnitude64(
    digits,
    if negative {
      negative_max
    } else {
      positive_max
    },
    budget,
    prefix~,
    skip_zeroes~,
    simd~,
  )
  (if negative { 0UL - magnitude } else { magnitude }, consumed + sign_length)
}

///|
/// Parses a 128-bit magnitude with checked base-2^32 carries and exact bounds.
fn magnitude128(
  data : BytesView,
  maximum : UInt128,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  simd~ : Bool,
) -> (UInt128, Int32) raise ParseError {
  let (digits, consumed) = significant_digits(data, 39, skip_zeroes~, simd~)
  let value = for rest = digits, value = UInt128::from_words(high=0UL, low=0UL); !rest.is_empty(); {
    let (group, count) = decimal_group(rest, simd~)
    let next = if count == 16 {
      // Each limb product fits UInt64 with multipliers no greater than 10^8.
      value
      .append_small(100000000UL, group / 100000000UL, data)
      .append_small(100000000UL, group % 100000000UL, data)
    } else {
      value.append_small(decimal_powers[count], group, data)
    }
    guard !next.greater_than(maximum) else { raise Overflow(data) }
    continue rest[count:], next
  } nobreak {
    value
  }
  if !prefix && consumed != data.length() {
    raise Invalid128(value, consumed, data)
  }
  (value, consumed)
}

///|
/// Adapts signs and consumed offsets while preserving exact 128-bit two's complement.
fn parse_wide(
  data : BytesView,
  mode : SignMode,
  signed~ : Bool,
  prefix~ : Bool,
  skip_zeroes~ : Bool,
  skip_plus~ : Bool,
  simd~ : Bool,
) -> (UInt128, Int32) raise ParseError {
  let (digits, negative, sign_length) = signed_input(
    data,
    mode,
    signed~,
    skip_plus~,
  )
  let maximum = if negative {
    UInt128::from_words(high=0x8000000000000000UL, low=0UL)
  } else if signed {
    UInt128::from_words(high=0x7FFFFFFFFFFFFFFFUL, low=0xFFFFFFFFFFFFFFFFUL)
  } else {
    UInt128::from_words(high=0xFFFFFFFFFFFFFFFFUL, low=0xFFFFFFFFFFFFFFFFUL)
  }
  let (magnitude, consumed) = magnitude128(
    digits,
    maximum,
    prefix~,
    skip_zeroes~,
    simd~,
  )
  (
    if negative {
      magnitude.negated_bits()
    } else {
      magnitude
    },
    consumed + sign_length,
  )
}
