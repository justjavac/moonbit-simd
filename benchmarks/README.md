# Development benchmarks

This MIT-licensed module contains development-only CRC-32/ISO-HDLC, WHATWG URL,
and UTF-8 comparison adapters. Its nested workspace links the local libraries while
keeping third-party dependencies out of the published library.

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
