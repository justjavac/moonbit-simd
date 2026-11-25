# Ryu formatting and parsing benchmarks

Complete three-OS/four-backend CI snapshot, 85 cases each (1020 measurements): [run](https://github.com/justjavac/moonbit-simd/actions/runs/45543134882), attempt 1, measured source `3ea16e8da66153646e4288b317f80db6278be9d8`.

All latencies are **nanoseconds per public invocation**. `*` marks CV >= 5% and possible noise. Compare within one OS/backend; a lower mean alone does not establish statistical significance.

## Shortest formatting and parsing

Cells show **Ryu / core adapted (Ryu speedup)**. Speedup divides the unrounded core mean by the Ryu mean: above 1 favors Ryu, below 1 favors core; `*` flags CV >= 5% in either measurement. The core formatter's conversion to the exact Ryu scientific layout and negative-zero sign is included.

| OS/backend | Double 0.3 | Float 0.3 | Parse Double pi | Parse Float pi |
| --- | --- | --- | --- | --- |
| linux/native | 199.904 / 357.841 (1.79x) | 127.153 / 348.374 (2.74x) | 76.564 / 92.697 (1.211x) | 47.524 / 76.826 (1.617x) |
| linux/wasm | 604.381 / 1175.085 (1.944x) | 359.517 / 1167.056 (3.246x) | 214.418 / 307.729 (1.435x) | 138.07 / 302.544 (2.191x) |
| linux/wasm-gc | 136.422 / 349.919 (2.565x) | 102.846 / 292.369 (2.843x) | 85.745 / 150.568 (1.756x) | 63.408 / 113.83 (1.795x) |
| linux/js | 1475.671 / 299.799 (0.203x) | 334.215 / 576.997 (1.726x) | 579.836 / 263.929 (0.455x) | 199.511 / 187.313 (0.939x) |
| macos/native | 213.211* / 468.048* (2.195x*) | 91.443* / 365.551* (3.998x*) | 86.901* / 81.264* (0.935x*) | 74.26* / 52.372 (0.705x*) |
| macos/wasm | 513.654 / 1069.724* (2.083x*) | 498.731* / 1346.574* (2.7x*) | 256.839* / 490.434* (1.909x*) | 104.409* / 301.506* (2.888x*) |
| macos/wasm-gc | 102.819* / 271.292* (2.639x*) | 71.805 / 201.482* (2.806x*) | 76.171* / 147.658* (1.939x*) | 47.892 / 74.013* (1.545x*) |
| macos/js | 1081.328* / 211.147* (0.195x*) | 346.243* / 481.581* (1.391x*) | 544.2* / 286.107* (0.526x*) | 219.596* / 170.146* (0.775x*) |
| windows/native | 656.578 / 1050.628 (1.6x) | 369.385 / 1033.342 (2.797x) | 252.475 / 302.767 (1.199x) | 155.732 / 290.165 (1.863x) |
| windows/wasm | 628.5 / 1180.852 (1.879x) | 345.244 / 1157.5 (3.353x) | 189.828 / 312.447 (1.646x) | 156.067 / 300.376* (1.925x*) |
| windows/wasm-gc | 170.617* / 354.71 (2.079x*) | 111.295 / 315.028 (2.831x) | 102.921* / 157.622* (1.531x*) | 63.043 / 109.119* (1.731x*) |
| windows/js | 1509.019 / 287.112 (0.19x) | 368.642 / 548.138 (1.487x) | 693.354* / 398.63* (0.575x*) | 220.005 / 225.028* (1.023x*) |

## Ryu Printf

Core has no equivalent fixed/scientific precision API in the validated toolchain, so these rows measure the port alone.

| OS/backend | Fixed 1.25, p=6 | Fixed smallest subnormal, p=1074 | Scientific 1.25, p=6 | Scientific 1.25, p=1000 |
| --- | --- | --- | --- | --- |
| linux/native | 267.265 | 7077.757 | 278.769 | 3211.914 |
| linux/wasm | 716.627 | 17824.749 | 792.693 | 9525.054 |
| linux/wasm-gc | 173.682 | 6547.96 | 191.052 | 3743.966 |
| linux/js | 1372.652 | 59594.15 | 1472.538 | 13985.08 |
| macos/native | 202.213* | 6721.021* | 219.28* | 3801.602 |
| macos/wasm | 841.82* | 23276.813* | 857.56* | 14163.619* |
| macos/wasm-gc | 144.405* | 8782.903* | 164.337* | 5538.053* |
| macos/js | 1126.904* | 64707.522* | 1385.478* | 19552.977* |
| windows/native | 815.453 | 18121.827 | 833.218 | 6796.82 |
| windows/wasm | 720.867 | 18028.301 | 800.911 | 9694 |
| windows/wasm-gc | 203.972 | 6952.296 | 219.003 | 4261.58 |
| windows/js | 1471.786 | 61517.675 | 1516.215 | 14372.265 |

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
moon 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moon
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) ~/.moon/bin/moonc
moonrun 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moonrun
v24.22.3
```
