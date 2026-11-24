///|
/// Holds the operators that append powers of two zero bytes to a CRC state.
let byte_powers : FixedArray[UInt32] = make_byte_powers()

///|
/// Multiplies reflected polynomials modulo the IEEE generator polynomial.
fn multiply_mod(left : UInt32, right : UInt32) -> UInt32 {
  let mut result = 0U
  let mut factor = right
  // The most significant bit represents x^0 in this reflected convention.
  for bit in 0..<32 {
    if (left & (0x80000000U >> bit)) != 0 {
      result = result ^ factor
    }
    let feedback = if (factor & 1) == 0 { 0U } else { polynomial }
    factor = (factor >> 1) ^ feedback
  }
  result
}

///|
/// Derives all 64 zero-byte powers by repeated polynomial squaring.
fn make_byte_powers() -> FixedArray[UInt32] {
  let powers = FixedArray::make(64, 0U)
  // In reflected form, x^8 is bit 23.
  powers[0] = 0x00800000
  for bit in 1..<64 {
    powers[bit] = multiply_mod(powers[bit - 1], powers[bit - 1])
  }
  powers
}

///|
/// Computes the reflected polynomial operator for appending a byte length.
fn shift_factor(length : UInt64) -> UInt32 {
  for remaining = length, bit = 0, factor = 0x80000000U; remaining != 0; {
    let next = if (remaining & 1) == 0 {
      factor
    } else {
      multiply_mod(byte_powers[bit], factor)
    }
    continue remaining >> 1, bit + 1, next
  } nobreak {
    factor
  }
}

///|
/// Combines the finalized IEEE checksums of two consecutive byte sequences.
///
/// `first` is the finalized prefix checksum, including a checksum continued
/// from a custom initial state. `second` must be the suffix checksum computed
/// with the standard zero initial checksum. `second_len` must be the exact
/// suffix length in bytes. The result equals the continued checksum of their
/// concatenation, without needing either byte sequence.
///
/// A zero `second_len` returns `first`, regardless of `second`. Every `UInt64`
/// length is supported, with logarithmic work and no allocation per call.
/// Passing a checksum or length that does not describe the suffix produces a
/// checksum for that supplied state; the function cannot validate the bytes.
///
/// ```mbt check
/// test {
///   let joined = @crc32.combine(@crc32.hash(b"hello"), @crc32.hash(b" world"), 6)
///   assert_eq(joined, @crc32.hash(b"hello world"))
/// }
/// ```
pub fn combine(first : UInt32, second : UInt32, second_len : UInt64) -> UInt32 {
  if second_len == 0 {
    first
  } else {
    multiply_mod(shift_factor(second_len), first) ^ second
  }
}
