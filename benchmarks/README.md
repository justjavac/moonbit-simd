# Development benchmarks

This MIT-licensed module contains development-only CRC-32/ISO-HDLC comparison
adapters. Its nested workspace links the local `justjavac/crc32` module while
keeping third-party dependencies out of the published library.

Run `moon -C benchmarks test --target all` before measuring. Results are recorded
in [crc32/BENCHMARK.md](../crc32/BENCHMARK.md), with all statistics and pinned
dependency versions in the companion JSON snapshot.

The suite compares identical bytes using each library's public API. Owned-byte
inputs and streaming chunks are prepared outside the timer; view-to-owned
conversion is included only in the separately labelled view workload. Digest
creation, byte-wise API loops, updates, and finalization are timed.
