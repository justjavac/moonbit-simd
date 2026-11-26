# Development benchmarks

The [bytecount adapters](bytecount) compare dispatched and byte-wise counts
on the same prepared views. The byte-match workload also measures
`@memchr.memchr_iter(...).count()`, including cursor creation. See the
[bytecount report](../bytecount/BENCHMARK.md) for workloads and commands.

The [byte-search adapters](memchr) compare byte unions, both search directions,
counts, and lazy iteration against independent per-byte references. Single-byte
and substring searches also use bundled core `BytesView.find`/`rev_find` on the
same views. The 370-case inventory includes short/large input, offsets 0/1/15,
periodic patterns, reusable finders, empty needles, and directional non-overlap.
All adapters verify identical indices, counts, or index sums before timing.

Run `moon -C benchmarks test memchr --target all`, then
`moon run scripts/benchmark.mbtx memchr`, or select `memchr` in the Benchmarks
workflow. Inputs, views, needles, and reusable finders are prepared outside timing;
one-off construction and lazy consumption stay inside it. The
[search report validator](../scripts/memchr_benchmark_report.mbtx) verifies the
complete inventory, sampling statistics, and snapshot identity. Local rendering
uses `moon run scripts/benchmark_report.mbtx --local memchr _build/benchmarks/memchr/windows.json _build/memchr-report`.

The [Ryu adapters](ryu) compare shortest Float/Double formatting and decimal
parsing with bundled core public APIs. Core's conversion to the exact Ryu
scientific layout and its required Float parse narrowing stay inside timing.
The measured corpus has identical strings or independently specified IEEE bits.
Core has no equivalent fixed/scientific precision API here, so Ryu Printf is
measured separately. This port uses the same scalar integer algorithm on all
backends and makes no SIMD claim.

There are 85 Ryu cases per backend, including precision through 1074, carries,
non-normal values, signed zero, leading zeroes, invalid input, and offsets
1/3/15. Prepared values and views stay outside timing; public allocation,
adaptation, callback dispatch, and `bench.keep` are timed. Run
`moon -C benchmarks test ryu --target all`, then
`moon run scripts/benchmark.mbtx ryu`. Collection and the independent
[Ryu report validator](../scripts/ryu_benchmark_report.mbtx) check the exact
inventory and source/run/attempt/dependency identity. Explicit local rendering
uses `moon run scripts/benchmark_report.mbtx --local ryu _build/benchmarks/ryu/windows.json _build/ryu-report`.


This MIT-licensed module contains development-only CRC-32/ISO-HDLC, WHATWG URL,
UTF-8, Base64, decimal integer, extrema, UUID, and Ryu comparison adapters.
Its nested workspace
links the local libraries while keeping third-party dependencies out of the
published libraries.

Run `moon update` after installing MoonBit, then
`moon -C benchmarks test --target all` before measuring. Results are recorded
in [crc32/BENCHMARK.md](../crc32/BENCHMARK.md), with all statistics and pinned
dependency versions in the companion JSON snapshot.

URL results are recorded in [url/BENCHMARK.md](../url/BENCHMARK.md). The URL
adapters live in separate packages under `url/`, with one shared input inventory
and identical parsing/serialization checks. This keeps large Unicode tables from
different libraries out of one Wasm binary. `moonbitstack/moonurl` is measured
with `syntax=Whatwg`; its default RFC 3986 mode is not used. Required adapter
conversions, including StringView-to-String for urllib and UTF-8 form input for
moonurl, remain inside the timer. Run `moon run scripts/benchmark.mbtx url` to
measure these packages on each selected backend sequentially.

The suite compares identical bytes using each library's public API. Owned-byte
inputs and streaming chunks are prepared outside the timer; view-to-owned
conversion is included only in the separately labelled view workload. Digest
creation, byte-wise API loops, updates, and finalization are timed.

## UTF-8

The [UTF-8 adapters](utf8) compare `justjavac/utf8` basic scalar/SIMD and compat
validation against `tonyfettes/utf8@0.2.4` and the bundled core UTF-8 decoder.
Separate tests verify strict acceptance and identical UTF-16 decoded output.
Validation and decoding have separate measurements: tonyfettes' validating
constructor may materialize partial views, and core's acceptance baseline
necessarily allocates decoded strings. Those costs remain inside the timer.

The pinned tonyfettes package uses legacy JSON manifests and removed syntax, so
the benchmark workspace links a reproducible development-only
[compatibility copy](vendor/tonyfettes-utf8/UPSTREAM.md). Its algorithms, original
source hash, and Apache-2.0 license are preserved. The published UTF-8 library
has no third-party dependencies.

There are 158 UTF-8 cases per backend, covering short/large ASCII and multilingual
texts, early/late errors, incomplete input, offset-one views, and prepared owned
stream chunks. Run `moon -C benchmarks test utf8 --target all`, then
`moon run scripts/benchmark.mbtx utf8`. The collector checks every case name,
length, API variant, and offset; the report validator independently checks that
inventory and rejects incomplete or mixed CI runs. Explicit local reports use
`moon run scripts/benchmark_report.mbtx --local utf8 _build/benchmarks/utf8/windows.json _build/utf8-report`.

## Base64

The `base64/` package compares our scalar/V128 requests with bundled core,
`gmlewis/base64 0.16.15`, `moonbitstack/moonbase/base64 0.5.1`, and
`kujirahand/base64 0.1.1`. Independent bitstream expectations verify every
measured alphabet and padding policy before timing. Moonbase explicitly selects
strict decoding. Decoder permissiveness differs among competitors; canonical
corpus agreement does not imply equivalent rejection behavior.

The exact 200-case inventory covers allocating byte-to-string encoding and
string-to-byte decoding, byte/UTF-16 offset-1 views, direct byte decoding, reusable
output, in-place decoding, and validation. Case lengths label binary payload
bytes; collected metadata separately records actual encoded input bytes and
UTF-16 code units. Decoder throughput uses its actual encoded input length.

Required conversions remain timed: gmlewis needs FixedArray input for encoding
and owned String for decoding; kujirahand needs owned Bytes/String. Kujirahand
provides only a standard padded binary encoder, whose repeated string
concatenation is quadratic, so its encoding inputs stop at 4 KiB while large
decoding remains included. Tonyfettes/base64 0.1.0 has unsupported legacy module
metadata on this toolchain and is excluded.

Run `moon run scripts/benchmark.mbtx base64`. Results are recorded in
[base64/BENCHMARK.md](../base64/BENCHMARK.md), with every statistic and complete
CI provenance in its companion JSON. Workflow dispatch can select Base64 alone;
each selected module still requires the full three-OS/four-backend matrix.

## UUID

UUID results are recorded in [uuid/BENCHMARK.md](../uuid/BENCHMARK.md).
The `uuid/` package compares `bobzhang/uuidm@0.2.0`, `f4ah6o/uuidm@0.2.1`,
`moonbitstack/moonuuid@0.2.1`, and `wulisususu/moonuuid@0.1.0` against our scalar
and SIMD requests. All adapters validate independent binary values and canonical
results before timing. The 193-case inventory covers individual and 1024-UUID
batch parsing, canonical roundtrips, prepared-value formatting, rejected input,
partial string views, and our arbitrary-byte and reusable-buffer APIs.
Required view-to-String conversion and public API adaptation remain inside the
timer. Unsupported braced parsing in bobzhang/f4ah6o and compact formatting in
wulisususu are omitted explicitly; f4ah6o is a bobzhang fork.

Run `moon run scripts/benchmark.mbtx uuid` for local measurements, or select
`uuid` in the Benchmarks workflow to collect all twelve OS/backend environments.
Use `moon run scripts/benchmark.mbtx all` to measure every integrated library.

## Decimal integers

The [integer adapters](atoi) compare the six-operation decimal port's scalar and
SIMD requests with core string parsers and BigInt restricted to the same 128-bit
ranges. Full and prefix parsing are separate workloads. Core's required UTF-8
conversion, plus handling, missing-prefix scan, and wide range checks remain
inside timing; returned values are formatted only for equivalence tests.

There are 176 integer cases per backend, including one/eight/sixteen/thirty-two
digit inputs, 64/128-bit limits, prefix suffixes, malformed bytes, overflow,
offsets 1/3/15, and 4 KiB/1 MiB leading-zero runs. The excessive-size case measures
only this library because core has no equivalent digit budget. Run
`moon -C benchmarks test atoi --target all`, then `moon run scripts/benchmark.mbtx atoi`.
The collector and report validator independently check the exact case inventory.
Local rendering uses
`moon run scripts/benchmark_report.mbtx --local atoi _build/benchmarks/atoi/windows.json _build/atoi-report`.

## Extrema indices

The [extrema adapters](argminmax) compare `justjavac/argminmax` scalar and SIMD
requests with an independent linear MoonBit reference. All fourteen numeric
kinds use identical prepared typed views; half/wide wrappers and validity
bitmaps are prepared outside timing. Public calls, bitmap validation, callback
dispatch, optional-result adapters, and `bench.keep` remain timed. The pinned
Rust `argminmax@0.7.1` crate identifies the source contract and is not timed here.

The exact 162-case inventory covers short/large inputs, element-offset-one
views, single extrema, first/last NaNs under both policies, validity-bit-offset
three, dense/sparse/all-null bitmaps, and narrow index boundaries. Correctness
tests also use a sort-based oracle and exhaustive IEEE half-float formulas.
Run `moon -C benchmarks test argminmax --target all`, then
`moon run scripts/benchmark.mbtx argminmax`. Results are recorded in
[argminmax/BENCHMARK.md](../argminmax/BENCHMARK.md), with complete statistics in
its companion JSON. Select `argminmax` in the Benchmarks workflow to measure
all three systems and four backends in one run. Explicit local rendering uses
`moon run scripts/benchmark_report.mbtx --local argminmax _build/benchmarks/argminmax/windows.json _build/argminmax-report`.

## Word counts

The [word-count adapters](wc) compare scalar and SIMD requests with an
independent scalar implementation over the same six workloads. Four one-shot
workloads cover short text, offset views, and binary bytes. Two streaming
workloads use prepared 63-byte and 8 KiB chunks. Each adapter checks its LF,
word, and byte totals before timing. Streaming measurements include creating
the public counter, updating it, and reading the totals.

Run `moon -C benchmarks test wc --target all` and
`moon run scripts/benchmark.mbtx wc`. `WC_BENCHMARK_REVERSE=1` reverses
implementation order and saves a distinct local artifact. Render a local run
with `moon run scripts/benchmark_report.mbtx --local wc _build/benchmarks/wc/linux.json _build/wc-report`.
The [word-count benchmark report](../wc/BENCHMARK.md) summarizes the selected CI
snapshot.
