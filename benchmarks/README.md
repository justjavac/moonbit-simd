# Development benchmarks

This MIT-licensed module contains development-only CRC-32/ISO-HDLC and WHATWG URL
comparison adapters. Its nested workspace links the local `justjavac/crc32` and `justjavac/url` modules while
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
