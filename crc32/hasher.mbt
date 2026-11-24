///|
/// Maintains a mutable, incremental CRC-32/ISO-HDLC checksum and byte count.
///
/// This is the reflected IEEE CRC used by PNG, ZIP, and gzip, with polynomial
/// `0x04C11DB7` (reflected `0xEDB88320`) and initial/final XOR `0xFFFFFFFF`.
/// The finalized checksum of empty input is zero. The internal fields are
/// private; use the constructors and methods to manage the state.
///
/// MoonBit values of this type have reference semantics: assigning a hasher
/// to another variable shares its mutable state. Use `copy()` to fork an
/// independent computation. `finalize()` observes the current checksum and
/// allows subsequent updates; it does not consume or reset the hasher.
///
/// The represented length must fit in `UInt64`. Updates and combinations
/// panic before changing the state if that length would overflow.
/// Constructors accept `simd=true` to request experimental vector processing
/// on `native` and `wasm`; other backends retain the scalar implementation.
/// The default uses slicing-by-eight, which is faster on the measured toolchain.
///
/// ```mbt check
/// test {
///   let hasher = @crc32.Hasher::new()
///   hasher.update(b"1234")
///   hasher.update(b"56789")
///   assert_eq(hasher.finalize(), 0xCBF43926U)
///   assert_eq(hasher.total_len(), 9UL)
/// }
/// ```
struct Hasher {
  mut checksum : UInt32
  mut amount : UInt64
  use_simd : Bool
}

///|
/// Computes the standard IEEE CRC-32 checksum of `data` in one call.
///
/// The result is a finalized 32-bit unsigned checksum, with zero for empty
/// input. `data` is a read-only byte view; passing `Bytes` or a subview avoids
/// copying the input. The input is interpreted as bytes, without text encoding
/// or host-endian conversion. Backend selection does not change the result.
/// `simd=false` uses slicing-by-eight; `simd=true` requests experimental
/// slicing-by-sixteen with vector operations on `native` and `wasm`, falling
/// back to scalar processing on `wasm-gc`, `js`, and inputs shorter than
/// sixteen bytes. Vector processing is not guaranteed to improve performance.
///
/// ```mbt check
/// test {
///   assert_eq(@crc32.hash(b"123456789"), 0xCBF43926U)
///   assert_eq(@crc32.hash(b""), 0U)
/// }
/// ```
pub fn hash(data : BytesView, simd~ : Bool = false) -> UInt32 {
  update(0, data, simd~)
}

///|
/// Extends a finalized IEEE CRC-32 checksum with additional bytes.
///
/// `initial` is a previous finalized checksum, not the inverted internal CRC
/// register. Pass zero to start a standard computation. An empty `data` leaves
/// `initial` unchanged; otherwise the result represents the preceding bytes
/// followed by `data`. The input view is read without copying or mutation.
///
/// Unlike a `Hasher`, this function tracks no byte count. Use it when a
/// checksum alone is enough, or use `Hasher` for later checksum combination.
/// `simd` selects the same experimental vector option as `hash()`; its default
/// is false and it does not affect checksum semantics.
///
/// ```mbt check
/// test {
///   let prefix = @crc32.hash(b"1234")
///   assert_eq(@crc32.update(prefix, b"56789"), 0xCBF43926U)
/// }
/// ```
pub fn update(
  initial : UInt32,
  data : BytesView,
  simd~ : Bool = false,
) -> UInt32 {
  update_dispatch(initial, data, simd)
}

///|
/// Creates a fresh incremental computation with checksum zero and length zero.
///
/// The state uses the standard IEEE initialization. Construction allocates
/// only the hasher itself; reusable algorithm tables are initialized once.
/// Updating the returned state and calling `finalize()` computes the same
/// result as `hash()` over the concatenated updates.
/// `simd=true` requests the vector implementation where available; false is
/// the default and uses the measured faster scalar implementation.
pub fn Hasher::new(simd~ : Bool = false) -> Hasher {
  Hasher::new_with_initial_len(0, 0, simd~)
}

///|
/// Resumes computation from a finalized checksum with an unknown prefix length.
///
/// `initial` uses the same convention as `hash()` and `update()`. The length
/// counter starts at zero because the prefix length is unknown; subsequent
/// updates still compute the correct continued checksum.
///
/// Use `new_with_initial_len()` when this state will be supplied as the suffix
/// to `combine()`, which requires its complete represented byte count.
/// `simd` selects the same implementation policy as `new()` and defaults to
/// false; the initial checksum convention is independent of that choice.
pub fn Hasher::new_with_initial(
  initial : UInt32,
  simd~ : Bool = false,
) -> Hasher {
  Hasher::new_with_initial_len(initial, 0, simd~)
}

///|
/// Resumes computation from a finalized checksum and its represented byte count.
///
/// `initial` is the existing finalized checksum and `amount` is the number of
/// bytes it represents. The caller must supply an accurate count for later
/// combination. No bytes are read and the relationship between the count and
/// checksum cannot be validated. Zero `amount` is valid, including for a custom
/// initial checksum. Subsequent updates add to this count without wrapping.
/// `simd` selects the same implementation policy as `new()` and defaults to
/// false. The supplied count is accepted in its full `UInt64` range.
///
/// ```mbt check
/// test {
///   let state = @crc32.Hasher::new_with_initial_len(@crc32.hash(b"hello"), 5)
///   state.update(b" world")
///   assert_eq(state.finalize(), @crc32.hash(b"hello world"))
///   assert_eq(state.total_len(), 11UL)
/// }
/// ```
pub fn Hasher::new_with_initial_len(
  initial : UInt32,
  amount : UInt64,
  simd~ : Bool = false,
) -> Hasher {
  { checksum: initial, amount, use_simd: simd, }
}

///|
/// Appends `data` to this hasher's represented byte sequence.
///
/// Updates the checksum and adds `data.length()` to the byte count. Empty
/// input is a no-op. Reads the input view without retaining, copying, or
/// changing it. Different chunk boundaries produce the same final checksum.
/// Panics before mutation if the total length would exceed `2^64 - 1` bytes.
pub fn Hasher::update(self : Hasher, data : BytesView) -> Unit {
  let amount = checked_length(self.amount, data.length().to_uint64())
  self.checksum = update(self.checksum, data, simd=self.use_simd)
  self.amount = amount
}

///|
/// Returns the number of bytes represented by this hasher without changing it.
///
/// Includes the constructor's supplied length, all updates, and the lengths of
/// combined suffix states. `new_with_initial()` starts at zero because its
/// prefix length is unknown. `reset()` sets the count back to zero.
pub fn Hasher::total_len(self : Hasher) -> UInt64 {
  self.amount
}

///|
/// Returns the current finalized IEEE CRC-32 checksum without changing the state.
///
/// A fresh or reset state returns zero. Repeated calls return the same value
/// until an update or combination occurs. Unlike Rust's consuming
/// `crc32fast::Hasher::finalize`, this method leaves the MoonBit reference usable
/// for further updates, copying, combination, or reset.
pub fn Hasher::finalize(self : Hasher) -> UInt32 {
  self.checksum
}

///|
/// Restores the standard empty state, setting both checksum and length to zero.
///
/// Discards a supplied initial checksum and supplied initial length as well as
/// all subsequent updates. The same mutable hasher can then be reused for a
/// separate byte sequence; references sharing this state observe the reset.
/// The implementation policy selected by the constructor is retained.
pub fn Hasher::reset(self : Hasher) -> Unit {
  self.checksum = 0
  self.amount = 0
}

///|
/// Returns an independent mutable copy of the current checksum and byte count.
///
/// Updating or resetting either hasher leaves the other unchanged. This is the
/// explicit alternative to assignment, which aliases the same MoonBit object.
/// Copying reads no input bytes and does not change this hasher.
/// The copy retains the constructor's SIMD selection.
///
/// ```mbt check
/// test {
///   let prefix = @crc32.Hasher::new()
///   prefix.update(b"hello")
///   let branch = prefix.copy()
///   branch.update(b" world")
///   assert_eq(prefix.finalize(), @crc32.hash(b"hello"))
///   assert_eq(branch.finalize(), @crc32.hash(b"hello world"))
/// }
/// ```
pub fn Hasher::copy(self : Hasher) -> Hasher {
  Hasher::new_with_initial_len(self.checksum, self.amount, simd=self.use_simd)
}

///|
/// Appends a separately computed suffix state without reading its bytes.
///
/// `other` must represent the subsequent byte sequence, computed from standard
/// initialization with its complete, accurate length. This state's checksum
/// and count become those of the concatenation; `other` is unchanged unless it
/// is the same mutable object as `self`, in which case the sequence is doubled.
/// A suffix with zero length is ignored, even if it has a nonzero checksum.
/// Panics before mutation if the combined count would exceed `2^64 - 1` bytes.
///
/// ```mbt check
/// test {
///   let prefix = @crc32.Hasher::new()
///   prefix.update(b"hello")
///   let suffix = @crc32.Hasher::new()
///   suffix.update(b" world")
///   prefix.combine(suffix)
///   assert_eq(prefix.finalize(), @crc32.hash(b"hello world"))
///   assert_eq(prefix.total_len(), 11UL)
///   assert_eq(suffix.total_len(), 6UL)
/// }
/// ```
pub fn Hasher::combine(self : Hasher, other : Hasher) -> Unit {
  // Read both lengths before mutation so combining a state with itself is valid.
  let amount = checked_length(self.amount, other.amount)
  self.checksum = combine(self.checksum, other.checksum, other.amount)
  self.amount = amount
}

///|
/// Adds represented lengths, rejecting overflow before a hasher is mutated.
fn checked_length(first : UInt64, second : UInt64) -> UInt64 {
  guard first <= 0xFFFFFFFFFFFFFFFFUL - second else {
    abort("CRC-32 represented length exceeds UInt64 capacity")
  }
  first + second
}
