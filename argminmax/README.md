# ArgMinMax

`justjavac/argminmax` finds the **indices** of the minimum and maximum values
in one pass, with first-index ties, two NaN policies, and Arrow validity bitmaps.
The name preserves the established mathematical terms `argmin` and `argmax`
and the identity of the upstream library.

This is an independent, MIT-licensed, pure MoonBit port of
[`argminmax@0.7.1`](https://crates.io/crates/argminmax/0.7.1), pinned to revision
[`f68aba5c251e9dc093f3939c0f9607c942228311`](https://github.com/jvdd/argminmax/tree/f68aba5c251e9dc093f3939c0f9607c942228311).
The published crate archive's verified SHA-256 is
`088a9c28ca36500c581f9f54b63460492d2b4f71e1e61d176e8fb79565109b01`.
The port uses the bundled `moonbitlang/core/simd` intrinsics and has no external
production dependencies, FFI, native stubs, or maintained backend sources.

## Installation and imports

The initial `0.1.0` source is available in this repository; it has not yet been
published to Mooncakes. The root workspace links it locally. To use it in
another local workspace, add this module's directory to that `moon.work` and
add `"justjavac/argminmax@0.1.0"` to the consuming module's `moon.mod` imports.
Once a release is published, install it with:

```text
moon add justjavac/argminmax@0.1.0
```

Configure the consuming package's `moon.pkg`:

```text
import {
  "justjavac/argminmax",
}
```

Consumers do not need to import the experimental SIMD package themselves.
See [README.mbt.md](README.mbt.md) for checked examples and
[pkg.generated.mbti](pkg.generated.mbti) for the generated interface.

## Basic usage

```moonbit
let values = [3, -2, 9, -2]
assert_eq(@argminmax.argminmax(values), Some((1, 2)))
assert_eq(@argminmax.argmin(values), Some(1))
assert_eq(@argminmax.argmax(values), Some(2))
assert_eq(@argminmax.argminmax(values[2:]), Some((1, 0)))
```

The input is `ArrayView[T]`: `Array`, `FixedArray`, `ReadOnlyArray`, and their
views are accepted without materializing a copy. Indices count **elements**
relative to the supplied view, even when its backing array starts earlier.
Empty views return `None`.

## Operations and NaNs

| Operation | Result | NaN handling |
| --- | --- | --- |
| `argminmax` | `(Int, Int)?` | Ignore NaNs; track both extrema. |
| `argmin` / `argmax` | `Int?` | Ignore NaNs; track only the requested extremum. |
| `nanargminmax` | `(Int, Int)?` | Return the first NaN index in both components. |
| `nanargmin` / `nanargmax` | `Int?` | Return the first NaN index, otherwise the requested extremum. |
| Each operation with `_masked` | Same optional result, raising `BitmapError` on an invalid bitmap range | Skip nulls, then apply the corresponding NaN policy. |

All operations preserve the first index on ties. Positive and negative zero
are equal. Infinities participate normally. A nonempty all-NaN view returns
index zero; a masked all-NaN view returns its first **valid** index. Empty or
all-null input returns `None`.

The `nan` prefix follows upstream's **propagation** convention, which differs
from NumPy's NaN-ignoring `nanargmin`. This port guarantees the first NaN even
when payloads, signs, or signaling encodings differ; upstream documents a
weaker guarantee for mixed NaN bit patterns. Integer `nan` operations have the
same result as their ordinary counterparts.

```moonbit
let values : Array[Double] = [1.0, 0.0 / 0.0, -3.0]
assert_eq(@argminmax.argminmax(values), Some((2, 0)))
assert_eq(@argminmax.nanargminmax(values), Some((1, 1)))
```

## Numeric types

All fourteen upstream numeric kinds are supported. Every search is exact for
integer inputs, including above `2^53` on JavaScript.

| Rust kind | MoonBit element | Representation / construction |
| --- | --- | --- |
| `u8` | `Byte` | Built in. |
| `i8` | `@argminmax.Int8` | `from_int` checks -128 through 127; `from_bits(Byte)` interprets two's complement. |
| `u16` / `i16` | `UInt16` / `Int16` | Built in. |
| `u32` / `i32` | `UInt` / `Int` (`UInt32` / `Int32`) | Built in. |
| `u64` / `i64` | `UInt64` / `Int64` | Built in. |
| `u128` | `@argminmax.UInt128` | `from_words(high=UInt64, low=UInt64)` or `from_uint64`; scalar comparisons. |
| `i128` | `@argminmax.Int128` | `from_words(high=Int64, low=UInt64)` or `from_int64`; scalar comparisons. |
| `f32` / `f64` | `Float` / `Double` | Built in. |
| `f16` | `@argminmax.Float16` | IEEE binary16; `from_bits(UInt16)`, `to_bits`, exact widening `to_double`. |
| `bf16` | `@argminmax.BFloat16` | Eight exponent / seven fraction bits; the same bit and widening methods. |

The custom types are immutable, with private representations and safe shared
assignments. The 128-bit high word is most significant: its signedness selects
signed or unsigned ordering, and the low word is always unsigned. No host byte
order or floating conversion is used for wide integers.

The half types preserve the original bits, including NaN payloads and signed
zero. Widening finite values to `Double` is exact; subsequent floating-point
operations can canonicalize NaNs on some backends. Numeric comparisons order
the finite/infinite values through signed ordinal bits, with both zeroes
mapped to zero; searches classify NaNs before comparing them. Half constructors
accept raw bits and do not provide narrowing or rounding from larger floats.
The wide integer types provide comparison and word construction, not arithmetic.

```moonbit
let wide = [
  @argminmax.UInt128::from_words(high=1UL, low=0UL),
  @argminmax.UInt128::from_uint64(1UL),
]
assert_eq(@argminmax.argminmax(wide), Some((1, 0)))
```

`Element : Compare` is open for custom ordered types. Its default implementation
is scalar. Implement `is_nan` only for types with unordered NaN values; otherwise
the default is false. The default `find_extrema` provides first ties, both policies,
and empty-input handling. Custom comparisons must remain consistent during a call.

## Validity bitmaps

`argminmax_masked(data, validity, offset=0, simd=...)` uses the
[Arrow validity format](https://arrow.apache.org/docs/format/Columnar.html#validity-bitmaps).
Element `i` is valid iff bit `offset + i` is set. Bits are numbered from the
least significant bit of the first byte. The offset counts bits relative to
the bitmap **view**, independently of the data view's element offset.

```moonbit
// Only elements 1 and 2 are valid. Results keep the original indices.
assert_eq(@argminmax.argminmax_masked([-5, 3, 9, 4], b"\x06"), Some((1, 2)))
assert_eq(@argminmax.argminmax_masked([1, 2], b"\x00"), None)
```

Negative offsets raise `BitmapError::InvalidOffset`. Too few bits raise
`BitmapError::InsufficientBits(required=..., available=...)`, including when an
empty view has an out-of-range offset. Required and available lengths use
`Int64`, so `offset + length` and bitmap-byte-to-bit conversion cannot overflow
an `Int`. Validation finishes before reading any values or bitmap bits.

Bitmap scanning finds contiguous valid runs, searches each view, and merges its
original indices. Null values, including null NaNs, never affect the result.
All-null inputs return `None`; all-valid NaNs return the first valid index.
No compacted array, converted data, or temporary validity buffer is allocated.

Default and explicit scalar searches instead scan valid elements directly,
caching extrema without allocating per-run views or results. Bitmap positioning
splits the offset and element index into byte parts and bit remainders. Their
largest byte sum is 536870911, so 32-bit arithmetic remains safe even when the
validated absolute bit position exceeds `Int` capacity. This avoids repeated
64-bit conversions and division in the JavaScript scan.

## Algorithms, dispatch, and portability

The scalar scan caches values and indices, updates them only for strict extrema,
and explicitly handles the first non-NaN and all-NaN cases. Combined searches
track both ends in one traversal. Single-extremum searches omit the other end.

The vector scan follows upstream's parallel lane-wise value/index reduction.
It gathers a complete group of typed elements using standard intrinsics,
updates values and unsigned integer indices with compare/select masks, and
reduces lanes using value order and the smallest original index. It masks
unordered lanes rather than depending on hardware NaN min/max behavior.
Half values use upstream's signed ordinal transform; unsigned 64-bit comparisons
flip the sign bit before signed vector comparison.

Typed array views currently have no bundled contiguous numeric vector load.
The port therefore gathers bounded elements into V128 lanes; it does not cast
the backing storage or encode a second byte array. Every gather is bounded by
the actual view. Tails and leading NaNs are processed scalarly. Byte-lane indices
restart after 256 elements and 16-bit indices after 65536, before a wrapped index
can be reused. Float indices stay integer, avoiding floating index precision loss.

Windows, Linux, and macOS support `native`, `wasm`, `wasm-gc`, and `js`.

| Request | Execution policy |
| --- | --- |
| Omit `simd` | Scalar, except unmasked `argminmax` searches of `Float` and `Double` on linear-memory Wasm with at least 4096 elements. |
| `simd=false` | Scalar on every backend. |
| `simd=true`, native / Wasm | Portable vectors for supported 8–64-bit types when the view has more than two vectors of elements; smaller views use scalar. |
| `simd=true`, Wasm GC / JS / 128-bit types | Scalar fallback. |
| Masked search | Direct scalar scan by default, for `simd=false`, and on scalar-only backends; explicit native/Wasm vector requests search valid runs. |

Automatic policy follows local reversed-order measurements of the whole public
operation. The conservative threshold is a measured dispatch choice, not a
universal SIMD cutoff. Native portable SIMD remains available explicitly;
automatic native searches retain the faster measured scalar path. This port
does not reproduce Rust's SSE/AVX/AVX512/NEON feature-detection API or promise its
published speedups. See [BENCHMARK.md](BENCHMARK.md) for actual comparisons.

The validated toolchain is `moon 0.1.20261120` and
`moonc v0.10.22+7b085e9a4-nightly` (2026-11-22). SIMD imports are acknowledged
in this module's metadata. Native builds require a platform C compiler for
MoonBit-generated code; JavaScript tests require Node.js. CI uses nightly and
Node.js 24 and records the actual versions.

## Ownership and adaptations

Searches are synchronous and stateless. They never mutate elements or arrays,
retain input views, or copy caller storage. Returned indices describe the input
at the time of the call; the caller can still mutate its own array afterward.
There is no mutable search object or consuming Rust ownership convention.

| Upstream behavior / integration | MoonBit adaptation |
| --- | --- |
| Empty unmasked input panics | Optional indices return `None`. |
| Invalid bitmap range panics | Checked `BitmapError` with wide length metadata. |
| NaN propagation may depend on mixed payloads | The first valid NaN is guaranteed for every payload/sign. |
| Rust slice / Vec / ndarray / Arrow traits | Ordinary `ArrayView` and raw Arrow validity bitmap entry points; no Rust container dependencies. |
| Optional `half` feature | Binary16 and bfloat16 bit wrappers are always available, without a third-party half package. |
| Runtime CPU instruction-set selection | Portable V128, measured backend dispatch, and scalar fallback. |

## Tests and benchmarks

```text
moon -C argminmax check --target all --deny-warn
moon -C argminmax test --target all
moon -C argminmax info
moon -C argminmax fmt
moon -C benchmarks test argminmax --target all
moon run scripts/benchmark.mbtx argminmax
moon run scripts/benchmark_report.mbtx --self-test
```

The correctness suite checks all fourteen types against an independent sorted
oracle, every short tail, offset views, all integer limits, first ties across
lanes and chunks, mixed NaN payloads, infinities, signed zero, both half formats'
65536 encodings against independent IEEE formulas, and exact 128-bit word order.
Masked cases cover every bit offset through 23, partial bitmap views, dense and
sparse validity, all nulls/NaNs, valid/null NaNs, and overflow-safe validation.
Checked documentation and private lane/index tests also run in the suite.

The local Windows native export on 2026-11-25 reports **345/352 covered lines
(98.01%)**. Six uncovered lines belong to automatic vector selection and
scalar-only backend fallbacks; those paths run in the corresponding correctness
tests. The remaining line guards an unexpected empty result from a custom
element implementation on a nonempty valid run. Coverage includes production
files only, and uses native trace metadata immediately after instrumented tests.

In a shared checkout, select a current native runtime log with
`moon run scripts/coverage_report.mbtx local argminmax --runtime-log <path>`.
The log may contain multiple complete native coverage blocks. This preserves
other tasks' logs while excluding older counter layouts.

The development-only [comparison package](../benchmarks/argminmax) has 162 cases
per backend. It measures this library's explicit scalar/SIMD requests against an
independent linear MoonBit reference over identical prepared values. The Rust
crate identifies the source contract and is not timed across languages. Full
CI publication requires one source, run, and attempt across all three systems
and four backends; local results remain explicitly local.

## License and references

The [MIT license](LICENSE) preserves upstream attribution to
Jeroen Van Der Donckt. Upstream acknowledges inspiration from
[`minimalrust/argmm`](https://github.com/minimalrust/argmm).

- [Pinned upstream documentation](https://docs.rs/argminmax/0.7.1/argminmax/)
- [Upstream scalar algorithm](https://github.com/jvdd/argminmax/blob/f68aba5c251e9dc093f3939c0f9607c942228311/src/scalar/generic.rs)
- [Upstream SIMD reduction](https://github.com/jvdd/argminmax/blob/f68aba5c251e9dc093f3939c0f9607c942228311/src/simd/generic.rs)
- [Upstream half ordinals](https://github.com/jvdd/argminmax/blob/f68aba5c251e9dc093f3939c0f9607c942228311/src/scalar/scalar_half.rs)
- [MoonBit SIMD API](https://mooncakes.io/docs/moonbitlang/core/simd)
