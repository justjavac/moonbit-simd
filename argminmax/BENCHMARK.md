# ArgMinMax performance comparison

[CI run 45553517657](https://github.com/justjavac/moonbit-simd/actions/runs/45553517657) | [source 791fa3e](https://github.com/justjavac/moonbit-simd/commit/791fa3e6d784bd1e372e4f2dbda89db1de2da297) | attempt 1

**Scope:** 3 operating system(s) × 4 backends × 162 cases = **1944 measurements**. Every unrounded distribution and its provenance is preserved in the companion [BENCHMARK-DATA.json](BENCHMARK-DATA.json).

The port follows `argminmax@0.7.1`, revision `f68aba5c251e9dc093f3939c0f9607c942228311`. The Rust crate is source provenance and is not timed here. The independent MoonBit linear reference and this library consume the same prepared values and return identical indices before timing. Correctness tests additionally use a sort-based oracle and exhaustive IEEE half-float formulas.

## Timer and dispatch

Typed arrays, half/wide wrappers, and offset-three validity bitmaps are prepared outside the timer. Public calls, bitmap validation, callback dispatch, single-index result adapters, and `bench.keep` are timed. Offset-one cases reuse a partial typed view without materialization. Numeric bytes describe element width; wrapper objects and bitmap storage are additional memory.

Automatic searches use scalar code, with unmasked NaN-ignoring `argminmax` calls for `Float` and `Double` (at least 4096 elements) using vectors on linear-memory Wasm. The tables explicitly request scalar or SIMD. SIMD requests use gathered typed lanes on native/Wasm, scalar tails, and overflow-bounded indices; 128-bit elements, Wasm GC, and JavaScript use scalar fallback. Masked defaults and scalar-only backends use a direct scalar scan with overflow-safe byte/bit positioning; explicit native/Wasm vector requests use valid runs. Leading NaNs are skipped scalarly.

Times are microseconds per invocation; nanoseconds multiply by 1000. **Bold** marks the smallest measured mean; `*` marks CV >= 5% and possible noise. A smaller mean does not establish statistical significance. Compare implementations within the same OS/backend. NaN propagation and all-null inputs can stop early or read only metadata, so these tables report latency rather than nominal throughput.

The core runner calibrates for about 100 ms, records ten batch samples, and applies 5% winsorization. Submicrosecond cases use 100000 iterations per batch. Every record preserves `runs`, `batch_size`, quartiles, variance, mean, median, range, commands, UTC timestamps, CPU, toolchain, and dependencies.

## Measured tradeoffs

For 4096 elements, these ratios divide the SIMD request's mean latency by the scalar mean. Values below 1 favor the SIMD request; the detailed tables mark possible noise.

- **linux:** native Double 0.862x; Wasm Float 0.487x; Wasm Double 0.678x.
- **macos:** native Double 0.193x; Wasm Float 0.485x; Wasm Double 0.872x.
- **windows:** native Double 1.506x; Wasm Float 0.572x; Wasm Double 0.815x.

## Runner context

| OS | CPU | Architecture / logical CPUs | Runner / image | Node.js |
| --- | --- | --- | --- | --- |
| linux | INTEL(R) XEON(R) PLATINUM 8573C | x86_64 / 4 | ubuntu-latest / ubuntu26 / 20261116.202.1 | v24.22.3 |
| macos | Apple M1 (Virtual) | arm64 / 3 | macos-15 / macos15 / 20261118.0550.1 | v24.22.3 |
| windows | AMD EPYC 9V74 80-Core Processor                 | AMD64 / 4 | windows-latest / win25-vs2026 / 20261116.315.1 | v24.22.3 |

## 4096 Int32 elements: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference |
| --- | --- | --- | --- |
| linux / native | **3.424** | 4.324 | 5.481 |
| linux / wasm | 8.174 | **5.827** | 13.424 |
| linux / wasm-gc | 7.838 | **7.791** | 10.873 |
| linux / js | **5.475** | 5.477 | 12.942 |
| macos / native | 6.565* | **2.296*** | 7.33* |
| macos / wasm | 12.413* | **6.076*** | 13.51* |
| macos / wasm-gc | 7.95* | **7.524*** | 10.957* |
| macos / js | **5.009** | 5.679* | 9.788 |
| windows / native | **3.558** | 4.895 | 4.661 |
| windows / wasm | **7.102** | 12.758 | 10.312 |
| windows / wasm-gc | **6.581** | 6.606 | 9.343 |
| windows / js | **4.575** | 4.575 | 10.215 |

## 4096 Float elements: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference |
| --- | --- | --- | --- |
| linux / native | 6.812 | **4.909** | 8.123 |
| linux / wasm | 13.099 | **6.375** | 14.486 |
| linux / wasm-gc | 12.571 | **12.564** | 14.812 |
| linux / js | 7.591 | **7.572** | 12.437 |
| macos / native | 18.567* | **2.633*** | 17.296 |
| macos / wasm | 13.483* | **6.537*** | 11.158* |
| macos / wasm-gc | 8.938* | **8.073*** | 10.095* |
| macos / js | 5.625 | **5.613** | 10.439 |
| windows / native | **4.623** | 4.891 | 6.883 |
| windows / wasm | 9.092 | **5.205** | 9.163 |
| windows / wasm-gc | 6.869 | **6.849** | 10.225 |
| windows / js | **4.605** | 4.649 | 9.143 |

## 4096 Double elements: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference |
| --- | --- | --- | --- |
| linux / native | 7.922* | **6.827** | 8.102 |
| linux / wasm | 12.407 | **8.412** | 13.79 |
| linux / wasm-gc | **11.921** | 11.945 | 13.355 |
| linux / js | **7.567** | 7.569 | 12.384 |
| macos / native | 17.822 | **3.443*** | 17.746* |
| macos / wasm | 11.72* | **10.226*** | 13.376* |
| macos / wasm-gc | **7.968*** | 8.01* | 10.071* |
| macos / js | 5.706 | **5.632** | 10.437 |
| windows / native | **4.657** | 7.014 | 5.791 |
| windows / wasm | 9.139 | **7.449** | 9.143 |
| windows / wasm-gc | **7.576** | 7.594 | 9.083 |
| windows / js | 4.597 | **4.576** | 9.102 |

## 33 Byte elements: latency (ns)

| OS / backend | ours scalar | ours SIMD request | linear reference |
| --- | --- | --- | --- |
| linux / native | **57.017** | 230.853 | 66.524* |
| linux / wasm | **106.53** | 339.219 | 128.364 |
| linux / wasm-gc | **67.281** | 67.668 | 88.4 |
| linux / js | **47.99** | 51.532 | 143.725 |
| macos / native | **59.301*** | 145.127* | 117.557* |
| macos / wasm | **151.814*** | 423.597* | 171.807* |
| macos / wasm-gc | 79.761* | **67.434*** | 78.276* |
| macos / js | **42.022** | 51.209* | 100.699 |
| windows / native | **88.334** | 277.65 | 121.902* |
| windows / wasm | **100.287** | 319.087 | 116.469 |
| windows / wasm-gc | 64.356 | **64.344** | 82.913 |
| windows / js | **43.023** | 46.047 | 114.77 |

## 1,048,576 Int32 elements at offset one: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference |
| --- | --- | --- | --- |
| linux / native | **889.389** | 1103.09 | 1514.227 |
| linux / wasm | 2168.727 | **1459.222** | 3327.8 |
| linux / wasm-gc | **1954.236** | 1955.111 | 2787.253 |
| linux / js | 3546.381 | **3490.921** | 4633.345 |
| macos / native | 1614.18* | **625.147*** | 1873.798 |
| macos / wasm | 2957.831* | **1299.992*** | 2952.131* |
| macos / wasm-gc | 1783.894 | **1781.768** | 2177.05 |
| macos / js | 3854.941 | **2310.108** | 3905.226 |
| windows / native | **865.944** | 1231.298 | 1159.574 |
| windows / wasm | 2341.248* | **1327.521** | 2770.358* |
| windows / wasm-gc | **1680.261** | 1750.152* | 2527.794* |
| windows / js | 3493.405 | **2887.341** | 3803.905 |

## Dense validity bitmap, 4096 Double elements: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference |
| --- | --- | --- | --- |
| linux / native | **8.922** | 11.997 | 11.616 |
| linux / wasm | 18.656 | **16.286** | 22.731 |
| linux / wasm-gc | **18.6** | 18.608 | 20.005 |
| linux / js | 22.603 | 22.547 | **21.844** |
| macos / native | **7.253*** | 8.863* | 21.463* |
| macos / wasm | 16.79* | **14.811*** | 19.463* |
| macos / wasm-gc | **10.139** | 10.41 | 11.28 |
| macos / js | 15.739 | 15.541 | **15.3** |
| windows / native | **8.098** | 11.685 | 9.149 |
| windows / wasm | **13.733** | 13.942 | 16.22 |
| windows / wasm-gc | **13.631** | 13.68 | 14.696 |
| windows / js | 18.284 | 18.483 | **15.92** |

## Last NaN propagation, 4096 Double elements: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference |
| --- | --- | --- | --- |
| linux / native | **6.834** | 6.964 | 8.116 |
| linux / wasm | 12.396 | **12.154** | 13.774 |
| linux / wasm-gc | **11.873** | 12.011 | 13.078 |
| linux / js | **7.929** | 7.958 | 12.335 |
| macos / native | 18.381 | **4.805*** | 19.088* |
| macos / wasm | **10.575*** | 14.273* | 12.27* |
| macos / wasm-gc | **7.025** | 7.266 | 8.611 |
| macos / js | **5.706** | 6.413* | 10.678 |
| windows / native | **4.642** | 6.865 | 6.887 |
| windows / wasm | **9.181** | 12.093 | 9.186 |
| windows / wasm-gc | 7.603 | **7.599** | 9.178 |
| windows / js | 4.611 | **4.6** | 9.123 |

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
