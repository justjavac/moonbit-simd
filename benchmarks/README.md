# Development benchmarks

This MIT-licensed module contains development-only CRC-32/ISO-HDLC, WHATWG URL,
and Base64 comparison adapters. Its nested workspace links the local
`justjavac/crc32`, `justjavac/url`, and `justjavac/base64` modules while
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
