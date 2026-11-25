# ArgMinMax performance comparison

[CI run 45541959176](https://github.com/justjavac/moonbit-simd/actions/runs/45541959176) | [source 7565184](https://github.com/justjavac/moonbit-simd/commit/756518459ff20334fe71b76c964dc3b73cc878d3) | attempt 1

**Scope:** 3 operating system(s) × 4 backends × 162 cases = **1944 measurements**. Every unrounded distribution and its provenance is preserved in the companion [BENCHMARK-DATA.json](BENCHMARK-DATA.json).

The port follows `argminmax@0.7.1`, revision `f68aba5c251e9dc093f3939c0f9607c942228311`. The Rust crate is source provenance and is not timed here. The independent MoonBit linear reference and this library consume the same prepared values and return identical indices before timing. Correctness tests additionally use a sort-based oracle and exhaustive IEEE half-float formulas.

## Timer and dispatch

Typed arrays, half/wide wrappers, and offset-three validity bitmaps are prepared outside the timer. Public calls, bitmap validation, callback dispatch, single-index result adapters, and `bench.keep` are timed. Offset-one cases reuse a partial typed view without materialization. Numeric bytes describe element width; wrapper objects and bitmap storage are additional memory.

Automatic searches use scalar code, with unmasked NaN-ignoring `argminmax` calls for `Float` and `Double` (at least 4096 elements) using vectors on linear-memory Wasm. The tables explicitly request scalar or SIMD. SIMD requests use gathered typed lanes on native/Wasm, scalar tails, and overflow-bounded indices; 128-bit elements, Wasm GC, and JavaScript use scalar fallback. Masked defaults and scalar-only backends use a direct scalar scan with overflow-safe byte/bit positioning; explicit native/Wasm vector requests use valid runs. Leading NaNs are skipped scalarly.

Times are microseconds per invocation; nanoseconds multiply by 1000. **Bold** marks the smallest measured mean; `*` marks CV >= 5% and possible noise. A smaller mean does not establish statistical significance. Compare implementations within the same OS/backend. NaN propagation and all-null inputs can stop early or read only metadata, so these tables report latency rather than nominal throughput.

The core runner calibrates for about 100 ms, records ten batch samples, and applies 5% winsorization. Submicrosecond cases use 100000 iterations per batch. Every record preserves `runs`, `batch_size`, quartiles, variance, mean, median, range, commands, UTC timestamps, CPU, toolchain, and dependencies.

## Measured tradeoffs

For 4096 elements, these ratios divide the SIMD request's mean latency by the scalar mean. Values below 1 favor the SIMD request; the detailed tables mark possible noise.

- **linux:** native Double 0.76x; Wasm Float 0.503x; Wasm Double 0.68x.
- **macos:** native Double 0.173x; Wasm Float 0.526x; Wasm Double 0.662x.
- **windows:** native Double 1.452x; Wasm Float 0.501x; Wasm Double 0.727x.

## Runner context

| OS | CPU | Architecture / logical CPUs | Runner / image | Node.js |
| --- | --- | --- | --- | --- |
| linux | AMD EPYC 7763 64-Core Processor | x86_64 / 4 | ubuntu-latest / ubuntu26 / 20261116.202.1 | v24.22.3 |
| macos | Apple M1 (Virtual) | arm64 / 3 | macos-15 / macos15 / 20261118.0550.1 | v24.22.3 |
| windows | AMD EPYC 7763 64-Core Processor                 | AMD64 / 4 | windows-latest / win25-vs2026 / 20261116.315.1 | v24.22.3 |

## 4096 Int32 elements: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference |
| --- | --- | --- | --- |
| linux / native | **3.925** | 4.189 | 6.45 |
| linux / wasm | 9.058 | **6.205** | 12.918 |
| linux / wasm-gc | 9.016 | **9.007** | 12.842 |
| linux / js | **5.21** | 5.234 | 11.597 |
| macos / native | 5.532 | **2.18*** | 6.775* |
| macos / wasm | 8.825* | **3.807*** | 10.759* |
| macos / wasm-gc | **8.594*** | 9.147* | 9.871* |
| macos / js | **4.957** | 5.16 | 9.859 |
| windows / native | **4.039** | 5.587 | 6.593 |
| windows / wasm | 9.218 | **6.309** | 13.291 |
| windows / wasm-gc | 11.384* | **9.958*** | 15.009* |
| windows / js | **5.265** | 5.428* | 11.829 |

## 4096 Float elements: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference |
| --- | --- | --- | --- |
| linux / native | 6.502 | **4.519** | 5.143 |
| linux / wasm | 11.717 | **5.899** | 11.702 |
| linux / wasm-gc | **9.905** | 9.908 | 11.699 |
| linux / js | **5.283** | 5.333 | 12.954 |
| macos / native | 16.676 | **1.941** | 16.37 |
| macos / wasm | 9.884* | **5.202*** | 8.758 |
| macos / wasm-gc | 8.62* | **8.163*** | 9.98* |
| macos / js | 5.869* | **5.78** | 10.39 |
| windows / native | **5.366** | 5.588 | 7.983 |
| windows / wasm | 11.919 | **5.976** | 11.904 |
| windows / wasm-gc | 11.541* | **11.05*** | 12.544* |
| windows / js | **5.328** | 5.342 | 13.132 |

## 4096 Double elements: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference |
| --- | --- | --- | --- |
| linux / native | 6.462 | **4.911** | 5.147 |
| linux / wasm | 12.376* | **8.42** | 11.73 |
| linux / wasm-gc | **9.928** | 9.951 | 11.055 |
| linux / js | **5.257** | 5.268 | 12.975 |
| macos / native | 16.451 | **2.841** | 16.359 |
| macos / wasm | 10.189* | **6.745*** | 9.229* |
| macos / wasm-gc | **7.461** | 7.752* | 9.422 |
| macos / js | **5.698** | 5.929 | 10.338 |
| windows / native | **5.44** | 7.897 | 8.035 |
| windows / wasm | 11.842 | **8.612** | 11.897 |
| windows / wasm-gc | **10.067** | 10.077 | 11.308 |
| windows / js | 5.405 | **5.36** | 13.077 |

## 33 Byte elements: latency (ns)

| OS / backend | ours scalar | ours SIMD request | linear reference |
| --- | --- | --- | --- |
| linux / native | 65.552 | 265.842 | **63.21** |
| linux / wasm | **131.655** | 383.945 | 150.449 |
| linux / wasm-gc | 80.791 | **80.612** | 108.102 |
| linux / js | **44.358** | 58.12 | 136.518 |
| macos / native | **56.824*** | 103.418 | 74.887* |
| macos / wasm | 183.312* | 398.933* | **110.45** |
| macos / wasm-gc | 101.607* | **68.861*** | 97.765* |
| macos / js | **38.637** | 67.153* | 100.123 |
| windows / native | **117.749** | 326.272 | 142.067 |
| windows / wasm | **152.297*** | 403.651* | 167.537 |
| windows / wasm-gc | **82.31** | 82.499 | 117.113* |
| windows / js | **46.874*** | 58.681 | 138.402 |

## 1,048,576 Int32 elements at offset one: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference |
| --- | --- | --- | --- |
| linux / native | **986.393** | 1067.534 | 1639.729 |
| linux / wasm | 2294.048 | **1568.776** | 3309.757 |
| linux / wasm-gc | **2293.572** | 2296.283 | 3283.489 |
| linux / js | 5568.295 | **4464.889*** | 5240.603 |
| macos / native | 1412.04 | **505.122** | 1855.795* |
| macos / wasm | 2394.345* | **1109.156*** | 2454.92* |
| macos / wasm-gc | 2259.315* | **1973.186*** | 2404.083* |
| macos / js | 3642.816 | **2348.274** | 3779.746 |
| windows / native | **995.841** | 1406.401 | 1680.172 |
| windows / wasm | 2314.221 | **1576.633** | 3362.253 |
| windows / wasm-gc | 2426.645* | **2350.54** | 3307.489 |
| windows / js | 5669.906 | **4536.254*** | 5370.113 |

## Dense validity bitmap, 4096 Double elements: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference |
| --- | --- | --- | --- |
| linux / native | **6.751** | 10.215 | 9.042 |
| linux / wasm | 16.912 | **15.742** | 19.421 |
| linux / wasm-gc | 16.864 | 16.837 | **16.819** |
| linux / js | **21.972** | 22.002 | 22.069* |
| macos / native | 7.158* | **7.143*** | 17.224 |
| macos / wasm | 13.259* | **11.316** | 14.223 |
| macos / wasm-gc | 10.264 | **10.223** | 11.296 |
| macos / js | 18.124* | 18.435* | **16.362** |
| windows / native | 10.627 | 13.543 | **10.605** |
| windows / wasm | 17.3 | **16.033** | 19.629 |
| windows / wasm-gc | 17.148 | 17.269 | **17.033** |
| windows / js | 22.313 | 22.368 | **21.24** |

## Last NaN propagation, 4096 Double elements: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference |
| --- | --- | --- | --- |
| linux / native | 6.463 | **4.728** | 5.182 |
| linux / wasm | **11.728** | 15.038 | 11.77 |
| linux / wasm-gc | 9.939 | **9.934** | 11.17 |
| linux / js | 5.411* | **5.28** | 11.655 |
| macos / native | 17.384 | **3.671*** | 18.689 |
| macos / wasm | **8.059** | 13.18* | 9.806* |
| macos / wasm-gc | 9.201* | **7.192** | 8.603 |
| macos / js | **6.036** | 6.517* | 11.451 |
| windows / native | **5.479** | 8.557 | 7.996 |
| windows / wasm | **11.974** | 15.672 | 12.64* |
| windows / wasm-gc | **10.221** | 10.232 | 11.264 |
| windows / js | **5.334** | 5.386 | 11.871 |

## Reproduction and toolchain

```text
moon -C benchmarks test argminmax --target all
moon run scripts/benchmark.mbtx argminmax
moon run scripts/benchmark_report.mbtx --self-test
```

**linux:**

~~~text
moon 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moon
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) ~/.moon/bin/moonc
moonrun 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moonrun
~~~

**macos:**

~~~text
moon 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moon
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) ~/.moon/bin/moonc
moonrun 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moonrun
~~~

**windows:**

~~~text
moon 0.1.20261120 (aaf8010 2026-11-20) ~\.moon\bin\moon.exe
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) ~\.moon\bin\moonc.exe
moonrun 0.1.20261120 (aaf8010 2026-11-20) ~\.moon\bin\moonrun.exe
~~~

Publish a snapshot from one complete CI run and attempt covering three systems and four backends. Raw artifacts remain available for 90 days. Local outputs retain their local label and dirty-checkout state.
