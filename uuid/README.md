# UUID parsing and formatting

`justjavac/uuid` is a portable MoonBit port of
[`uuid-simd 0.8.0`](https://crates.io/crates/uuid-simd/0.8.0), with scalar
implementations and V128 acceleration. It parses UUID text or arbitrary ASCII
bytes, formats compact and hyphenated output in either case, and writes into
reusable byte buffers. UUID values are immutable and preserve every bit.

## Upstream and specification

The port is pinned to Nugine/simd commit
[`d74c030d9dc4f3cae02146d1f497ff62726ef09a`](https://github.com/Nugine/simd/tree/d74c030d9dc4f3cae02146d1f497ff62726ef09a/crates/uuid-simd).
The published `uuid-simd-0.8.0.crate` SHA-256 is
`23b082222b4f6619906941c17eb2297fff4c2fb96cb60164170522942a200bd8`.
The grammar and nibble operations follow that revision. All accepted, rejected,
and formatting cases from `tests/it.rs` are retained, with the upstream MIT
attribution in [LICENSE](LICENSE).

Parsing accepts these exact ASCII spellings, with case-insensitive hex digits:

| Form | Length | Example |
| --- | --- | --- |
| Simple | 32 | `67e5504410b1426f9247bb680e5fe0c8` |
| Hyphenated | 36 | `67e55044-10b1-426f-9247-bb680e5fe0c8` |
| Microsoft GUID wrapper | 38 | `{67e55044-10b1-426f-9247-bb680e5fe0c8}` |
| URN | 45 | `urn:uuid:67e55044-10b1-426f-9247-bb680e5fe0c8` |

The prefix `urn:uuid:` is exactly lowercase, matching upstream. Whitespace,
misplaced hyphens, extra wrappers, non-ASCII digits, and embedded NUL are
rejected. Parsing validates spelling, not version/variant bits: nil, max,
reserved variants, and every other 128-bit pattern are valid inputs. The
hyphenated spelling follows the RFC 9562 `8-4-4-4-12` layout.

Rust's `Out` and `UuidExt` APIs are adapted to an owned MoonBit `Uuid` and
checked buffer writers. Parsing constructs an immutable value rather than
mutating an uninitialized destination. Rust formatter lifetimes, CPU
multiversion dispatch, and optional Rust dependencies are not reproduced.
UUID generation is outside the upstream codec's scope.

## Installation and imports

The source version is `0.1.0`; this change does not publish a Mooncakes release.
Include the checkout's library in your application's `moon.work`:

```text
members = [
  ".",
  "../moonbit-simd/uuid",
]
```

Declare the local module in your `moon.mod` and its package in `moon.pkg`:

```text
// moon.mod
import {
  "justjavac/uuid@0.1.0",
}

// moon.pkg
import {
  "justjavac/uuid",
}
```

After a release appears on Mooncakes, install its listed version with
`moon add justjavac/uuid@VERSION`. The library has no external dependencies;
comparison dependencies belong exclusively to `benchmarks/`.

## API and examples

[pkg.generated.mbti](pkg.generated.mbti) is the generated public interface;
[README.mbt.md](README.mbt.md) contains compiler-checked examples.

| API | Contract |
| --- | --- |
| `parse(StringView, algorithm?)` | Parses any of the four spellings; raises `InvalidUuid`. |
| `parse_simple(StringView, algorithm?)` | Requires exactly 32 hex code units. |
| `parse_hyphenated(StringView, algorithm?)` | Requires the exact 36-unit hyphenated form. |
| `parse_bytes(BytesView, algorithm?)` | Parses the same spellings without UTF-8 conversion. |
| `Uuid::from_bytes(BytesView)` | Requires exactly 16 binary bytes in network order. |
| `Uuid::to_bytes()` | Returns 16 immutable binary bytes in network order. |
| `Uuid::format_simple(case?, algorithm?)` | Returns 32 ASCII characters. |
| `Uuid::format_hyphenated(case?, algorithm?)` | Returns 36 ASCII characters. |
| `Uuid::write_simple(FixedArray[Byte], offset?, case?, algorithm?)` | Writes 32 bytes into a checked destination range. |
| `Uuid::write_hyphenated(FixedArray[Byte], offset?, case?, algorithm?)` | Writes 36 bytes into a checked range. |
| `Uuid::to_string()` / `Show` | Lowercase hyphenated display. |
| `simd_available()` | Reports whether this backend includes V128 kernels. |

`case` defaults to `Lower`; `Upper` changes only hexadecimal letters.
`algorithm` defaults to `Auto`. `Uuid` implements `Eq`, `Compare`, `Hash`, and
`Debug`; ordering follows its unsigned network-order binary value.

```moonbit
let id = @uuid.parse("67E55044-10b1-426f-9247-bb680e5fe0c8")
assert_eq(id.format_simple(), "67e5504410b1426f9247bb680e5fe0c8")
assert_eq(
  id.format_hyphenated(case=@uuid.Upper),
  "67E55044-10B1-426F-9247-BB680E5FE0C8",
)
```

Checked `UuidError` failures have these meanings:

| Error | Meaning |
| --- | --- |
| `InvalidUuid` | Invalid spelling, length, wrapper, hyphen, or hex digit; opaque like upstream's error. |
| `InvalidByteLength(actual)` | Binary construction received a view other than 16 bytes. |
| `InvalidBuffer(offset~, required~, length~)` | The complete output range does not fit; no byte changed. |

```moonbit
let id = @uuid.parse_bytes(b"67e5504410b1426f9247bb680e5fe0c8")
let output : FixedArray[Byte] = FixedArray::make(38, b'!')
id.write_hyphenated(output, offset=1, algorithm=@uuid.Simd)
assert_eq(
  Bytes::from_array(output),
  b"!67e55044-10b1-426f-9247-bb680e5fe0c8!",
)
```

Writers preserve all bytes outside their range, retain no destination, and
check capacity without overflowing `offset + length`. Negative and extremely
large offsets fail before mutation. String formatting includes allocation and
ASCII decoding; buffer writers reuse caller-provided storage.

## Representation and ownership

`Uuid` stores two private `UInt64` words with the first textual byte most
significant. Structs have reference semantics, but this one has no mutable
fields; assignments and retained output values are safe. A mutable-state copy
operation is unnecessary. Parsing and construction retain no input views.

Binary conversion always uses network order. GUID braces do not change its
binary order; Windows GUID's mixed-endian field representation is a separate
conversion and is not applied here. Views bound every read even when backing
storage contains additional data.

## Algorithms and portability

| Request / backend | Behavior |
| --- | --- |
| `Scalar` / every backend | Scalar hexadecimal lookups and unsigned word accumulation. |
| `Simd` / native | V128 classification, narrowing/widening, and stores; fixed-width field packing avoids optional byte-shuffle instructions. |
| `Simd` / linear-memory Wasm | V128 classification, constant byte shuffles, nibble merging, and bounded stores. |
| `Simd` / Wasm GC and JavaScript | Scalar fallback; `simd_available()` returns false. |
| `Auto` / native | Scalar, following whole-operation local byte-parsing and buffer-write measurements. |
| `Auto` / linear-memory Wasm | SIMD. |
| `Auto` / Wasm GC and JavaScript | Scalar. |

Vector parsers validate all 32 hexadecimal digits. UTF-16 loads cover eight
code units and add the view's `start_offset()` in code units. Saturating
narrowing rejects high Unicode values whose low byte resembles ASCII hex.
Native hyphen removal/insertion uses fixed 64-bit fields around the vector
kernels; Wasm uses constant shuffles. Byte parsing reads two checked 16-byte
vectors and a final four-byte tail for hyphenated bodies. Loads do not require
alignment and stay inside the view.

Portable core intrinsics avoid FFI and optional AVX/SSSE3 assumptions. On the
validated native toolchain, generic byte swizzles require SSSE3 for the direct
x86 implementation; its scalar fallback was expensive. Fixed-width native
packing avoids that cost while retaining vector hexadecimal operations.
Revalidate dispatch and intrinsic costs after toolchain changes.

Windows, Linux, and macOS support `native`, `wasm`, `wasm-gc`, and `js`. Native
builds require a platform C compiler; JavaScript requires Node.js. Development
used `moon 0.1.20261120` and `moonc v0.10.22+7b085e9a4-nightly` (2026-11-22).
CI uses nightly and Node.js 24 and records its actual versions. Experimental
SIMD imports are acknowledged in `moon.pkg`.

## Correctness and performance

Tests retain all upstream fixtures, check 1024 deterministic UUIDs against an
independent arithmetic oracle, classify every byte at every compact digit
position, and cover malformed wrappers/hyphens, high and unpaired UTF-16 code
units, output case, nil/max, ordering, immutable ownership, and input/output
offsets 0 through 31. Guard bytes detect overreads and overwrites; invalid
output offsets include signed integer extremes.

On the recorded toolchain, native coverage includes zero-hit rows for some
Wasm-only and fallback declarations excluded from native compilation. The
correctness suite exercises those declarations on their supported backends;
the native line rate includes this reporting limitation.

```text
moon -C uuid check --target all --deny-warn
moon -C uuid test --target all
moon -C uuid info
moon -C uuid fmt
moon -C benchmarks test --target all
moon run scripts/benchmark.mbtx uuid
```

[BENCHMARK.md](BENCHMARK.md) compares scalar and SIMD requests with pinned
`bobzhang/uuidm`, its `f4ah6o/uuidm` fork, `moonbitstack/moonuuid`, and
`wulisususu/moonuuid`. The harness validates binary results before timing 193
exact cases per backend. Required input conversion and result adaptation stay
inside the timer. Unsupported public operations are omitted explicitly.

In the selected CI snapshot, linear-memory Wasm SIMD parsing outperforms our
scalar path on all three systems. Native x86 hyphenated parsing favors scalar;
the ARM64 macOS runner favors an explicit SIMD request. JavaScript parsing and
formatting trail the fastest competing packages in this snapshot. Whole public
operations include representation, allocation, and conversion costs; compare
our scalar and SIMD requests to assess this port's vector benefit.

One complete CI snapshot covers all twelve OS/backend environments at one
source revision, run, and attempt. Its JSON preserves every unrounded statistic
and length/offset label. Local measurements remain explicitly local. Ten
samples are batches of calls; CV >= 5% is marked as possible noise.

## References and license

- [uuid-simd source](https://github.com/Nugine/simd/tree/d74c030d9dc4f3cae02146d1f497ff62726ef09a/crates/uuid-simd)
- [RFC 9562](https://www.rfc-editor.org/rfc/rfc9562)
- [MoonBit SIMD API](https://mooncakes.io/docs/moonbitlang/core/simd)
- [Comparison harness](../benchmarks/README.md)
- [Collector](../scripts/benchmark.mbtx) and [report validator](../scripts/benchmark_report.mbtx)

MIT with Nugine's attribution preserved; comparison dependencies retain their
own ISC or Apache-2.0 licenses.
