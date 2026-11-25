# ArgMinMax performance comparison

[CI run 45553517657](https://github.com/justjavac/moonbit-simd/actions/runs/45553517657) | [source 791fa3e](https://github.com/justjavac/moonbit-simd/commit/791fa3e6d784bd1e372e4f2dbda89db1de2da297) | attempt 1

**Scope:** 3 operating system(s) × 4 backends × 162 cases = **1944 measurements**. Every unrounded distribution and its provenance is preserved in the companion [BENCHMARK-DATA.json](BENCHMARK-DATA.json).

**Speedups:** `SIMD speedup` = scalar mean / SIMD-request mean; `Best ours vs ref` = fastest reference mean / fastest shown `ours` mean. Ratios use unrounded latencies within each OS/backend: above 1 is faster, below 1 is slower. `*` marks CV >= 5% in either measurement. The best measured path can differ from automatic dispatch; a SIMD request can use scalar fallback.

The port follows `argminmax@0.7.1`, revision `f68aba5c251e9dc093f3939c0f9607c942228311`. The Rust crate is source provenance and is not timed here. The independent MoonBit linear reference and this library consume the same prepared values and return identical indices before timing. Correctness tests additionally use a sort-based oracle and exhaustive IEEE half-float formulas.

## Timer and dispatch

Typed arrays, half/wide wrappers, and offset-three validity bitmaps are prepared outside the timer. Public calls, bitmap validation, callback dispatch, single-index result adapters, and `bench.keep` are timed. Offset-one cases reuse a partial typed view without materialization. Numeric bytes describe element width; wrapper objects and bitmap storage are additional memory.

Automatic searches use scalar code, with unmasked NaN-ignoring `argminmax` calls for `Float` and `Double` (at least 4096 elements) using vectors on linear-memory Wasm. The tables explicitly request scalar or SIMD. SIMD requests use gathered typed lanes on native/Wasm, scalar tails, and overflow-bounded indices; 128-bit elements, Wasm GC, and JavaScript use scalar fallback. Masked defaults and scalar-only backends use a direct scalar scan with overflow-safe byte/bit positioning; explicit native/Wasm vector requests use valid runs. Leading NaNs are skipped scalarly.

Times are microseconds per invocation; nanoseconds multiply by 1000. **Bold** marks the smallest measured mean; `*` marks CV >= 5% and possible noise. A smaller mean does not establish statistical significance. Compare implementations within the same OS/backend. NaN propagation and all-null inputs can stop early or read only metadata, so these tables report latency rather than nominal throughput.

The core runner calibrates for about 100 ms, records ten batch samples, and applies 5% winsorization. Submicrosecond cases use 100000 iterations per batch. Every record preserves `runs`, `batch_size`, quartiles, variance, mean, median, range, commands, UTC timestamps, CPU, toolchain, and dependencies.

## Measured tradeoffs

For 4096 elements, these speedups divide scalar mean latency by SIMD-request mean latency. Values above 1 favor the SIMD request; `*` marks possible noise in either measurement.

- **linux:** native Double 1.16x*; Wasm Float 2.055x; Wasm Double 1.475x.
- **macos:** native Double 5.177x*; Wasm Float 2.063x*; Wasm Double 1.146x*.
- **windows:** native Double 0.664x; Wasm Float 1.747x; Wasm Double 1.227x.

## Runner context

| OS | CPU | Architecture / logical CPUs | Runner / image | Node.js |
| --- | --- | --- | --- | --- |
| linux | INTEL(R) XEON(R) PLATINUM 8573C | x86_64 / 4 | ubuntu-latest / ubuntu26 / 20261116.202.1 | v24.22.3 |
| macos | Apple M1 (Virtual) | arm64 / 3 | macos-15 / macos15 / 20261118.0550.1 | v24.22.3 |
| windows | AMD EPYC 9V74 80-Core Processor                 | AMD64 / 4 | windows-latest / win25-vs2026 / 20261116.315.1 | v24.22.3 |

## 4096 Int32 elements: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: |
| linux / native | **3.424** | 4.324 | 5.481 | 0.792x | 1.601x |
| linux / wasm | 8.174 | **5.827** | 13.424 | 1.403x | 2.304x |
| linux / wasm-gc | 7.838 | **7.791** | 10.873 | 1.006x | 1.396x |
| linux / js | **5.475** | 5.477 | 12.942 | 1x | 2.364x |
| macos / native | 6.565* | **2.296*** | 7.33* | 2.859x* | 3.192x* |
| macos / wasm | 12.413* | **6.076*** | 13.51* | 2.043x* | 2.224x* |
| macos / wasm-gc | 7.95* | **7.524*** | 10.957* | 1.057x* | 1.456x* |
| macos / js | **5.009** | 5.679* | 9.788 | 0.882x* | 1.954x |
| windows / native | **3.558** | 4.895 | 4.661 | 0.727x | 1.31x |
| windows / wasm | **7.102** | 12.758 | 10.312 | 0.557x | 1.452x |
| windows / wasm-gc | **6.581** | 6.606 | 9.343 | 0.996x | 1.42x |
| windows / js | **4.575** | 4.575 | 10.215 | 1x | 2.233x |

## 4096 Float elements: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: |
| linux / native | 6.812 | **4.909** | 8.123 | 1.388x | 1.655x |
| linux / wasm | 13.099 | **6.375** | 14.486 | 2.055x | 2.272x |
| linux / wasm-gc | 12.571 | **12.564** | 14.812 | 1.001x | 1.179x |
| linux / js | 7.591 | **7.572** | 12.437 | 1.003x | 1.643x |
| macos / native | 18.567* | **2.633*** | 17.296 | 7.051x* | 6.568x* |
| macos / wasm | 13.483* | **6.537*** | 11.158* | 2.063x* | 1.707x* |
| macos / wasm-gc | 8.938* | **8.073*** | 10.095* | 1.107x* | 1.251x* |
| macos / js | 5.625 | **5.613** | 10.439 | 1.002x | 1.86x |
| windows / native | **4.623** | 4.891 | 6.883 | 0.945x | 1.489x |
| windows / wasm | 9.092 | **5.205** | 9.163 | 1.747x | 1.761x |
| windows / wasm-gc | 6.869 | **6.849** | 10.225 | 1.003x | 1.493x |
| windows / js | **4.605** | 4.649 | 9.143 | 0.991x | 1.986x |

## 4096 Double elements: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: |
| linux / native | 7.922* | **6.827** | 8.102 | 1.16x* | 1.187x |
| linux / wasm | 12.407 | **8.412** | 13.79 | 1.475x | 1.639x |
| linux / wasm-gc | **11.921** | 11.945 | 13.355 | 0.998x | 1.12x |
| linux / js | **7.567** | 7.569 | 12.384 | 1x | 1.637x |
| macos / native | 17.822 | **3.443*** | 17.746* | 5.177x* | 5.155x* |
| macos / wasm | 11.72* | **10.226*** | 13.376* | 1.146x* | 1.308x* |
| macos / wasm-gc | **7.968*** | 8.01* | 10.071* | 0.995x* | 1.264x* |
| macos / js | 5.706 | **5.632** | 10.437 | 1.013x | 1.853x |
| windows / native | **4.657** | 7.014 | 5.791 | 0.664x | 1.243x |
| windows / wasm | 9.139 | **7.449** | 9.143 | 1.227x | 1.227x |
| windows / wasm-gc | **7.576** | 7.594 | 9.083 | 0.998x | 1.199x |
| windows / js | 4.597 | **4.576** | 9.102 | 1.005x | 1.989x |

## 33 Byte elements: latency (ns)

| OS / backend | ours scalar | ours SIMD request | linear reference | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: |
| linux / native | **57.017** | 230.853 | 66.524* | 0.247x | 1.167x* |
| linux / wasm | **106.53** | 339.219 | 128.364 | 0.314x | 1.205x |
| linux / wasm-gc | **67.281** | 67.668 | 88.4 | 0.994x | 1.314x |
| linux / js | **47.99** | 51.532 | 143.725 | 0.931x | 2.995x |
| macos / native | **59.301*** | 145.127* | 117.557* | 0.409x* | 1.982x* |
| macos / wasm | **151.814*** | 423.597* | 171.807* | 0.358x* | 1.132x* |
| macos / wasm-gc | 79.761* | **67.434*** | 78.276* | 1.183x* | 1.161x* |
| macos / js | **42.022** | 51.209* | 100.699 | 0.821x* | 2.396x |
| windows / native | **88.334** | 277.65 | 121.902* | 0.318x | 1.38x* |
| windows / wasm | **100.287** | 319.087 | 116.469 | 0.314x | 1.161x |
| windows / wasm-gc | 64.356 | **64.344** | 82.913 | 1x | 1.289x |
| windows / js | **43.023** | 46.047 | 114.77 | 0.934x | 2.668x |

## 1,048,576 Int32 elements at offset one: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: |
| linux / native | **889.389** | 1103.09 | 1514.227 | 0.806x | 1.703x |
| linux / wasm | 2168.727 | **1459.222** | 3327.8 | 1.486x | 2.281x |
| linux / wasm-gc | **1954.236** | 1955.111 | 2787.253 | 1x | 1.426x |
| linux / js | 3546.381 | **3490.921** | 4633.345 | 1.016x | 1.327x |
| macos / native | 1614.18* | **625.147*** | 1873.798 | 2.582x* | 2.997x* |
| macos / wasm | 2957.831* | **1299.992*** | 2952.131* | 2.275x* | 2.271x* |
| macos / wasm-gc | 1783.894 | **1781.768** | 2177.05 | 1.001x | 1.222x |
| macos / js | 3854.941 | **2310.108** | 3905.226 | 1.669x | 1.69x |
| windows / native | **865.944** | 1231.298 | 1159.574 | 0.703x | 1.339x |
| windows / wasm | 2341.248* | **1327.521** | 2770.358* | 1.764x* | 2.087x* |
| windows / wasm-gc | **1680.261** | 1750.152* | 2527.794* | 0.96x* | 1.504x* |
| windows / js | 3493.405 | **2887.341** | 3803.905 | 1.21x | 1.317x |

## Dense validity bitmap, 4096 Double elements: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: |
| linux / native | **8.922** | 11.997 | 11.616 | 0.744x | 1.302x |
| linux / wasm | 18.656 | **16.286** | 22.731 | 1.146x | 1.396x |
| linux / wasm-gc | **18.6** | 18.608 | 20.005 | 1x | 1.076x |
| linux / js | 22.603 | 22.547 | **21.844** | 1.003x | 0.969x |
| macos / native | **7.253*** | 8.863* | 21.463* | 0.818x* | 2.959x* |
| macos / wasm | 16.79* | **14.811*** | 19.463* | 1.134x* | 1.314x* |
| macos / wasm-gc | **10.139** | 10.41 | 11.28 | 0.974x | 1.113x |
| macos / js | 15.739 | 15.541 | **15.3** | 1.013x | 0.984x |
| windows / native | **8.098** | 11.685 | 9.149 | 0.693x | 1.13x |
| windows / wasm | **13.733** | 13.942 | 16.22 | 0.985x | 1.181x |
| windows / wasm-gc | **13.631** | 13.68 | 14.696 | 0.996x | 1.078x |
| windows / js | 18.284 | 18.483 | **15.92** | 0.989x | 0.871x |

## Last NaN propagation, 4096 Double elements: latency (us)

| OS / backend | ours scalar | ours SIMD request | linear reference | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: |
| linux / native | **6.834** | 6.964 | 8.116 | 0.981x | 1.187x |
| linux / wasm | 12.396 | **12.154** | 13.774 | 1.02x | 1.133x |
| linux / wasm-gc | **11.873** | 12.011 | 13.078 | 0.989x | 1.101x |
| linux / js | **7.929** | 7.958 | 12.335 | 0.996x | 1.556x |
| macos / native | 18.381 | **4.805*** | 19.088* | 3.826x* | 3.973x* |
| macos / wasm | **10.575*** | 14.273* | 12.27* | 0.741x* | 1.16x* |
| macos / wasm-gc | **7.025** | 7.266 | 8.611 | 0.967x | 1.226x |
| macos / js | **5.706** | 6.413* | 10.678 | 0.89x* | 1.871x |
| windows / native | **4.642** | 6.865 | 6.887 | 0.676x | 1.484x |
| windows / wasm | **9.181** | 12.093 | 9.186 | 0.759x | 1.001x |
| windows / wasm-gc | 7.603 | **7.599** | 9.178 | 1.001x | 1.208x |
| windows / js | 4.611 | **4.6** | 9.123 | 1.002x | 1.983x |

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
