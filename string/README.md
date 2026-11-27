# justjavac/string

StringZilla literal search and comparison adapted to MoonBit's `StringView`.
The module uses UTF-16 code-unit offsets and the signatures of the matching
core string methods. Inputs are immutable views and can refer to a part of a
larger string.

## Installation

```text
moon add justjavac/string@0.1.0
```

```moonbit
import {
  "justjavac/string" @string,
}
```

```moonbit
let text = "x猫😀::犬y"[1:7]
assert_eq(@string.find(text, "::"), Some(3))
assert_eq(@string.rev_find_code_unit(text, 0xDE00), Some(2))
assert_eq(@string.replace_all(text, old="::", new=" / "), "猫😀 / 犬")
```

## API compatibility

The search and text operations are package functions. Change a method call
such as `view.find(needle)` to `@string.find(view, needle)` to use the port.
MoonBit reserves public methods on built-in types for their owning package.
An owned `String` can be passed wherever core accepts a `StringView`.

| Function | Result and behavior |
| --- | --- |
| `find(text, needle)`, `rev_find(text, needle)` | First or last exact occurrence as a view-relative `Int32?`. Empty needles match at zero and the view length, respectively. |
| `find_code_unit(text, code)`, `rev_find_code_unit(text, code)` | First or last occurrence of a raw `UInt16`, including either half of a surrogate pair. |
| `contains(text, needle)` | Whether an exact occurrence exists. |
| `equal(text, other)`, `has_prefix(text, prefix)`, `has_suffix(text, suffix)` | Exact code-unit equality or a prefix/suffix check. Empty prefixes and suffixes match. |
| `split(text, separator)` | A lazy `Iter[StringView]`. A nonempty separator preserves empty fields. An empty separator yields individual Unicode scalars. |
| `split_once(text, separator)`, `rev_split_once(text, separator)` | Optional pair of borrowed views around the first or last separator. |
| `replace(text, old~, new~)`, `replace_all(text, old~, new~)` | Replacement of the first or all non-overlapping matches as a `StringView`. Empty `old` prepends in `replace` and inserts at every scalar boundary in `replace_all`. |

Search compares the original code units exactly. The split iterator keeps its
backing data alive while it is consumed. Nonempty separators produce borrowed
slices. Replacement materializes changed text and returns the original view on
a miss.

`Regex`, `MatchResult`, `FromStr`, `ToStringView`, `from_str`, and the
`parse_*` functions are re-exported from core. The regex types retain their
constructors, methods, and type identity. Other built-in string methods are
available on the same `String` and `StringView` values.

## Algorithms and backends

- Single-code-unit scans compare four groups of eight UTF-16 units and reduce
  their masks together. On a hit, bit scans select the first or last match.
- Literal substring search compares up to three needle positions. The
  StringZilla probe selection looks near the beginning, midpoint, and end to
  prefer distinct code units. Longer searches check the first probe across
  32 candidate starts, then apply the other two probes to halves with matches.
  Full equality verifies each surviving candidate. After 16 failed
  verifications, core searches the remaining view. Core's
  linear fallback bounds the worst-case search by the sum of the input and
  needle lengths.
- Linear-memory Wasm equality combines four eight-lane XOR comparisons.
  Core handles native range equality and short ranges. Every SIMD load
  stays within the original view, including views at odd code-unit offsets.

| Backend | Dispatch |
| --- | --- |
| `native` | V128 searches from 32 code units for a single unit and 16 complete starts for a substring. Substring blocks grow from 16 to 32 starts when there are at least 64 candidates. Core handles two-unit needles below 64 starts, shorter input, tails, and equality. |
| `wasm` | The same V128 search thresholds, with grouped equality starting at 32 units. The Wasm host must support SIMD. |
| `wasm-gc`, `js` | Core search and equality paths for those backends. |

The API is tested on Linux with native, Wasm, Wasm GC, and JavaScript using
`moon 0.1.20261126` and `moonc v1.0.0-rc1+546870549-nightly`. Workspace CI
also runs the four backends on Windows and macOS. The module uses MoonBit source
and bundled core. The adapted scope is literal search and equality. StringZilla's
UTF-8-specific algorithms, hashing, sorting, and distance APIs have separate
contracts from these core string operations.

## Verification and provenance

```text
moon check string --target all --deny-warn
moon test string --target all
moon -C benchmarks test string --target all
moon run scripts/benchmark.mbtx string
```

Tests compare literal searches with both core and an independent code-unit
oracle. They cover UTF-16 boundaries, unaligned views, all vector lanes and
tails, periodic false positives, and split and replacement edge cases.
See [BENCHMARK.md](BENCHMARK.md) for the core comparison.

The port adapts [StringZilla v5.3.2](https://github.com/ashvardanian/StringZilla/tree/3cd0f9bcab97912dd36ca4ca4253f1f46b33ef8e)
by Ash Vardanian. The original MoonBit contributions are under [MIT](LICENSE).
Adapted portions retain [Apache-2.0](LICENSE-APACHE) and their [notice](NOTICE).
