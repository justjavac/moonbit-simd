# memchr for MoonBit

`justjavac/memchr` ports the byte-search and substring-search contracts of
[memchr 2.8.3](https://crates.io/crates/memchr/2.8.3) to pure MoonBit, with portable
SWAR, SIMD, and Two-Way implementations. It has no production dependencies beyond
MoonBit core and supports `native`, `wasm`, `wasm-gc`, and `js`.

The source is pinned to revision
[`5fdb40c054e1fff359a2f7bdf7f87a13b34b465d`](https://github.com/BurntSushi/memchr/tree/5fdb40c054e1fff359a2f7bdf7f87a13b34b465d).
The published crate's SHA-256 is
`cf8baf1c55e62ffcace7a9f06f4bd9cd3f0c4beb022d3b367256b91b87513d98`.
Upstream code, its byte-frequency table, and translated regression fixtures use
the MIT license option; see [LICENSE](LICENSE).

This initial `0.1.0` module is available in the workspace. Registry publication
is separate; installation and the full API are documented below.

## Installation and imports

For a source checkout, add this library alongside your application's module in
the application's `moon.work`:

```text
members = [ ".", "../moonbit-simd/memchr" ]
```

Declare `"justjavac/memchr@0.1.0"` in the application's `moon.mod` import block.
After a registry release, the equivalent dependency can be installed with
`moon add justjavac/memchr@0.1.0`. Import the packages you use in `moon.pkg`:

```text
import {
  "justjavac/memchr",
  "justjavac/memchr/memmem",
}
```

Both public packages belong to this independently buildable module. The
development-only comparison workspace is separate and is not a dependency.

## Byte search

| Operation | Result |
| --- | --- |
| `memchr(needle, haystack)` / `memrchr(needle, haystack)` | First / last occurrence of one byte. |
| `memchr2(a, b, haystack)` / `memrchr2(a, b, haystack)` | First / last occurrence of either byte. |
| `memchr3(a, b, c, haystack)` / `memrchr3(a, b, c, haystack)` | First / last occurrence of any of three bytes. |
| Each operation's `_iter` counterpart | A lazy `Matches` cursor over all matching byte positions. |

Searches return `Int32?`: `None` for absent matches, including empty haystacks.
Needles are `Byte`, input is `BytesView`, and ordinary `Bytes` implicitly converts
to a view. Duplicate needle values and their ordering do not change results.
Input is never decoded, copied, or mutated by searches. Results count bytes
relative to the supplied view, independently of its backing-buffer offset.

```mbt nocheck
assert_eq(@memchr.memchr(b'o', b"foo bar foo"), Some(1))
assert_eq(@memchr.memrchr(b'o', b"foo bar foo"), Some(10))
assert_eq(@memchr.memchr2(b' ', b'!', b"foo bar"), Some(3))
assert_eq(@memchr.memchr3(b'x', b'y', b'z', b"!xyz!"[2:4]), Some(0))
```

Every operation accepts `simd=false` to select scalar search explicitly. The
default is `simd=true`; actual vector execution depends on backend and length,
as described under portability.

## Byte cursors and ownership

`Matches` unifies Rust's `Memchr`, `Memchr2`, `Memchr3`, and their reversed
iterators. `next()` consumes from the construction direction; `next_back()`
consumes from the other end. Mixed calls never repeat a position. `iter()`
provides a consuming MoonBit `Iter[Int32]`, while `count()` consumes all remaining
matches using exact word/vector masks instead of constructing an array.

MoonBit structs have reference semantics: assigning a cursor shares its mutable
progress. `copy()` creates independent progress while safely retaining the same
immutable input view. `iter()` shares progress with that cursor. Exhaustion is
permanent. Retained views remain valid after the caller's local bindings end;
they can keep a larger backing buffer alive. Materialize a partial view with
`to_owned()` before constructing a cursor if only those bytes should be retained.

```mbt nocheck
let cursor = @memchr.memchr_iter(b'o', b"foo bar foo")
assert_eq(cursor.next(), Some(1))
let copy = cursor.copy()
assert_eq(cursor.next_back(), Some(10))
assert_eq(cursor.count(), 2)
assert_eq(copy.iter().to_array(), [2, 9, 10])
```

## Substring search

The `justjavac/memchr/memmem` package accepts arbitrary byte haystacks and needles.
Its indices also count bytes, including positions inside multibyte UTF-8.

| API | Contract |
| --- | --- |
| `find(haystack, needle)` / `rfind(haystack, needle)` | First / last substring offset, with one-off preprocessing included. |
| `Finder::new(needle).find(haystack)` | Reusable immutable forward finder. |
| `FinderRev::new(needle).rfind(haystack)` | Reusable immutable reverse finder. |
| `find_iter` / `rfind_iter` and the corresponding finder methods | Lazy non-overlapping matches, selected from the left / right. |
| `Finder::needle()` / `FinderRev::needle()` | The original immutable needle view. |
| `FindIter` / `FindRevIter`: `next()`, `iter()`, `copy()` | Consuming cursors with shared assignment and independent copies. |

Absent matches and needles longer than the haystack return `None`. An empty
needle matches every byte boundary: `find` returns zero and `rfind` returns the
haystack length. Iteration includes both endpoints, including the sole zero
boundary of an empty haystack. Forward and reverse iteration each discard
overlapping occurrences in their own direction; their match sets can differ.

```mbt nocheck
let finder = @memmem.Finder::new(b"aba")
assert_eq(finder.find(b"ababa"), Some(0))
assert_eq(finder.find_iter(b"ababa").iter().to_array(), [0])
assert_eq(@memmem.rfind_iter(b"ababa", b"aba").iter().to_array(), [2])
assert_eq(@memmem.find_iter(b"\xC3\xA9", b"").iter().to_array(), [0, 1, 2])
```

Finders retain their immutable needle view and contain no mutable search state;
assignments and concurrent independent searches safely share preprocessing.
Creating a match cursor does not consume or mutate its finder. Substring cursor
assignments share progress, while `copy()` isolates consumption and retains
immutable needle/haystack storage. Searches and iteration never mutate input.
Use `needle.to_owned()` before construction when retaining a partial backing
buffer would be undesirable.

Forward constructors and one-off APIs accept `prefilter=@memmem.None` to disable
candidate filtering, or `prefilter=@memmem.Auto` (the default). They also accept
`simd=false`. Reverse APIs accept `simd` and use the reverse Two-Way algorithm for
needles longer than one byte. No API raises a recoverable error: every byte
sequence and every valid byte view is a valid search input.

## Algorithms and upstream adaptation

Byte search uses complete eight-byte little-endian SWAR words, or sixteen-byte
V128 equality masks. Unused vector lanes are never loaded. Exact zero-byte masks
avoid subtraction-borrow false positives, which is necessary for reverse offsets
and counting; duplicate needle masks are combined before population counting.
All short remainders are handled without reading outside the view.

Vector loops retain the immutable backing buffer and use explicit view-relative
length guards before core's byte-aligned V128 extraction. This avoids rebuilding
tail views and repeated reference bookkeeping inside vector scans. The core
operation accepts arbitrary byte offsets; it does not require sixteen-byte
memory alignment. Both byte scans and pair filters bound loads by the actual
view, including offset views with additional backing bytes.

Substring search ports upstream's Crochemore-Perrin Two-Way factorization,
periodic/nonperiodic shifts, backward periodic memory, and approximate 64-bit
needle-byte set. Preprocessing takes O(m), and auxiliary state takes O(1), where
m is the needle length. Reusable search takes O(n + m) for n haystack bytes;
single-byte needles delegate to byte search, and empty needles have an explicit
boundary path. No reversed needle/haystack buffers are allocated.

Forward candidate filtering uses upstream's complete 256-entry background
frequency table and pair selection over needle positions below 255. Complete
sixteen-position candidates can be filtered with two bounded vector comparisons;
other cases use scalar byte search plus a second-byte predicate. Candidates always
undergo exact Two-Way verification. This port limits filtering to fifty calls per
search and retains periodic memory between compatible shifts, so even adversarial
pair collisions preserve linear search. Upstream instead uses an average-skip
effectiveness heuristic; the fixed bound is an intentional portable adaptation.

The port provides the stable byte/substring behaviors through idiomatic MoonBit
APIs. Rust lifetime/`Cow` conversions and `into_owned`/`as_ref` are replaced by
safe immutable views and ordinary `to_owned()`. Builder configuration is exposed
as labeled constructor arguments and `Prefilter`; custom frequency-ranker
traits, logging, Rust feature flags, architecture-specific AVX2/NEON dispatch,
and separate Rabin-Karp/Shift-Or strategies are omitted. Production code consists
only of MoonBit and standard core SIMD intrinsics, without FFI or native stubs.

## Portability and limits

| Backend | `simd=true` |
| --- | --- |
| `native` | V128 byte search/counting for inputs of at least 16 bytes; vector pair filtering when at least 16 complete candidate starts remain. |
| `wasm` | The same portable sixteen-byte vector paths. |
| `wasm-gc` | Scalar SWAR and Two-Way fallback. |
| `js` | Per-byte scalar search/counting and Two-Way, avoiding BigInt word operations. |

`simd=false` always selects the scalar paths. An early match can finish after a
single vector/word, and short input uses scalar code even with a SIMD request.
Reverse multi-byte substring searches use Two-Way on every backend. Vectors use
the toolchain's standard lowering; no optional CPU instruction is assumed.
Compare whole-operation scalar/SIMD measurements before drawing speed conclusions.

JavaScript uses ordinary per-byte comparisons rather than `UInt64` SWAR, because
the installed backend represents word arithmetic using BigInt. Local public-API
measurements showed that cost exceeded the independent byte scan; the per-byte
fallback preserves the same view bounds, duplicate handling, and cursor semantics.

The workspace targets Windows, Linux, and macOS. Native needs a platform C
compiler for MoonBit-generated artifacts; JavaScript tests need Node.js. The
validated nightly is `moon 0.1.20261120`, `moonc v0.10.22+7b085e9a4-nightly`
(2026-11-22). Experimental `moonbitlang/core/simd` imports are acknowledged in
both package manifests. Byte lengths and returned indices use MoonBit's `Int32`
indexing domain rather than Rust's platform-dependent `usize`. Offset views
require no alignment and all loads are explicitly little-endian.

## Tests and reproduction

[Checked byte examples](README.mbt.md) and [checked substring examples](memmem/README.mbt.md)
run with the correctness suite. The suite retains all **27 upstream byte seeds**
and **37 upstream substring seeds**, including duplicate fixture rows, and expands
them across prefix/suffix padding of 0–34 bytes. Upstream expected results remain
unchanged. Independent byte/substring oracles cover every short tail and offset,
all 256 byte values, duplicate needles, arbitrary binary data, non-overlap,
empty byte boundaries, shared/copied cursors, periodic and long patterns,
approximate-set collisions, and adversarial filter shutdown. Binary haystacks up
to eight bytes and needles up to five bytes are exhaustively cross-checked.
Private tests independently verify suffix/period extraction, exact SWAR masks,
ranked-pair bounds, and candidate-vector tails.

Run from the repository root:

```text
moon check memchr memchr/memmem --target all --deny-warn
moon test memchr memchr/memmem --target all
moon -C memchr info
moon -C memchr fmt
moon test memchr memchr/memmem --target native --enable-coverage
moon run scripts/coverage_report.mbtx local memchr
moon -C benchmarks test memchr --target all
moon run scripts/benchmark.mbtx memchr
moon run scripts/benchmark_report.mbtx --self-test
```

The coverage exporter writes separate filtered reports for `justjavac/memchr`
and `justjavac/memchr/memmem`, immediately after native collection. Shared CI
uploads both with each operating system's Codecov flag. See
[BENCHMARK.md](BENCHMARK.md) for the complete case inventory, adaptation costs,
and snapshot publication policy.

The local Windows native collection on 2026-11-25 reports **120/135 lines (88.89%)**
for byte search and **145/146 (99.32%)** for memmem: **265/281 (94.31%)** combined.
The validated coverage exporter retains JavaScript-only declarations and the
scalar-only vector fallback declarations as uncovered native counters. Those
paths are exercised by the JavaScript/Wasm GC correctness suites; native coverage
is not a measurement of their backend coverage. Sources are not skipped to alter
the reported rate. Existing shared-workspace runtime logs are preserved; the
exporter accepts `--runtime-log <file>` to select only fresh native collection.

To regenerate fixtures, download
[`memchr-2.8.3.crate`](https://static.crates.io/crates/memchr/memchr-2.8.3.crate),
verify its SHA-256 above, and extract it under the ignored `_build/upstream/`:

```text
moon run scripts/memchr_fixtures.mbtx _build/upstream/memchr-2.8.3
moon -C memchr fmt
moon fmt scripts/memchr_fixtures.mbtx
moon test memchr memchr/memmem --target all
```

The generator checks the pinned VCS revision and exact fixture/table counts. It
preserves both seed inventories and translates the three ASCII Rust Unicode
escapes into equivalent byte literals. Script mode's experimental async imports
produce toolchain notices; package `options(...)` is not valid script frontmatter.
The library packages acknowledge their experimental imports normally.

## References

- [Pinned upstream source and MIT license](https://github.com/BurntSushi/memchr/tree/5fdb40c054e1fff359a2f7bdf7f87a13b34b465d).
- [Upstream byte-search API](https://docs.rs/memchr/2.8.3/memchr/) and [memmem API](https://docs.rs/memchr/2.8.3/memchr/memmem/).
- [Pinned Two-Way implementation](https://github.com/BurntSushi/memchr/blob/5fdb40c054e1fff359a2f7bdf7f87a13b34b465d/src/arch/all/twoway.rs).
- [Generic SIMD substring filtering](http://0x80.pl/articles/simd-strfind.html#first-and-last).
- [Current MoonBit SIMD API](https://mooncakes.io/docs/moonbitlang/core/simd).
