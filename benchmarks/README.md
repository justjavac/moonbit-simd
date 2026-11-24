# Development benchmarks

This MIT-licensed module contains development-only CRC-32/ISO-HDLC, WHATWG URL,
and UUID comparison adapters. Its nested workspace links the local libraries while
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
