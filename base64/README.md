# justjavac/base64

Portable RFC 4648 Base64 encoding, strict decoding, and WHATWG forgiving
decoding for MoonBit. This MIT-licensed library ports the algorithms and
contracts of [base64-simd 0.8.0](https://crates.io/crates/base64-simd/0.8.0).
It builds independently on Windows, Linux, and macOS across `native`,
`wasm`, `wasm-gc`, and `js`.

See [checked examples](README.mbt.md), the generated
[public interface](pkg.generated.mbti), and [performance comparisons](BENCHMARK.md).

## Installation and imports

Version 0.1.0 is the initial source version. After its Mooncakes release:

```text
moon add justjavac/base64@0.1.0
```

Import the root package in your `moon.pkg`:

```text
import {
  "justjavac/base64",
}
```

For an unpublished checkout, include this directory in your consumer's
`moon.work` and declare `justjavac/base64@0.1.0` in its `moon.mod`.
The library depends only on bundled MoonBit core packages. Comparison
dependencies live exclusively in the development-only `benchmarks/` module.

## Quick start

```mbt
let encoded = @base64.standard.encode_to_string(b"hello world")
assert_eq(encoded, "aGVsbG8gd29ybGQ=")
assert_eq(@base64.standard.decode_string(encoded), b"hello world")

let token = @base64.url_safe_no_pad.encode_to_string(b"\xfb\xff")
assert_eq(token, "-_8")
assert_eq(@base64.url_safe_no_pad.decode_string(token), b"\xfb\xff")
assert_eq(@base64.forgiving_decode_string(" Z h = = \n"), b"f")
```

The statements that decode can raise `Base64Error`; examples belong in a
test or a function declared with `raise`. The short examples in
[README.mbt.md](README.mbt.md) are compiled and tested.

## Configuration and strictness

`Base64` is immutable. Use the four shared values or construct the same
policies with `Base64::new(url_safe=false, padding=true)`:

| Value | Last two alphabet characters | Encoding | Strict decoding |
| --- | --- | --- | --- |
| `standard` | `+/` | Required `=` padding | Exact padding required |
| `standard_no_pad` | `+/` | No padding | Every `=` rejected |
| `url_safe` | `-_` | Required `=` padding | Exact padding required |
| `url_safe_no_pad` | `-_` | No padding | Every `=` rejected |

Strict decoding rejects whitespace, characters from the other alphabet,
non-ASCII input, misplaced/excess padding, lengths congruent to 1 modulo 4,
and nonzero unused tail bits. Empty input is valid. Thus `Zg==` is valid
standard padded Base64, `Zg` belongs to its no-pad policy, and `Zh==`
is noncanonical and rejected by strict decoding.

The `forgiving_decode*` functions use only the standard alphabet and
implement [WHATWG Infra forgiving-base64](https://infra.spec.whatwg.org/#forgiving-base64-decode):
remove TAB, LF, FF, CR, and SPACE; accept properly placed optional padding;
ignore unused tail bits. Vertical tab, non-ASCII whitespace, URL-safe digits,
and malformed padding remain invalid. `Zh` and `Zh==` therefore decode to
`b"f"` only under forgiving decoding.

## Public API

All processing methods take `simd? : Bool`. The measured default requests
V128 on Wasm and uses scalar processing on native, Wasm GC, and JS. An explicit
`simd=false` forces scalar code; `simd=true` requests V128 where supported
and falls back to scalar elsewhere.

| Operation | Result and purpose |
| --- | --- |
| `Base64::new(url_safe?, padding?)` | Immutable alphabet/padding policy |
| `charset()` | Immutable 64-byte alphabet view |
| `encoded_length(Int)` | Exact output size including configured padding |
| `estimated_decoded_length(Int)` | Allocation upper bound; no input validation |
| `decoded_length(BytesView)` | Exact size after partial structural validation |
| `check(BytesView, simd?)` | Full strict validation without output allocation |
| `encode(BytesView, simd?)` | New ASCII `Bytes` |
| `encode_to_string(BytesView, simd?)` | New ASCII `String` |
| `decode(BytesView, simd?)` | New decoded `Bytes` |
| `decode_string(StringView, simd?)` | Direct UTF-16 input, new decoded `Bytes` |
| `encode_into(BytesView, FixedArray[Byte], offset?, simd?)` | Number of encoded bytes written |
| `decode_into(BytesView, FixedArray[Byte], offset?, simd?)` | Number of decoded bytes written |
| `decode_inplace(FixedArray[Byte], length?, simd?)` | Size of decoded prefix |
| `encode_append(BytesView, StringBuilder, simd?)` | Append encoded text |
| `decode_append(BytesView, @buffer.Buffer, simd?)` | Append validated decoded bytes |
| `forgiving_decode(BytesView, simd?)` | New bytes under WHATWG rules |
| `forgiving_decode_string(StringView, simd?)` | Direct UTF-16 input under WHATWG rules |
| `forgiving_decode_into(BytesView, FixedArray[Byte], offset?, simd?)` | Number of decoded bytes written |
| `forgiving_decode_inplace(FixedArray[Byte], length?, simd?)` | Compact whitespace and decode in place |

The generated interface and each declaration's doc comment provide complete
signatures, defaults, mutation rules, and errors.

As upstream specifies, `decoded_length` validates only structural length and
terminal padding. For example, `decoded_length(b"!!!!")` returns 3 while
`check(b"!!!!")` raises `InvalidInput`. Use `check` or a decoding operation
to establish validity.

## Buffers, ownership, and failures

`Bytes` and `String` inputs are immutable. A view is read only within its
own bounds, even when its backing value contains additional characters.
Configurations retain no input or output. Assigning a `Base64` safely shares
its immutable configuration, and allocating operations return independent values.

Caller-provided `FixedArray[Byte]` storage is mutable and has reference
semantics. Assignments share it, so aliases observe writes. Buffer functions
return a count, and `Bytes::from_array(buffer[:count])` creates an independent
snapshot. `offset` defaults to zero; `length` defaults to the full array.

```mbt
let data = b"foobar"
let storage = FixedArray::make(@base64.standard.encoded_length(data.length()), b'\x00')
let encoded_size = @base64.standard.encode_into(data, storage)
let encoded_snapshot = Bytes::from_array(storage[:encoded_size])
assert_eq(encoded_snapshot, b"Zm9vYmFy")
let decoded_size = @base64.standard.decode_inplace(storage, length=encoded_size)
assert_eq(Bytes::from_array(storage[:decoded_size]), data)
assert_eq(encoded_snapshot, b"Zm9vYmFy")
```

`Base64Error` exposes two matchable variants:

- `InvalidInput`: invalid alphabet, padding, length, unused bits, or mutable
  input-prefix length.
- `OutputTooSmall`: insufficient capacity or an output offset outside the
  destination. This is checked before output writes.

Allocating decoders expose no partial result. Structural length failures occur
before writes. A later character or tail-bit failure in `decode_into` or
`decode_inplace` can leave a partially decoded prefix; its contents are
unspecified on error. On successful strict in-place decoding, the unused suffix
is unchanged. Forgiving in-place decoding first compacts whitespace, so its suffix
is unspecified and even an invalid input can already have been changed.

Append helpers allocate an intermediate result. In particular, `decode_append`
validates completely before appending and leaves the buffer unchanged on error.
Append calls process independent complete messages; the upstream crate supplies
no stateful streaming encoder/decoder, and this port does not add one.

## Algorithm and backend behavior

The scalar path uses the RFC 4648 alphabets and reusable 256-entry decoding
tables. Quartet validation combines invalid-byte flags before writing three
decoded bytes, and remainder checks enforce canonical unused bits.

The V128 path adapts upstream's portable Wasm/NEON bit transforms and
ALSW (average, lookup, saturating add, wrapping add) decoding. Lookup offsets
are derived from the alphabets outside hot loops and independently checked for
all 256 byte values. Encoding splits twelve source bytes into sixteen sextets;
decoding merges sixteen sextets into twelve bytes.

| Backend | Explicit `simd=true` | Default on the validated toolchain |
| --- | --- | --- |
| `wasm` | Bounded V128 operations and scalar remainders | V128 request |
| `native` | V128 operations; several lower to core scalar helpers | Scalar, based on measured public operations |
| `wasm-gc`, `js` | Scalar fallback | Scalar |

An encoding vector load needs sixteen bytes inside the view and consumes twelve,
so final short input remains scalar. Decoding writes exactly twelve bytes per
sixteen-character block using an eight-byte and a four-byte store; it never relies
on upstream's overlapping overstores. String decoding loads bounded UTF-16 spans
and rejects every non-ASCII code unit, including isolated surrogates, before it
can become a valid sextet.

This is portable MoonBit code, with no Rust runtime, native FFI, CPU-feature
assumptions, or AVX2-specific kernels. V128 is not a guarantee of native hardware
acceleration. Backend defaults and dispatch costs must be remeasured after
toolchain changes; [BENCHMARK.md](BENCHMARK.md) records complete public operations
and includes explicit scalar/SIMD requests.

Validated locally with `moon 0.1.20261120` and
`moonc v0.10.22+7b085e9a4-nightly` (2026-11-22).
Native builds need a platform C compiler; JS tests need Node.js. CI uses
MoonBit nightly and Node.js 24 and records actual versions for every runner.
The macOS job uses the maintained `macos-15` ARM64 image. The current
official MoonBit installer supplies only an ARM64 macOS host toolchain;
Intel macOS host installation is unavailable.

Sizes are nonnegative `Int` values. `encoded_length` checks multiplication
before allocating and panics if output cannot fit in `Int`; negative size
arguments also panic. These arithmetic bounds do not promise that an allocator
can provide the largest representable buffer.

## Upstream scope and attribution

Pinned release: `base64-simd 0.8.0` and its `vsimd 0.8.0` algorithms,
[revision d74c030d9dc4f3cae02146d1f497ff62726ef09a](https://github.com/Nugine/simd/tree/d74c030d9dc4f3cae02146d1f497ff62726ef09a/crates/base64-simd).
The base64-simd crate archive has SHA-256
`339abbe78e73178762e23bea9dfd08e697eb3f3301cd4be981c0f78ba5859195`.
Upstream is MIT, copyright 2021 Nugine; [LICENSE](LICENSE) preserves that notice.
Its Rust output-reference dependency is declared as `outref 0.5.0`; MoonBit
uses ordinary fixed arrays and returned counts instead.

Implemented: four policies, sizing, strict checking, allocated byte/string APIs,
caller-provided output, in-place decoding, append conveniences, forgiving
decoding, scalar algorithms, and portable V128 transforms.

Rust `Out`/mutable-slice return values map to `FixedArray[Byte]` operations
and returned counts. Destination capacity failures raise a typed MoonBit error
instead of Rust's assertion. Allocated bytes use MoonBit's immutable ownership
model. The forgiving output API requires only the exact decoded capacity,
relaxing upstream's encoded-input-sized destination requirement.

Rust lifetimes, generic `FromBase64Encode/Decode` and
`AppendBase64Encode/Decode` traits, runtime instruction-set detection,
and architecture-specific 256-bit kernels are intentionally omitted. The public
API provides concrete MoonBit return/storage types and explicit backend requests.

## Tests and comparisons

Black-box tests cover RFC 4648 and retained upstream basic, allocation, canonicity,
and forgiving vectors; independent per-bit and core differential results; every
short/tail length; vector boundaries; all byte values at each lane; non-ASCII and
unpaired UTF-16 surrogates; offsets 0 through 16; sentinels outside input/output
ranges; array aliases; append failure behavior; and size overflow. White-box tests
verify generated ALSW classification and sextet values against an independent
per-byte oracle.

```text
moon check --target all --deny-warn
moon test base64 --target all
moon info
moon fmt
moon test --target native --enable-coverage
moon run scripts/coverage_report.mbtx local crc32 url base64
moon -C benchmarks check --target all --deny-warn
moon -C benchmarks test --target all
moon run scripts/benchmark.mbtx base64
moon run scripts/benchmark_report.mbtx --self-test
```

The development harness compares MoonBit core, `gmlewis/base64 0.16.15`,
`moonbitstack/moonbase 0.5.1`, and `kujirahand/base64 0.1.1`. It verifies
canonical outputs before release timing and records required input conversions.
Each backend has an exact 200-case inventory. Published snapshots require all
twelve OS/backend environments from one CI source revision, run, and attempt.

References: [RFC 4648](https://www.rfc-editor.org/rfc/rfc4648),
[WHATWG Infra](https://infra.spec.whatwg.org/#forgiving-base64-decode),
[upstream source](https://github.com/Nugine/simd/tree/d74c030d9dc4f3cae02146d1f497ff62726ef09a),
and [comparison harness](../benchmarks/README.md).
