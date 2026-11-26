# Byte and UTF-8 code point counts

`justjavac/bytecount` ports [bytecount 0.6.9](https://github.com/llogiq/bytecount/tree/f06647f90a45ab302d9423dbe85019d595abf8c2)
to pure MoonBit. It has no dependencies beyond bundled core and supports
`native`, `wasm`, `wasm-gc`, and `js`.

## Installation

The repository workspace already includes this module. For a separate project
using the registry release, add it with `moon add justjavac/bytecount` and add
`"justjavac/bytecount"` to the consuming package's `moon.pkg` imports.

## API

| Function | Input | Result |
| --- | --- | --- |
| `count` | `BytesView`, `Byte` | Occurrences of the requested byte |
| `num_chars` | `BytesView` | Bytes outside the continuation range `0x80..0xBF` |
| `naive_count`, `naive_count_32` | `BytesView`, `Byte` | Same byte count using a per-byte loop |
| `naive_num_chars` | `BytesView` | Same non-continuation count using a per-byte loop |

All operations return `Int32` since a count fits within the view length.
`naive_count_32` uses the same loop as `naive_count`. Calls borrow immutable
input, accept unaligned subviews, and return zero for an empty view.

```mbt nocheck
let spaces = @bytecount.count(b"one two three", b' ')
let code_points = @bytecount.num_chars(b"A\xC3\xA9\xF0\x9F\x98\x80")
assert_eq(spaces, 2)
assert_eq(code_points, 3)
```

For valid UTF-8, `num_chars` counts Unicode code points, including a BOM.
A combining mark contributes one code point. The function applies the same
byte rule to malformed or truncated views without validating, replacing, or
decoding anything. For example, a lone `0x80` contributes zero and a lone
`0xFF` contributes one. Views use byte offsets.

## Dispatch

On native and linear-memory Wasm, inputs below 128 bytes use eight-byte SWAR
groups and a byte tail. Starting at 128 bytes, both operations count complete
`V128` blocks, followed by a byte tail. Native accumulates pairs of vectors
and widens the counters after at most 255 pairs. Wasm uses population counts
for up to 256 complete-vector bytes and switches to the batched sum above that.
Wasm GC uses eight-byte SWAR groups. JavaScript uses four-byte SWAR groups for
`count` starting at 128 bytes, with a byte loop for shorter inputs and
`num_chars`.

## Verification

Run `moon test bytecount --target all` from the repository root. Tests cover
all byte values and needles, unaligned views, scalar and vector tails,
malformed UTF-8, and dense inputs across the vector accumulation boundaries.
See [BENCHMARK.md](BENCHMARK.md) for the measured workloads.

The port uses the upstream MIT license and preserves its copyright in
[LICENSE](LICENSE).
