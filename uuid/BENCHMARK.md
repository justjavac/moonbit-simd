# UUID performance comparison

The reproducible comparison suite is in [benchmarks/uuid](../benchmarks/uuid).
It compares scalar and SIMD requests against four pinned Mooncakes UUID packages
through equivalent public parsing and formatting operations.

```text
moon -C benchmarks test --target all
moon run scripts/benchmark.mbtx uuid
```

The collector validates 193 exact cases per backend. A complete report requires
one CI run and attempt covering Linux, macOS, and Windows on native, Wasm,
Wasm GC, and JavaScript. Local measurements are labelled local and cannot be
published as a CI snapshot. The selected complete snapshot will replace this
page after validation by scripts/benchmark_report.mbtx.
