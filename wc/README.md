# justjavac/wc

Pure MoonBit line, word, and byte counts for one-shot and incremental input.
This module ports the byte-oriented algorithm from [fastlwc] at revision
[`b8d3a383`](https://github.com/expr-fi/fastlwc/tree/b8d3a3839161d0487a25610d65a077d8431de1f0).

## Install

```text
moon add justjavac/wc@0.1.0
```

```moonbit
// moon.pkg
import {
  "justjavac/wc" @wc,
}
```

## Counting rules

- `lines` counts LF (`0x0A`). A final unterminated line contributes zero LF.
  CRLF contributes one LF, and a bare CR contributes zero.
- `words` counts maximal nonempty runs of bytes separated by ASCII space, tab,
  LF, vertical tab, form feed, or CR (`0x20` and `0x09` through `0x0D`). A final
  word is counted as soon as it starts, even if the stream ends inside it.
- `bytes` is the number of bytes supplied. Empty input returns three zeroes.

All other byte values can be part of a word, including NUL, `0x0E`, high
bytes, and invalid UTF-8. Non-ASCII whitespace such as U+00A0 is part of a
word. The port follows the upstream scalar rule for `0x0E`. The old SSE2
comparison erroneously includes that byte in the separator range. This
library exposes the main byte-counting algorithm through in-memory APIs.
Upstream provides its UTF-8 utility and parallel file reader separately.

## API

`@wc.count(data, simd=true)` counts a `BytesView` in one call and returns
read-only `Counts` with `UInt64` fields `lines`, `words`, and `bytes`.

```moonbit
let counts = @wc.count(b"alpha\tbeta\ngamma")
// counts.lines == 1UL, counts.words == 3UL, counts.bytes == 16UL
```

`@wc.Counter::new(simd=true)` creates a counter for one byte stream. Call
`update(data)` for each successive view. `counts()` returns a snapshot and
allows further updates. `reset()` clears the totals and the boundary state.
Assignment shares the counter, and `copy()` forks an independent counter with
the same totals and boundary state.

```moonbit
let counter = @wc.Counter::new()
counter.update(b"al")
counter.update(b"pha\tbeta\n")
let totals = counter.counts()
// totals.lines == 1UL, totals.words == 2UL, totals.bytes == 11UL
```

Both entry points read their views without copying. A counter retains no input,
and empty chunks leave it intact. The byte total can reach `2^64 - 1`. An
update that would exceed it panics before changing the counter. Line and word
totals are bounded by the byte total.

## SIMD and portability

The vector kernel adapts the upstream population-count path. Each 16-byte
block produces a mask for LF and one for whitespace. A shifted whitespace
mask identifies bytes preceded by a separator, using one bit from the previous
block or chunk. Intersecting with the non-whitespace lanes identifies word
starts. Two population counts give the block totals. The remaining bytes
use the scalar loop with the same incoming boundary bit.

The default uses vectors for full 16-byte blocks on native and linear-memory
Wasm. Short views and the Wasm GC and JavaScript backends use the scalar loop.
Pass `simd=false` to request scalar scanning on every backend. Loads stay
within the supplied view, including at unaligned offsets. The native backend
uses the standard MoonBit toolchain and a platform C compiler.

## Verify

Run `moon -C wc test --target all` for the public API and checked examples.
The tests compare all byte values at every SIMD position against an independent
reference and exercise tails, offsets, chunk boundaries, and counter ownership.
See the [benchmark guide](BENCHMARK.md) for the comparison and timing scope.
The adaptation is licensed under [MIT](LICENSE).

[fastlwc]: https://github.com/expr-fi/fastlwc
