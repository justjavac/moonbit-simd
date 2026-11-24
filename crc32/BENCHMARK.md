# justjavac/crc32 Benchmark Report

This file is reserved for the first complete GitHub Actions benchmark snapshot.
CI measurements have not been collected yet; no local timings are presented as
CI results.

The Benchmarks workflow measures Linux, macOS, and Windows across the native,
Wasm, Wasm GC, and JavaScript backends. It records 69 cases per backend covering
one-shot hashing, nonzero view offsets, incremental chunk sizes, and checksum
combination. Its generated report includes CPU and runner identity, exact
toolchain versions, source commit, CI run, sampling details, variability,
latency, and throughput.

After that run completes, replace this placeholder with the CI-generated
`BENCHMARK.md` and preserve its companion `BENCHMARK-DATA.json`. Raw per-backend
logs remain available in the run's artifacts.
