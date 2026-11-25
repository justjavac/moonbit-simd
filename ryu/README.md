# Ryu for MoonBit

`justjavac/ryu` is a pure MoonBit port of [Ulf Adams's Ryu](https://github.com/ulfjack/ryu),
pinned to revision [`4c0618b0e44f7ef027ebae05d2cc7812048f7c8f`](https://github.com/ulfjack/ryu/tree/4c0618b0e44f7ef027ebae05d2cc7812048f7c8f).
It implements shortest IEEE 754 binary32/binary64 formatting, Ryu Printf's
binary64 fixed/scientific formatting, and the upstream experimental decimal
parsers. Formatting and parsing use integer arithmetic and verified lookup
tables. Production code has no third-party dependencies, FFI, native stubs,
maintained C sources, or calls to a platform floating-point formatter/parser.

## Installation

The module is prepared as version `0.1.0`; registry publication is a separate
step. Once published:

```text
moon add justjavac/ryu@0.1.0
```

Import the root package in the consuming package's `moon.pkg`:

```text
import {
  "justjavac/ryu",
}
```

For local development, link `ryu/` explicitly in `moon.work` and declare
`justjavac/ryu@0.1.0` in the consuming module's `moon.mod`. Each library is an
independent module; the repository root is a development workspace.

## Public API

| MoonBit operation | Upstream C operation | Result |
| --- | --- | --- |
| `d2s(Double)` | `d2s`, `d2s_buffered_n` | Shortest binary64 decimal `String` |
| `f2s(Float)` | `f2s`, `f2s_buffered_n` | Shortest binary32 decimal `String` |
| `d2fixed(Double, precision~)` | `d2fixed`, `d2fixed_buffered_n` | Exact-width fixed `String`, raises `FormatError` |
| `d2exp(Double, precision~)` | `d2exp`, `d2exp_buffered_n` | Exact-width scientific `String`, raises `FormatError` |
| `s2d(StringView)` | `s2d_n` | Binary64 `Double`, raises `ParseError` |
| `s2f(StringView)` | `s2f_n` | Binary32 `Float`, raises `ParseError` |

Returned strings are immutable, independently usable values. Input numbers and
views are unchanged. There is no public mutable state, global formatting mode,
locale, or consuming operation. Calls share read-only private tables. C buffer
ownership and NUL termination are replaced with managed MoonBit strings; parse
views are consumed in full, including any embedded NUL. Offsets and lengths are
UTF-16 code units, and accepted parser characters are ASCII.

### Shortest formatting

`d2s` and `f2s` find the shortest significant decimal digits whose correctly
rounded parse recovers the original IEEE value. Rounding is to nearest with
ties to even. The C output layout always uses one digit before an optional
decimal point, uppercase `E`, and an unpadded exponent without a positive sign.
It is not a fixed-vs-scientific layout heuristic.

| Input | `d2s` result |
| --- | --- |
| `0.3` | `3E-1` |
| `1000.0` | `1E3` |
| Positive/negative zero | `0E0` / `-0E0` |
| Positive/negative infinity | `Infinity` / `-Infinity` |
| Any NaN sign or payload | `NaN` |

The source precision matters. `f2s(Float::from_double(0.3))` returns `3E-1`;
formatting that Float after widening to Double returns
`3.0000001192092896E-1`. Use `f2s` for binary32 shortest output.

### Ryu Printf

`precision` counts digits **after** the decimal point in both operations.
`d2fixed` prints the complete integer part; `d2exp` prints one integer digit,
lowercase `e`, an explicit exponent sign, and at least two exponent digits.
Precision zero omits the decimal point. Both round the exact binary value to
nearest with ties to even, rather than rounding its shortest string. A carry
can grow the integer part or increase the scientific exponent.

```mbt
assert_eq(@ryu.d2fixed(2.5, precision=0), "2")
assert_eq(@ryu.d2fixed(3.5, precision=0), "4")
assert_eq(@ryu.d2fixed(0.1, precision=20), "0.10000000000000000555")
assert_eq(@ryu.d2exp(9.99, precision=1), "1.0e+01")
assert_eq(@ryu.d2exp(-0.0, precision=2), "-0.00e+00")
```

Precision must be in `0..2147483336`, reserving portable `Int` length space for
the largest integer part and punctuation. Invalid precision raises
`FormatError::InvalidPrecision(requested)` before allocation, even for NaN or
infinity. Actual allocation remains limited by available memory, with storage
proportional to the output length. Finite values support precision beyond the
upstream convenience functions' fixed 2000-byte allocation: tests exercise
10000 digits and zero padding after the exact binary expansion.

Infinities are `Infinity`/`-Infinity`; Printf NaNs are always `nan`. This chooses
the upstream non-MSVC spelling uniformly, rather than its Windows-specific
negative/signaling-NaN spellings. Signed zero and the sign of a negative value
rounded to zero are preserved. Binary32 Float values may be widened exactly
to Double before Printf formatting.

### Experimental parsing

The parsers preserve upstream `ryu_parse.h` semantics and limitations; they are
not a general JSON or language-number validator. They operate directly at the
requested binary precision with nearest, ties-to-even rounding. `s2f` does not
parse through Double, avoiding a double-rounding step.

| Property | `s2d` | `s2f` |
| --- | --- | --- |
| Significant mantissa digit budget | 17 | 9 |
| Significant exponent digit budget | 4 | 4 |
| Initial mantissa sign | Optional `-` | Optional `-` |
| Decimal point | At most one `.` | At most one `.` |
| Exponent marker and sign | `e`/`E`, optional `+`/`-` | Same |
| Underflow / overflow | Signed zero / signed infinity | Same |

Initial zeroes do not consume either budget. Once a nonzero digit has appeared,
every following digit counts, including zeroes. An all-zero input can be long.
The full-width exponent adjustment avoids overflow when a view has many
fractional zeroes. Initial `+`, spaces, underscores, hexadecimal syntax,
non-ASCII digits, NUL, and `NaN`/`Infinity` spellings are rejected.

Upstream does not require mantissa or exponent digits: `-` produces negative
zero; `.`, `e`, and `.e2` produce zero; `1e+` and `1.` produce one. These forms
are deliberately retained and tested. Validate a stricter grammar separately
when required by the calling application.

| `ParseError` | Meaning |
| --- | --- |
| `InputTooShort` | The entire input view is empty |
| `InputTooLong` | A significant mantissa or exponent budget was exceeded |
| `MalformedInput` | A repeated point or rejected character/sign was encountered |

Failures follow upstream scan order. No partial successful parse or input
mutation is exposed. Existing views and returned strings remain valid after
later calls.

## Algorithm and portability

The shortest port retains the binary rounding intervals, boundary inclusion,
decimal digit removal, trailing-zero detection, ties-to-even rounding, and
binary64 small-integer fast path. Binary32 uses its own interval computation
with the upper limbs of the shared binary64 tables, as upstream's default C
configuration does. Printf retains its nine-digit block tables and exact
rounding tests. Scientific formatting skips table-exhausted zero blocks and
pads the remaining output directly.

Full 64-by-64 multiplication is implemented using four bounded 32-bit limb
products. Wider products, carries, shifts, and modulo-billion extraction remain
fixed-width integer operations. Tables are flat private arrays, avoiding a
separate allocation for each tuple. The 668 shortest and 4357 Printf multiplier
entries are checked against exact BigInt formulas by
[ryu_tables.mbtx](../scripts/ryu_tables.mbtx), including every offset and minimum
block. BigInt is used only in generation and independent tests.

`native`, `wasm`, `wasm-gc`, and `js` use the same portable scalar algorithm.
This module does not request or claim SIMD execution: one value's Ryu interval
and rounding transitions are dependent integer work. It has no CPU feature,
alignment, endianness, or architecture-specific shortcut. CI configures Windows,
Linux, and macOS; [CI run 45541274765](https://github.com/justjavac/moonbit-simd/actions/runs/45541274765)
passed all four backends on all three systems at source
`a627d01c05f431e39fe4acb15ef956dd694d2d4e`. Native
builds require a standard C compiler for MoonBit's generated backend/runtime;
JavaScript tests require Node.js.

Validated toolchain: `moon 0.1.20261120`,
`moonc v0.10.22+7b085e9a4-nightly` (2026-11-22). Core APIs and benchmark adapter
behavior should be revalidated after toolchain changes.

Intentional scope: the optimized C binary32/binary64 converters and their
experimental parsers. The experimental generic binary16/80/128 representation,
Java's minimum-two-digit layout and configurable rounding modes, printf width
and flags, `%g`, debug output, and C allocation/buffer APIs are not exposed.

## Tests and regeneration

The correctness suite includes public checked examples, special values,
source-precision differences, every binary32/binary64 exponent boundary with
both signs and endpoint mantissas, deterministic bit round trips through the
independent core parser, actual offset views, invalid syntax and precision,
decimal carries, and high precision.

The pinned upstream fixtures retain **5867** exact expected records: 132
binary64 shortest cases, 60 binary32 shortest cases, 31 binary64 parse cases,
20 binary32 parse cases, and 2812 cases each for fixed/scientific formatting.
The latter include all upstream power-of-ten and binary-exponent tables.
The C oracle also generates **17280** deterministic differential records:
4000 each for shortest binary64, shortest binary32, parsed binary64, and parsed
binary32, plus 640 each for fixed/scientific formatting. Records store exact
input bits to avoid cross-compiler decimal-literal differences.

Independent exact rational tests cover 1120 structured values/precision combinations
for each Printf mode plus 100 sampled bit patterns, using BigInt scaling, division, and ties-to-even rounding
without Ryu tables. Full-width multiplication is checked against BigInt.
Core parsing is independent of the port's tables and decimal-removal logic;
external Ryu expectations also share upstream's algorithm lineage, so both
forms of reference are retained.

Native line coverage from that CI run is **99.13% (343/346 executable lines)**
on each of Windows, Linux, and macOS. The three
unhit locations are defensive zero-shift bodies in the word-window helper and
the two decimal-to-binary converters; the validated Ryu factors retain at least
one rounding bit. Table literals have no executable-line counters. No executable
code is skipped, and every backend passes its own correctness suite.

```text
moon check ryu --target all --deny-warn
moon test ryu --target all
moon info
moon fmt
moon test ryu --target native --enable-coverage
moon run scripts/coverage_report.mbtx local ryu
```

From a checkout of the exact pinned upstream revision, regenerate and format:

```text
moon run scripts/ryu_tables.mbtx _build/ryu-upstream
moon run scripts/ryu_oracle.mbtx _build/ryu-upstream
moon fmt ryu
moon fmt scripts/ryu_tables.mbtx scripts/ryu_oracle.mbtx
```

The oracle generates and compiles C/C++ only under ignored `_build/ryu-oracle/`
and retains full build/output logs. It is an external correctness reference,
never an implementation dependency or cross-language timing competitor. Normal
tests use the committed data and do not need an upstream checkout.

See [README.mbt.md](README.mbt.md) for short checked examples,
[pkg.generated.mbti](pkg.generated.mbti) for the generated interface, and
[BENCHMARK.md](BENCHMARK.md) for the public-operation measurements and source
context.

## License and references

MoonBit contributions are MIT. Translated algorithms, tables, and imported
tests retain Ulf Adams and contributors' copyright and the upstream Boost
Software License 1.0 option. [LICENSE](LICENSE) contains both complete notices.
The upstream alternative Apache-2.0 license and unrelated third-party code are
not used for this port.

- [Ryu: fast float-to-string conversion, PLDI 2018](https://doi.org/10.1145/3192366.3192369).
- [Ryu revisited: printf floating point conversion, OOPSLA 2019](https://doi.org/10.1145/3360595).
- [Pinned upstream C APIs](https://github.com/ulfjack/ryu/blob/4c0618b0e44f7ef027ebae05d2cc7812048f7c8f/ryu/ryu.h).
- [Pinned experimental parsing API](https://github.com/ulfjack/ryu/blob/4c0618b0e44f7ef027ebae05d2cc7812048f7c8f/ryu/ryu_parse.h).
- [Comparison adapters and reproduction](../benchmarks/README.md).
