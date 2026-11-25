// Adapted from simdutf8 0.1.5, src/implementation/algorithm.rs and wasm32/simd128.rs.
// See LICENSE and README.md for revision, attribution, and algorithm provenance.

///|
/// Classifies the preceding byte's high nibble using the lookup3 error bitsets.
#cfg(target="wasm")
let previous_high : V128 = @simd.i8x16_const(
  2, 2, 2, 2, 2, 2, 2, 2, 128, 128, 128, 128, 33, 1, 21, 73,
)

///|
/// Classifies the preceding byte's low nibble, refining exceptional lead bytes.
#cfg(target="wasm")
let previous_low : V128 = @simd.i8x16_const(
  231, 163, 131, 131, 139, 203, 203, 203, 203, 203, 203, 203, 203, 219, 203, 203,
)

///|
/// Classifies the current high nibble for missing or extra continuation bytes.
#cfg(target="wasm")
let current_high : V128 = @simd.i8x16_const(
  1, 1, 1, 1, 1, 1, 1, 1, 230, 174, 186, 186, 1, 1, 1, 1,
)

///|
/// Detects leading bytes whose continuation extends beyond a sixteen-byte block.
#cfg(any(target="native", target="wasm"))
fn incomplete(previous : V128) -> V128 {
  @simd.i8x16_sub_sat_u(
    previous,
    @simd.i8x16_const(
      255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 239, 223,
      191,
    ),
  )
}

///|
/// Computes lookup3 errors while carrying the previous vector's last three bytes.
#cfg(target="wasm")
fn block_errors(input : V128, previous : V128) -> V128 {
  let prev1 = @simd.i8x16_shuffle(
    previous, input, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29,
    30,
  )
  let prev2 = @simd.i8x16_shuffle(
    previous, input, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28,
    29,
  )
  let prev3 = @simd.i8x16_shuffle(
    previous, input, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27,
    28,
  )
  let high = @simd.i8x16_swizzle(previous_high, @simd.i8x16_shr_u(prev1, 4))
  let low = @simd.i8x16_swizzle(
    previous_low,
    @simd.v128_and_(prev1, @simd.i8x16_splat(15)),
  )
  let current = @simd.i8x16_swizzle(current_high, @simd.i8x16_shr_u(input, 4))
  let special = @simd.v128_and_(@simd.v128_and_(high, low), current)
  let must_continue = @simd.v128_or_(
    @simd.i8x16_gt_u(prev2, @simd.i8x16_splat(223)),
    @simd.i8x16_gt_u(prev3, @simd.i8x16_splat(239)),
  )
  @simd.v128_xor(
    special,
    @simd.v128_and_(must_continue, @simd.i8x16_splat(128)),
  )
}

///|
/// Returns -1 for valid input or a failing block boundary, with view-bounded loads.
#cfg(any(target="native", target="wasm"))
fn scan_simd(data : BytesView, early~ : Bool) -> Int32 {
  let zero = @simd.i8x16_splat(0)
  for rest = data, previous = zero, errors = zero {
    match rest {
      [v128le(a), v128le(b), v128le(c), v128le(d), .. tail] => {
        let all = @simd.v128_or_(@simd.v128_or_(a, b), @simd.v128_or_(c, d))
        let next_errors = if @simd.i8x16_bitmask(all) == 0 {
          @simd.v128_or_(errors, incomplete(previous))
        } else {
          let ab = @simd.v128_or_(block_errors(a, previous), block_errors(b, a))
          let cd = @simd.v128_or_(block_errors(c, b), block_errors(d, c))
          @simd.v128_or_(errors, @simd.v128_or_(ab, cd))
        }
        if early && @simd.v128_any_true(next_errors) {
          break data.length() - rest.length()
        }
        continue tail, d, next_errors
      }
      [v128le(block), .. tail] => {
        let next_errors = @simd.v128_or_(
          errors,
          if @simd.i8x16_bitmask(block) == 0 {
            incomplete(previous)
          } else {
            block_errors(block, previous)
          },
        )
        if early && @simd.v128_any_true(next_errors) {
          break data.length() - rest.length()
        }
        continue tail, block, next_errors
      }
      _ => {
        if @simd.v128_any_true(errors) {
          break 0
        }
        let boundary = data.length() - rest.length()
        let start = pending_suffix_start(data[:boundary])
        break if scalar_error(data[start:]) is None { -1 } else { start }
      }
    }
  }
}

///|
/// Preserves strict scalar behavior on backends without portable V128 validation.
#cfg(not(any(target="native", target="wasm")))
fn scan_simd(data : BytesView, early~ : Bool) -> Int32 {
  let _ = early
  if scalar_error(data) is None {
    -1
  } else {
    0
  }
}
