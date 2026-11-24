# justjavac/crc32

Portable IEEE CRC-32 for MoonBit, with one-shot hashing, incremental state,
checksum continuation, combination of independently processed blocks, and an
optional SIMD implementation. Licensed under [MIT](LICENSE).

For a short executable introduction, see [README.mbt.md](README.mbt.md).
For formal signatures, see [pkg.generated.mbti](pkg.generated.mbti).

## Algorithm

The module implements CRC-32/ISO-HDLC, commonly called IEEE CRC-32 and used by
PNG, ZIP, and gzip.

| Parameter | Value |
| --- | --- |
| Width | 32 bits |
| Polynomial | `0x04C11DB7` |
| Reflected polynomial | `0xEDB88320` |
| Initial register | `0xFFFFFFFF` |
| Input and output reflection | Enabled |
| Final XOR | `0xFFFFFFFF` |
| Empty input checksum | `0x00000000` |
| `123456789` check value | `0xCBF43926` |

Public results and initial values are finalized `UInt` checksums, shown as
`UInt32` in the generated interface. Passing zero starts a standard computation;
passing a previous result continues it. Callers never invert the internal
register themselves.

Input is a sequence of bytes. `BytesView` parameters accept `Bytes` and subviews
without copying. Encode strings into bytes explicitly before hashing. The result
is an unsigned integer; apply a file format's required byte order when storing it.

## Installation and imports

Once version `0.1.0` is published on Mooncakes, add it to a consuming module:

```text
moon add justjavac/crc32@0.1.0
```

In the consuming package's `moon.pkg`:

```text
import {
  "justjavac/crc32",
}
```

Use `@crc32` for its API. For source development before publication, this
repository's `moon.work` already includes the local `crc32/` module. It has its
own `moon.mod`, `moon.pkg`, documentation, tests, and license and can be copied
or checked out as a standalone module without sibling modules.

## Public API

The optional `simd` argument defaults to false wherever it appears. It requests
vector processing on `wasm` and `native`; `wasm-gc` and `js` use the scalar path.

| Operation | Behavior |
| --- | --- |
| `hash(data, simd?=false)` | Compute a standard finalized checksum. |
| `update(initial, data, simd?=false)` | Append bytes to a finalized checksum without counting their length. |
| `combine(first, second, second_len)` | Join a prefix checksum to a standard suffix checksum of the exact supplied byte length. |
| `Hasher::new(simd?=false)` | Create standard empty state. |
| `Hasher::new_with_initial(initial, simd?=false)` | Resume a finalized checksum with unknown prefix length; start its count at zero. |
| `Hasher::new_with_initial_len(initial, amount, simd?=false)` | Resume a finalized checksum with a known `UInt64` count. |
| `state.update(data)` | Append bytes, updating checksum and count. |
| `state.finalize()` | Observe the checksum without consuming or changing state. |
| `state.total_len()` | Return the represented `UInt64` byte count. |
| `state.copy()` | Fork an independent state with the same checksum, count, and SIMD selection. |
| `state.reset()` | Restore checksum and count to zero, retaining SIMD selection. |
| `state.combine(other)` | Append the checksum and complete length of a standard suffix state. |

All exported declarations have detailed checked doc comments in
[hasher.mbt](hasher.mbt) and [combine.mbt](combine.mbt).

## One-shot hashing

```mbt
test {
  assert_eq(@crc32.hash(b""), 0U)
  assert_eq(@crc32.hash(b"123456789"), 0xCBF43926U)
  assert_eq(@crc32.hash(b"hello world"), 0x0D4A1185U)
  assert_eq(@crc32.hash(b"123456789", simd=true), 0xCBF43926U)
}
```

The input is read without mutation, and only the specified view is hashed.
Empty input is valid on every backend.

## Streaming and continuation

```mbt
test {
  let state = @crc32.Hasher::new()
  state.update(b"hello")
  state.update(b" ")
  state.update(b"world")
  assert_eq(state.finalize(), 0x0D4A1185U)
  assert_eq(state.total_len(), 11UL)

  // Observing the result leaves the state available for more input.
  state.update(b"!")
  assert_eq(state.finalize(), @crc32.hash(b"hello world!"))
}
```

Chunk boundaries and empty updates do not affect the result. Unlike Rust's
consuming `crc32fast::Hasher::finalize`, this method observes a reusable MoonBit
object. `reset()` starts a separate standard computation on the same object.

Continue from a checksum without constructing a hasher:

```mbt
test {
  let prefix = @crc32.hash(b"1234")
  assert_eq(@crc32.update(prefix, b"56789"), 0xCBF43926U)
  assert_eq(@crc32.update(prefix, b""), prefix)
}
```

To track an existing prefix's length, use
`Hasher::new_with_initial_len(@crc32.hash(prefix), prefix.length().to_uint64())`.
`new_with_initial()` resumes the same checksum but counts only later updates
because the original prefix length is unknown.

## Copying and mutation

MoonBit structs have reference semantics. Assignment shares this hasher's
mutable state; use `copy()` when computations should diverge:

```mbt
test {
  let prefix = @crc32.Hasher::new()
  prefix.update(b"hello")
  let branch = prefix.copy()
  branch.update(b" world")
  assert_eq(branch.finalize(), @crc32.hash(b"hello world"))
  assert_eq(prefix.finalize(), @crc32.hash(b"hello"))
}
```

Updating, resetting, or combining one independent copy leaves the other
unchanged. References that share the same object observe those changes.

## Combining independent blocks

If blocks are hashed separately, join their results without reading their bytes:

```mbt
test {
  let first = @crc32.hash(b"hello")
  let second = @crc32.hash(b" world")
  assert_eq(@crc32.combine(first, second, 6), @crc32.hash(b"hello world"))
}
```

The suffix checksum must be computed with standard initialization, and its
supplied length must be exact. The prefix may be a continued checksum. The
function cannot verify a checksum/length pair against unavailable bytes. A
zero suffix length returns the prefix checksum regardless of the suffix value.

The stateful form adds the suffix's represented count:

```mbt
test {
  let prefix = @crc32.Hasher::new()
  prefix.update(b"hello")
  let suffix = @crc32.Hasher::new()
  suffix.update(b" world")
  prefix.combine(suffix)
  assert_eq(prefix.finalize(), @crc32.hash(b"hello world"))
  assert_eq(prefix.total_len(), 11UL)
  assert_eq(suffix.total_len(), 6UL)
}
```

Normally `other` is unchanged. Combining a hasher with itself doubles the
sequence when it represents a complete standard checksum and count. Combination
is associative when all suffix counts are accurate and the combined count fits.
Use `new_with_initial_len()` when restoring a suffix state; an unknown prefix
length from `new_with_initial()` is insufficient for that role.

Combination uses polynomial arithmetic over GF(2), with work proportional to
the logarithm of the suffix length and no per-call table allocation. The free
function supports the full `UInt64` suffix-length range. A hasher's represented
count must fit in `UInt64`; updates and combinations panic before changing it
if the count would exceed `2^64 - 1`.

## SIMD and portability

| Backend | Default | With `simd=true` |
| --- | --- | --- |
| `native` | Slicing-by-eight scalar | Vector slicing-by-sixteen |
| `wasm` | Slicing-by-eight scalar | SIMD128 slicing-by-sixteen |
| `wasm-gc` | Slicing-by-eight scalar | Scalar fallback |
| `js` | Slicing-by-eight scalar | Scalar fallback |

Both implementations derive their slicing tables from the same reflected
polynomial once at startup. Sixteen tables occupy 16 KiB. Scalar code consumes
eight-byte blocks and a bytewise tail. Vector code safely loads sixteen bytes,
uses four 32-bit lanes for shifts, masks, and XOR reduction, performs positional
table lookups, and sends the remaining short tail to scalar code.

The core SIMD API does not provide a general table-gather operation, so table
reads remain scalar. This implementation uses portable SIMD operations rather
than x86 PCLMULQDQ, AArch64 CRC instructions, or runtime CPU feature detection.
It has no module-specific FFI or architecture-dependent compiler flags.

Little-endian bitstring patterns define input order on every host. The
`v128le` pattern checks that sixteen bytes are available before loading, including
when a view starts at an unaligned offset. Tests compare both implementations to
an independent forward-polynomial bitwise oracle.

Use a MoonBit nightly providing `moonbitlang/core/simd` and the built-in `V128`
type. The older `moonbitlang/core/v128` path is deprecated. The validated compiler
is `moonc v0.10.22+7b085e9a4-nightly` from November 22, 2026, used with
`moon 0.1.20261120`. SIMD APIs are experimental; the importing package explicitly
allows them, and this package suppresses only their intentional experimental
alerts and backend-dependent unused-import warnings.

Windows, Linux, and macOS are supported. Native builds require a C compiler;
the JavaScript backend requires Node.js. CI runs all four backends on each OS.

## Performance

The complete CI performance report is [BENCHMARK.md](BENCHMARK.md), with its
original statistics and provenance in `BENCHMARK-DATA.json`. The report covers
Linux, macOS, and Windows across all four supported backends, including input
sizes, nonzero view offsets, streaming chunk sizes, and full-width combination
lengths. It records CPU, compiler, sample counts, latency, throughput, and variation.

Scalar processing remains the default based on the initial local measurements.
The vector path still performs scalar table lookups, so SIMD requests can be
slower. Use the report for the measured backend and machine; hosted-runner results
do not establish a universal speed guarantee.

Run the same suite locally:

```text
moon bench --target native --release
moon bench --target wasm --release
moon run scripts/benchmark.mbtx crc32
```

The last command runs all four backends sequentially from the parent workspace
and writes JSON and raw logs to `_build/benchmarks/crc32/`. Those measurements are
marked local; the CI report generator requires a complete, consistent CI run.

To request vectors for streaming input:

```mbt
test {
  let state = @crc32.Hasher::new(simd=true)
  state.update(b"a sixteen-byte block followed by a tail")
  assert_eq(state.finalize(), @crc32.hash(b"a sixteen-byte block followed by a tail"))
}
```

Inputs shorter than sixteen bytes use scalar code even when vectors are
requested. `copy()` and `reset()` retain the selected implementation policy.

## Development and verification

Run from the workspace root or from this module:

```text
moon check --target all --deny-warn
moon test --target all
moon info
moon fmt
```

Coverage:

```text
moon test --target all --enable-coverage
moon coverage analyze -p justjavac/crc32 -- -f cobertura -o coverage-crc32.xml
```

Tests include standard reference vectors; all single-byte values; nonzero
initial checksums; empty updates; vector and scalar block boundaries; unaligned
subviews; varied streaming chunk sizes; copying and reset; associative and
self-combination; crc32fast's large-length combination vectors; and represented
length overflow. The README examples and public doc comments are checked tests.

Coverage uploads are managed by the parent workspace's GitHub Actions workflow,
with separate Codecov flags for Linux, macOS, and Windows. See the workspace
README for Codecov setup and the four coverage badges.

The initial Windows Cobertura report records 98.75% coverage (79/80 instrumented
locations). Its remaining location is the managed-backend dispatch wrapper,
which is exercised by the JavaScript and Wasm GC test runs but is not included
in the default analysis's merged counters. Generate API documentation with
`moon doc` from this module, or `moon -C crc32 doc` from the workspace root.

## References and license

- [crc32fast](https://crates.io/crates/crc32fast): public API conventions,
  algorithm design context, and golden checksum-combination vectors.
- [crc32fast source](https://github.com/srijs/rust-crc32fast): reference baseline
  and combination behavior.
- [MoonBit SIMD API](https://mooncakes.io/docs/moonbitlang/core/simd): current
  portable vector operations.
- [Original v128 documentation](https://mooncakes.io/docs/moonbitlang/core/v128):
  the original package path before its rename.

This MoonBit implementation, its documentation, and tests are distributed under
the complete [MIT license](LICENSE) included in this module.
