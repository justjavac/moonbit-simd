# justjavac/atoi

Portable decimal byte-to-integer parsing, ported from
[`atoi_simd 0.18.1`](https://crates.io/crates/atoi_simd/0.18.1) to pure MoonBit.
The module validates ASCII decimal input, checks fixed-width overflow, supports
full and prefix parsing, and accelerates complete 16-byte blocks with standard
`V128` intrinsics. Its scalar/SWAR implementation supports the same contract.

## Source and scope

The port is pinned to upstream Git revision
[`f0952f7bb71ee581dcc2871841f9b2dbd241bd7e`](https://github.com/RoDmitry/atoi_simd/tree/f0952f7bb71ee581dcc2871841f9b2dbd241bd7e).
The published crate's SHA-256 is
`f3cdb3708a128e559a30fb830e8a77a5022ee6902806925c216658652b452a44`.
The MIT option of upstream's `MIT OR Apache-2.0` license is selected; Dmitry
Rodionov's copyright is retained in [LICENSE](LICENSE).

Implemented features are all six current parsing operations, the ten fixed-width
integer ranges from 8 through 128 bits, signed minimum values, exact prefix sizes,
the leading-plus and unbounded-leading-zero options, structured validation
errors, and bounded vector loads. Rust's architecture-specific SSE/AVX/Neon
loads and reduction instructions are adapted to portable MoonBit SIMD.

Rust pointer-width `usize`/`isize` aliases are omitted: choose explicit `UInt`,
`Int`, `UInt64`, or `Int64` bounds across backends. The deprecated Rust aliases
`parse_any*` and `parse_skipped` are omitted from this new MoonBit API. Their
replacements are `parse_prefix*` and `parse(..., skip_zeroes=true, skip_plus=true)`.
There is no production dependency beyond the bundled MoonBit core, and no FFI,
native stub, optional CPU instruction, or maintained generated backend source.

## Installation and imports

Version `0.1.0` is currently a source workspace module. Once it is published to
Mooncakes, install the version explicitly:

```text
moon add justjavac/atoi@0.1.0
```

Use the root package in your `moon.pkg`:

```text
import {
  "justjavac/atoi",
}
```

For local development, add `atoi/` to `moon.work` and declare the module version
in the consuming module's own `moon.mod`, as the development benchmark workspace
does. The library has its own manifest, license, tests, and generated interface.

## Results and API

Annotate the result to choose the integer width. `Parse` is implemented for all
listed types; `ParseNeg` is implemented only for signed results.

| Rust range | MoonBit result | Inclusive bounds |
| --- | --- | --- |
| `u8` | `Byte` | 0 through 255 |
| `i8` | `@atoi.Int8` | -128 through 127 |
| `u16` | `UInt16` | 0 through 65535 |
| `i16` | `Int16` | -32768 through 32767 |
| `u32` | `UInt` | 0 through 4294967295 |
| `i32` | `Int` | -2147483648 through 2147483647 |
| `u64` | `UInt64` | 0 through 18446744073709551615 |
| `i64` | `Int64` | -9223372036854775808 through 9223372036854775807 |
| `u128` | `@atoi.UInt128` | 0 through 340282366920938463463374607431768211455 |
| `i128` | `@atoi.Int128` | -170141183460469231731687303715884105728 through 170141183460469231731687303715884105727 |

| Function | Result | Sign handling |
| --- | --- | --- |
| `parse(data, ...)` | `T` | Signed `T` accepts `-`; enabled `skip_plus` accepts `+` |
| `parse_pos(data, ...)` | `T` | Rejects both signs; result is nonnegative |
| `parse_neg(data, ...)` | Signed `T` | Sign-free digits become a negative value |
| `parse_prefix(data, ...)` | `(T, Int)` | Same signs as `parse` |
| `parse_prefix_pos(data, ...)` | `(T, Int)` | Sign-free nonnegative prefix |
| `parse_prefix_neg(data, ...)` | `(Signed T, Int)` | Sign-free negative prefix |

All functions accept `BytesView`, raise `ParseError`, and leave input unchanged.
`Bytes` implicitly supplies a view. Full parsers require the entire view to be
decimal digits after the optional sign. Prefix parsers stop before the first
non-digit and return the consumed **byte** count, including the sign and every
leading zero. At least one digit is required. A numeric prefix's range is checked
in full; overflow never returns a truncated successful result.

| Option | Default | Applies to | Behavior |
| --- | --- | --- | --- |
| `skip_plus` | `false` | `parse`, `parse_prefix` | Permits one initial `+`; it does not permit a second sign |
| `skip_zeroes` | `false` | All functions | Removes leading ASCII zeroes from the 64/128-bit digit budget |
| `simd` | `true` | All functions | Requests bounded V128 work on native/Wasm, with scalar/SWAR tails and backend fallback |

Only ASCII bytes `0` through `9` are digits. Whitespace, underscores, exponents,
decimal points, radix prefixes, NUL, and Unicode digits are rejected by full
parsers. For example, a prefix parser consumes only the `0` in `0x10`. Unsigned
types reject `-0`; signed negative zero returns ordinary zero.

Without `skip_zeroes`, signed 64-bit results have a 19-digit budget, unsigned
64-bit results have a 20-digit budget, and both 128-bit results have 39-digit
budgets. Leading zeroes count toward these budgets. Smaller types accept
arbitrarily many leading zeroes, matching upstream's complete scalar parsing;
they still enforce their numeric range. `skip_zeroes=true` permits arbitrarily
many leading zeroes for every result type, including an all-zero input.

## Examples

```mbt
let value : Int64 = @atoi.parse(b"-9223372036854775808")
assert_eq(value, -9223372036854775808L)

let prefix : (UInt64, Int) = @atoi.parse_prefix(
  b"+00123,rest", skip_plus=true,
)
assert_eq(prefix, (123UL, 6))

let negative : Int = @atoi.parse_neg(b"2147483648")
assert_eq(negative, -2147483648)

let wide : @atoi.UInt128 = @atoi.parse(
  b"340282366920938463463374607431768211455",
)
assert_eq(wide.to_words(), (0xFFFFFFFFFFFFFFFFUL, 0xFFFFFFFFFFFFFFFFUL))
```

For an input `String`, explicitly encode it with the bundled
`moonbitlang/core/encoding/utf8` package before calling the byte parser. This
conversion may allocate and is outside the library's byte-oriented operation.
StringView offsets count UTF-16 code units; parsing and consumption count bytes.

See [README.mbt.md](README.mbt.md) for short checked examples and
[pkg.generated.mbti](pkg.generated.mbti) for the compiler-generated API.

## Errors and ownership

| Error | Meaning and payload |
| --- | --- |
| `Empty` | No initial digit, including empty input, sign-only input, and an invalid first byte |
| `Size(length, input)` | A 64/128-bit digit budget was exceeded; `length` is the observed prefix size when one extra digit proves rejection |
| `Overflow(input)` | The permitted-length digit prefix exceeds the selected signed/unsigned range |
| `Invalid64(magnitude, index, input)` | A full parse found a non-digit suffix; retains the unsigned magnitude and byte offset |
| `Invalid128(magnitude, index, input)` | Same failure with an exact `UInt128` magnitude |

Stored error input excludes an accepted initial sign. It preserves the original
remaining view even if zeroes were skipped; an invalid index is relative to this
stored view, rather than the backing buffer. A size's observed count includes
skipped zeroes. A rejected long digit input is inspected only far enough to prove
the size violation, so the `Size` count need not equal the entire input length.
Error precedence is size, then numeric overflow, then an invalid suffix.

```mbt
try (@atoi.parse(b"-123x") : Int64) catch {
  @atoi.Invalid64(magnitude, index, input) => {
    assert_eq(magnitude, 123UL)
    assert_eq(index, 3)
    assert_true(input == b"123x")
  }
  _ => fail("Unexpected error")
} noraise {
  _ => fail("Expected an invalid suffix")
}
```

The parser has no mutable state. `Int8`, `UInt128`, and `Int128` have private,
immutable representations; shared assignments need no independent copy.
`Int8.to_int()` exposes its exact value. `UInt128.from_words(high~, low~)` and
`to_words()` use decreasing word significance. `Int128.from_bits()` and
`to_bits()` interpret the same pair in two's complement; `is_negative()` reads
its sign bit. Their decimal `to_string()` methods are exact on every backend.
Formatting allocates strings; numeric parsing never converts through a float
or an arbitrary-precision type.

Input bytes and views are immutable. Retained errors safely retain their input
snapshot, and may keep the backing buffer alive. Parsing a subview neither copies
it nor reads neighboring backing bytes. There is no streaming parser state;
prefix parsing supplies the consumed offset for callers processing a token stream.

## Upstream compatibility choices

Upstream's scalar and architecture-specific implementations do not have identical
edge-case behavior. This port exposes one stable contract on all backends:

| Area | MoonBit behavior and reason |
| --- | --- |
| Leading `+` in prefix mode | Counts the accepted plus byte; upstream 0.18.1 omits it from successful consumption |
| Long narrow-integer prefixes | Checks the entire digit prefix; upstream can return only the first 16 digits when zero skipping is disabled |
| Leading-zero limits | Keeps scalar full-parse acceptance for narrow types and explicit 19/20/39-digit budgets for wider types; upstream vector acceptance can differ |
| Failure ordering | Uses size, overflow, then invalid suffix consistently; upstream SIMD can report an invalid suffix before checking a smaller result range |
| Error payloads | Retains sign-free views before zero removal and uses type-width-specific `Invalid64`/`Invalid128`; upstream payload slices and invalid variants can depend on its selected backend |
| Excessive-size counts | Reports the first observed extra digit, instead of a load-width-dependent count |

These are intentional validation and ownership adaptations. Normal decimal
results, signed minima, prefix values, and the current six operations retain
upstream's meaning. The generated Rust corpus covers portable overlapping
behavior; independent reference tests protect the complete MoonBit contract and
the documented differences.

## Algorithm and portability

Scalar/SWAR scanning translates upstream's `check_len_8` mask: high nibbles and
a wrapping addition detect the first byte outside the ASCII decimal range.
Little-endian checked bitstring loads avoid alignment and host-endian assumptions.
Eight validated digits are reduced in a tree using weights 10, 100, and 10000.
Remaining bytes are accumulated individually.
After leading zeroes are removed, narrow types inspect at most one 16-byte block
before rejecting a prefix that exceeds their range; they do not scan an arbitrarily
long nonzero integer merely to discover overflow.

The vector path checks 16 lanes with signed ASCII-range comparisons; high-bit
bytes are rejected by the lower-bound comparison. Validated digits are reduced
to pairs, four-digit groups, and eight-digit groups using portable integer
multiplication, dot products, and narrowing. Intermediate values are bounded
so narrowing cannot saturate. Two eight-digit groups produce one exact UInt64
block. Range checks precede 64-bit multiplication; 128-bit results append groups
with checked base-2^32 carries, splitting vector blocks into two eight-digit
updates. Leading zeroes use a separate scalar/SWAR scan for both requests.
Local complete-operation measurements found the vector zero scanner slower on
native and Wasm, so only the significant digit scanning/reduction selects vectors.
An all-zero input can therefore remain entirely scalar/SWAR with `simd=true`.

| Backend | Explicit `simd=true` request |
| --- | --- |
| `native` | V128 scanning/reduction for complete 16-byte blocks; bounded scalar/SWAR tails |
| `wasm` | V128 scanning/reduction in linear memory; bounded scalar/SWAR tails |
| `wasm-gc` | Scalar/SWAR fallback |
| `js` | Scalar/SWAR fallback |

Fewer than 16 remaining significant input bytes use scalar/SWAR even when vectors
are requested. Leading-zero removal always uses scalar/SWAR.
A SIMD option alone does not establish vector execution or a speedup. Compare
this module's scalar and SIMD requests for the actual workload in
[BENCHMARK.md](BENCHMARK.md). Core parser comparisons also include representation,
UTF-8 conversion, and required prefix/range adaptations.

Windows, Linux, and macOS are supported. Native requires a platform C compiler
for MoonBit-generated artifacts; JavaScript requires Node.js. The validated
toolchain is `moon 0.1.20261120` and
`moonc v0.10.22+7b085e9a4-nightly` (2026-11-22). CI selects nightly, initializes
Mooncakes with `moon update`, uses Node.js 24, and records actual versions.
Revalidate the experimental `core/simd` intrinsics and measurements after upgrades.

## Correctness and regeneration

The suite covers all ten integer ranges, one beyond each bound, minimum signed
magnitudes, zero and signs, malformed ASCII/UTF-8 bytes, leading-zero budgets,
full/prefix failure ordering, offset views, every short/vector tail, and retained
error views. SWAR masks are checked against every byte value in every word slot
and 4096 deterministic random words. Vector masks exercise every byte in every
lane; reductions use independent per-byte arithmetic.

An independent byte-wise BigInt oracle exercises all six public operations,
result types, and option combinations. Random full-width word pairs verify exact
128-bit formatting and decimal round trips. The pinned Rust corpus contains
2745 cases, generated from both a generic CPU build and a native CPU build of
`atoi_simd 0.18.1`. Both agree after correcting the plus-prefix byte count;
MoonBit scalar and SIMD requests replay the same results. This corpus does not
claim equivalence for upstream's documented backend-dependent edge cases.

Run from this repository's root:

```text
moon check atoi --target all --deny-warn
moon test atoi --target all
moon info
moon fmt
moon test --target native --enable-coverage
moon run scripts/coverage_report.mbtx local crc32 url utf8 atoi
moon -C benchmarks test atoi --target all
moon run scripts/benchmark_report.mbtx --self-test
moon run scripts/benchmark.mbtx atoi
```

To regenerate the Rust fixtures, run `moon run scripts/atoi_oracle.mbtx` with
Rust/Cargo and network access to crates.io. Its reference-only dependencies are
pinned to `atoi_simd 0.18.1`, `debug_unsafe 0.1.4`, and `rustversion 1.0.23`.
The seed is `0xA7015EED`. Commands, compiler version, Cargo.lock, input protocol,
and both raw output/build logs remain under `_build/atoi-oracle/`. The generated
fixture file is ordinary MoonBit source, so regular tests require no Rust compiler
or network access. Format the script explicitly and review regenerated expectations.

## References

- [Pinned atoi_simd source](https://github.com/RoDmitry/atoi_simd/tree/f0952f7bb71ee581dcc2871841f9b2dbd241bd7e)
- [atoi_simd 0.18.1 API](https://docs.rs/atoi_simd/0.18.1/atoi_simd/)
- [Original faster integer parsing explanation](https://rust-malaysia.github.io/code/2020/07/11/faster-integer-parsing.html)
- [MoonBit core SIMD](https://mooncakes.io/docs/moonbitlang/core/simd)
- [Development comparisons](../benchmarks/README.md)
