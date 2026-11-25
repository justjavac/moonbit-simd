# Decimal integer benchmarks

**Local Windows results; a selected complete CI snapshot is pending.** The final implementation was measured across four backends with 176 cases each (704 measurements). Source HEAD `1cad3cc96c4c5ac98fd6cc940bb81e6f358216d5`, with uncommitted source changes. CPU: 13th Gen Intel(R) Core(TM) i7-13650HX.

The development host had concurrent Moon/Node activity during the final measurement. Absolute latencies differ from earlier development passes; compare implementations within this pass and retain the variation marks. Generated release code was checked for coverage instrumentation and had none. These local timings are not a stable hosted-runner or cross-system result.

## Representative public parsing latency

All values are nanoseconds per public invocation, including the documented adapter calls. `*` indicates CV >= 5% and possible noise.

| Backend | Input | Scalar | SIMD request | Core adapted |
| --- | --- | --- | --- | --- |
| native | UInt64, 16 digits | 1267.272 | 1164.262 | 1295.128 |
| native | UInt128 maximum | 2790.877 | 2474.933 | 3319.825 |
| wasm | UInt64, 16 digits | 909.155 | 1098.844* | 2169.407* |
| wasm | UInt128 maximum | 1191.028* | 1015.849 | 1786.698* |
| wasm-gc | UInt64, 16 digits | 269.125* | 241.27* | 900.402 |
| wasm-gc | UInt128 maximum | 550.807 | 526.39 | 705.139 |
| js | UInt64, 16 digits | 1009.81 | 985.108 | 2312.211 |
| js | UInt128 maximum | 3251.249* | 3192.767 | 875.026 |

## Early rejection of a 64 KiB nonzero UInt32 input

These cases report latency in microseconds. This library proves overflow within a bounded block; core's byte adapter must first decode the whole input to UTF-16.

| Backend | Scalar | SIMD request | Core adapted |
| --- | --- | --- | --- |
| native | 1.009 | 0.849 | 553.925* |
| wasm | 0.498 | 0.421 | 43.503 |
| wasm-gc | 0.199 | 0.196 | 541.075* |
| js | 1.084 | 1.073 | 37.726 |

## Findings and method

- Compare this library's scalar and SIMD requests to assess vector gains. Native and linear-memory Wasm use bounded V128 digit scans and reduction for complete 16-byte blocks. Wasm GC and JavaScript use scalar/SWAR for both requests; timing differences on those backends are not vector gains.
- Leading-zero removal uses SWAR for both requests. The earlier local V128 zero scan took about 511 vs 102 microseconds on native and 270 vs 123 microseconds on Wasm for one MiB, so the final dispatch keeps SWAR for that scan. All-zero input can remain entirely scalar/SWAR with a SIMD request.
- Full/prefix parsing, signed minima, unsigned maxima, malformed bytes, overflow, and offsets 1/3/15 are separate cases. Core comparisons include strict UTF-8 conversion, its missing prefix scan, and exact 128-bit range checks. Core wide bounds are prepared outside timing. Values are formatted only during correctness checks.
- Core BigInt uses a different representation; it can outperform the private word-pair result on JavaScript. These competitor comparisons include conversion and representation costs. A best mean does not establish statistical significance.
- Prepared inputs are outside timing; public calls, optional-result adaptation, generic callbacks, and bench.keep are timed. Release mode, --no-parallelize, and sequential backends are used. Core records 10 batch samples after calibration around 100 ms with 5% winsorization; fast cases use 100000 iterations per batch. Raw results retain runs, batch_size, and every unrounded statistic.

Native coverage is **97.65% (166/170 executable lines)**. The four unhit locations are Wasm GC/JavaScript dispatch bodies emitted into the native coverage source metadata; those paths pass their own backend tests. No executable code is skipped to alter coverage.

## Reproduction and provenance

~~~text
moon 0.1.20261120 (aaf8010 2026-11-20) D:\App\.moon\bin\moon.exe
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) D:\App\.moon\bin\moonc.exe
moonrun 0.1.20261120 (aaf8010 2026-11-20) D:\App\.moon\bin\moonrun.exe
v24.1.0
~~~

- native: 2026-11-25T00:59:40Z to 2026-11-25T01:03:31Z (UTC).
- wasm: 2026-11-25T01:03:31Z to 2026-11-25T01:06:47Z (UTC).
- wasm-gc: 2026-11-25T01:06:48Z to 2026-11-25T01:09:06Z (UTC).
- js: 2026-11-25T01:09:07Z to 2026-11-25T01:12:36Z (UTC).

```text
moon -C benchmarks test atoi --target all
moon run scripts/benchmark.mbtx atoi
moon run scripts/benchmark_report.mbtx --local atoi _build/benchmarks/atoi/windows.json _build/atoi-report
```

The local collector JSON and raw logs are under `_build/benchmarks/atoi/`; the validated full local report and JSON are under `_build/atoi-report/`. These generated files are ignored. The selected `BENCHMARK-DATA.json` will be added only from a complete three-OS/four-backend CI run (2112 measurements), with matching source commit, repository, run, attempt, manifests, dependencies, and exact case inventory. Local data is never relabeled as CI data.

See [README.md](README.md) for contracts and upstream compatibility choices, and [the comparison guide](../benchmarks/README.md) for adapter details.
