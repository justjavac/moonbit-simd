# justjavac/utf8

Strict UTF-8 validation for MoonBit, ported from
[simdutf8 0.1.5](https://crates.io/crates/simdutf8/0.1.5). The module provides a
fast acceptance check, precise Rust-compatible errors, UTF-16 decoding, and
streaming validation. It has no third-party production dependencies.

## Upstream and algorithm

The crates.io release is pinned to Git revision
[`87ee8d9d20b849eae1974a82b248ee6fe7491bcc`](https://github.com/rusticstuff/simdutf8/tree/87ee8d9d20b849eae1974a82b248ee6fe7491bcc),
as recorded in its `.cargo_vcs_info.json`. This port adapts
`src/implementation/algorithm.rs` and the portable 128-bit operations in
`src/implementation/wasm32/simd128.rs`; it does not follow the moving main branch.

The linear-memory Wasm implementation uses the **lookup3** algorithm: three sixteen-entry
tables classify the high/low nibbles of the preceding byte and the high nibble
of the current byte. Their intersection marks missing/extra continuations,
overlong encodings, surrogate encodings, and values above U+10FFFF. Predecessor
vectors shifted by two and three bytes identify the remaining continuation
requirements. The implementation combines four checked sixteen-byte loads into
64-byte blocks, skips ASCII blocks, carries predecessor bytes across blocks,
and finishes with scalar validation within the view. Tables are initialized
once outside hot loops.

The native kernel in [native.mbt](native.mbt) checks the same byte grammar with
vector range masks. It flips each byte's sign bit to use signed comparisons
for unsigned ordering, and assembles predecessor vectors from two `UInt64`
lanes. This avoids the current x86 toolchain's per-lane emulation of byte
shuffles, swizzles, and unsigned comparisons. Continuation positions and the
E0/ED/F0/F4 restrictions are still checked for every lane. Both kernels use the
same bounded block traversal, ASCII shortcut, scalar tail, and error recovery.

The table bits in [simd.mbt](simd.mbt) are: missing continuation `1`, extra
continuation `2`, overlong three-byte sequence `4`, out-of-range four-byte
sequence `8`, surrogate `16`, overlong two-byte sequence `32`, exceptional
four-byte prefix `64`, and two consecutive continuations `128`. These reproduce
the pinned upstream tables rather than relying on a platform-specific gather.

## Installation and imports

This source is versioned as `0.1.0`. Until that version is published to
Mooncakes, use a local workspace entry pointing to this directory. A registry
release can be installed with:

```text
moon add justjavac/utf8@0.1.0
```

Import the module in the consuming `moon.pkg`:

```text
import {
  "justjavac/utf8",
}
```

The module is independently buildable and publishable. From the repository
root, select it with `moon check utf8 --target all --deny-warn` and
`moon test utf8 --target all`. Commands without a package selector operate on
the enclosing workspace. [README.mbt.md](README.mbt.md) contains checked examples,
and [pkg.generated.mbti](pkg.generated.mbti) is the generated public interface.

## API and semantics

| Operation | Result and purpose |
| --- | --- |
| `is_valid(BytesView, simd?=true)` | Boolean acceptance, corresponding to simdutf8 basic validation. |
| `validate(BytesView, simd?=true)` | `Unit` or a precise `Utf8Error`, corresponding to simdutf8 compat validation. |
| `from_utf8(BytesView, simd?=true)` | Validates and decodes into a MoonBit UTF-16 `String`. |
| `Utf8Error.valid_up_to()` | Number of valid bytes before the first malformed sequence. |
| `Utf8Error.error_len()` | `Some(1..3)` for malformed input, `None` for a potentially valid truncated suffix. |
| `Validator.new(simd?=true)` | Creates empty mutable streaming state. |
| `Validator.update(BytesView)` | Adds an arbitrarily split chunk, including empty chunks. |
| `Validator.finalize()` | Observes whether all supplied bytes are complete, valid UTF-8. |
| `Validator.copy()` / `reset()` | Forks independent state / discards accumulated state and errors. |

All offsets count **bytes relative to the input view**, not backing-buffer
positions, Unicode scalars, or UTF-16 code units. Validation accepts empty input,
embedded NUL, BOM bytes, and Unicode noncharacters. It rejects unexpected or
missing continuation bytes, C0/C1 and other overlong encodings, encoded
surrogates, leading bytes F5..FF, scalars above U+10FFFF, and truncated sequences.
These are encoding checks; no Unicode normalization or character-policy checks
are performed.

For `b"a\xF0\x9Fa"`, the error is at byte `1` with length `Some(2)`: the ASCII
byte that interrupts the sequence is not part of the malformed prefix. For
`b"a\xF0\x9F"`, the error is at byte `1` with length `None`. A bad second-byte
restriction, such as `b"\xED\xA0"`, has length `Some(1)` even at end of input.

`from_utf8` preserves a leading U+FEFF and embedded NUL. It validates first, then
uses the bundled core decoder on the known-valid bytes. Decoding allocates
UTF-16 storage; successful validation by itself does not construct a string.
Unlike Rust's borrowed UTF-8 `str`, the result is an independent immutable
MoonBit string. No mutable `from_utf8_mut` API is exposed because MoonBit byte
and string ownership differs from Rust.

## Streaming and ownership

`Validator` has private mutable representation. Assignment aliases the same
state; call `copy()` for an independent branch. No update retains a byte view or
buffers the whole stream. Pending state contains only continuation counts and
the bounds needed for the next byte. Errors are sticky until `reset()` and are
reported as a boolean at finalization, matching the basic streaming contract.

`finalize()` observes rather than consumes state. It can be called repeatedly,
and updates may continue afterward. A false result caused solely by an
incomplete suffix can become true after the missing continuation arrives. A
malformed sequence cannot be repaired by later chunks. `reset()` preserves the
SIMD preference, and `copy()` preserves pending sequence restrictions.

Complete large portions of updates use the requested validator. Sequence
fragments crossing chunk boundaries and short chunks use scalar transitions.
There is no artificial maximum total stream length because no cumulative
length counter is stored; individual views use MoonBit's `Int` length limits.

## Backends and limits

| Backend | SIMD request |
| --- | --- |
| `native` | V128 range masks and predecessor-lane arithmetic for inputs of at least 64 bytes. Requires a platform C compiler. |
| `wasm` | V128 lookup algorithm for inputs of at least 64 bytes. Requires a host supporting Wasm SIMD. |
| `wasm-gc` | Strict scalar fallback. |
| `js` | Strict scalar fallback; tests require Node.js. |

The supported systems are Windows, Linux, and macOS. The port uses ordinary
MoonBit and core SIMD operations, with no Rust/C FFI, unsafe byte-string views,
AVX/SSE/NEON runtime feature dispatch, prefetching, optional CPU instructions,
or architecture-specific public implementation traits. The 64-byte dispatch
boundary follows the pinned upstream high-level API; it is not a claim that
SIMD is faster on every input or backend. Unaligned byte views are supported,
and every vector load is bounded by the view itself.

The vector basic path aggregates errors until the full input is checked. The
compat path checks blocks as it processes them and scans around the first
failing block to recover exact errors. Scalar fallback may fail immediately.
Their acceptance and error semantics agree, while their costs on early errors
differ. See [BENCHMARK.md](BENCHMARK.md) for comparison methods and results.

Validated with `moon 0.1.20261120` and
`moonc v0.10.22+7b085e9a4-nightly` (2026-11-22). Experimental core SIMD is enabled
in this module's package metadata; consumers import only `justjavac/utf8`.
Revalidate experimental APIs and dispatch choices after toolchain updates.

## Correctness and development

Tests retain upstream language samples, incomplete-sequence expectations, error
messages, and boundary regressions. An independent integer code-point oracle
checks all 65,536 byte pairs in short inputs and across a vector boundary,
deterministic varied byte corpora, and independently encoded Unicode scalar
samples. Tests cover all sixteen tail lengths, 64-byte boundaries, offset 0..15
views with invalid sentinels, first-error behavior, streaming splits, empty
updates, incomplete observation, reset, assignment aliasing, and independent
copies. Core decoding provides an additional differential check.

[rust_vectors_test.mbt](rust_vectors_test.mbt) records 620 results from Rust's
standard-library `str::from_utf8`, independently of simdutf8's implementation.
Regenerate them with `moon run scripts/utf8_oracle.mbtx` from the repository
root; regeneration requires `rustc`, while normal tests do not. The generator
records the Rust version and deterministic seed in the fixture header.

```text
moon check utf8 --target all --deny-warn
moon test utf8 --target all
moon info
moon fmt
moon test utf8 --target native --enable-coverage
moon run scripts/coverage_report.mbtx local utf8
moon -C benchmarks test utf8 --target all
moon run scripts/benchmark.mbtx utf8
```

Run native coverage export immediately after the instrumented native test.
Comparison dependencies remain in the development-only `benchmarks/` workspace.

The Windows native export on the validated toolchain reports **149/170 counters
(87.65%)**, above the repository's 80% target. Its source metadata also retains
twenty counters for the Wasm-only lookup kernel and non-native fallback, which
cannot execute in a native run. Native vector checks, error accessors, public
dispatch, and streaming operations are covered; one scalar invariant-abort
counter is unreachable for the defined byte grammar. These are reported as
ordinary uncovered counters without coverage exclusions.

## License and references

This module is [MIT licensed](LICENSE), using the MIT option of simdutf8's dual
license and preserving its attribution. The lookup algorithm traces through
simdutf8 and simd-json.rs to simdjson. Benchmark dependencies retain their own
licenses and are not incorporated into the published module.

- [Pinned simdutf8 source](https://github.com/rusticstuff/simdutf8/tree/87ee8d9d20b849eae1974a82b248ee6fe7491bcc).
- [Rust `Utf8Error` contract](https://doc.rust-lang.org/std/str/struct.Utf8Error.html).
- John Keiser and Daniel Lemire, [Validating UTF-8 In Less Than One Instruction Per Byte](https://arxiv.org/abs/2010.03090), Software: Practice and Experience 51(5), 2021.
- [Unicode UTF-8 encoding forms](https://www.unicode.org/versions/Unicode16.0.0/core-spec/chapter-3/).
- [MoonBit SIMD API](https://mooncakes.io/docs/moonbitlang/core/simd).
