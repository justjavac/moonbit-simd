# Ryu formatting and parsing benchmarks

**Local measurements; a selected complete CI snapshot is pending.** Four backends, 85 cases each (340 measurements). Source HEAD `a39373237b2b2b8ee0d544a9cc9fa0282d2d5854`; working tree dirty: `true`. CPU: 13th Gen Intel(R) Core(TM) i7-13650HX.

All latencies are **nanoseconds per public invocation**. `*` marks CV >= 5% and possible noise. Compare within one OS/backend; a lower mean alone does not establish statistical significance.

## Shortest formatting and parsing

Cells show **Ryu / core adapted**. The core formatter's conversion to the exact Ryu scientific layout and negative-zero sign is included.

| OS/backend | Double 0.3 | Float 0.3 | Parse Double pi | Parse Float pi |
| --- | --- | --- | --- | --- |
| windows/native | 1087.567* / 3367.676* | 2196.558* / 7007.275* | 773.31 / 966.382 | 523.273* / 769.736* |
| windows/wasm | 465.075 / 889.278 | 1412.568* / 6739.734* | 528.108* / 743.077* | 390.243* / 718.885* |
| windows/wasm-gc | 101.551 / 227.56* | 295.285* / 798.933* | 237.832 / 419.809* | 140.015* / 285.932* |
| windows/js | 1091.318 / 278.944* | 891.271* / 1340.147* | 2049.338* / 1262.616* | 918.599* / 1134.398* |

## Ryu Printf

Core has no equivalent fixed/scientific precision API in the validated toolchain, so these rows measure the port alone.

| OS/backend | Fixed 1.25, p=6 | Fixed smallest subnormal, p=1074 | Scientific 1.25, p=6 | Scientific 1.25, p=1000 |
| --- | --- | --- | --- | --- |
| windows/native | 3288.896* | 61633.417* | 3333.412* | 18122.221* |
| windows/wasm | 1741.123* | 42933.597* | 1808.483 | 26740.648 |
| windows/wasm-gc | 478.66* | 17848.816* | 526.47* | 11810.065 |
| windows/js | 4200.595* | 159795.579* | 4054.471* | 39532.365 |

## Method and limits

- Production code uses portable scalar integer Ryu on every backend; these measurements make no SIMD claim.
- Prepared numeric values, Float construction, ASCII strings, and offset backing strings are outside timing. Public calls, returned-string allocation, core layout/narrowing adapters, optional-bit results, callback dispatch, and `bench.keep` are timed.
- Core shortest Float formatting uses original Float precision. Core has no direct Float parser here; parsing includes its required Double-to-Float narrowing. All measured parse bits match independent expected values, but that adapter does not establish equivalent rounding for every possible decimal.
- The 85-case inventory includes source precision, negative zero, subnormals, maximum finite values, integer shortcuts, carries, malformed parse input, leading zeroes, offsets 1/3/15, and Printf precision through 1074. Input widths are 8/4 bytes for numeric values; parser inputs are ASCII, so byte counts equal UTF-16 code units. No byte-stream throughput is reported.
- Release mode and `--no-parallelize`; four backends run sequentially. Core calibrates around 100 ms and takes 10 batch samples with 5% winsorization. Submicrosecond cases use 100000 calls per batch; every unrounded statistic and batch size is retained in the JSON.
- Upstream C is a correctness reference at `4c0618b0e44f7ef027ebae05d2cc7812048f7c8f` under BSL-1.0. It is not timed across languages.

## Reproduction and dependencies

| Adapter package | Version | License |
| --- | --- | --- |
| moonbitlang/core/builtin | moonc v0.10.22+7b085e9a4-nightly (2026-11-22) | Apache-2.0 |
| moonbitlang/core/string | moonc v0.10.22+7b085e9a4-nightly (2026-11-22) | Apache-2.0 |

```text
moon -C benchmarks test ryu --target all
moon run scripts/benchmark.mbtx ryu
moon run scripts/benchmark_report.mbtx --local ryu _build/benchmarks/ryu/windows.json _build/ryu-report
```

Publish only one complete CI snapshot with matching source, run, attempt, manifests, dependencies, workloads, and all three systems/four backends. Local data stays explicitly local. Raw CI artifacts are retained for 90 days; local raw logs and full collector JSON are in ignored `_build/benchmarks/ryu/`. The selected `BENCHMARK-DATA.json` is added only after complete CI validation.

Toolchain:

```text
moon 0.1.20261120 (aaf8010 2026-11-20) D:\App\.moon\bin\moon.exe
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) D:\App\.moon\bin\moonc.exe
moonrun 0.1.20261120 (aaf8010 2026-11-20) D:\App\.moon\bin\moonrun.exe
v24.1.0
```
