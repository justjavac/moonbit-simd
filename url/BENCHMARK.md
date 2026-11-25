# URL performance comparison

[CI run 45393812095](https://github.com/justjavac/moonbit-simd/actions/runs/45393812095) | [source 36e496d](https://github.com/justjavac/moonbit-simd/commit/36e496d84b94058fbe83a9baa67ed6f4c8b2dd17) | attempt 1

**Scope:** 3 operating systems x 4 backends x 144 cases = **1728 measurements**. [BENCHMARK-DATA.json](BENCHMARK-DATA.json) preserves all workloads, input lengths, UTF-16 view offsets, means, medians, ranges, variability, throughput inputs, sample counts, compiler versions, commands, timestamps, and dependency manifests.

**Speedups:** `SIMD speedup` = scalar mean / SIMD-request mean; `Best ours vs ref` = fastest reference mean / fastest shown `ours` mean. Ratios use unrounded latencies within each OS/backend: above 1 is faster, below 1 is slower. `*` marks CV >= 5% in either measurement. The best measured path can differ from automatic dispatch; a SIMD request can use scalar fallback.

## Implementations

| Label | Package / pinned version | API |
| --- | --- | --- |
| ours scalar / SIMD request | justjavac/url / source above | parse(StringView, simd=false/true), href |
| tonyfettes | tonyfettes/url / 0.3.5 | Url::parse(StringView), href |
| moonbitstack | moonbitstack/moonurl / 0.3.1 | Url::decode(syntax=Whatwg), encode |
| connect0459 | connect0459/urllib/url / 0.6.0 | parse(String), parse_with_base, href |

## Method

- All adapters pass identical canonical results before timing; moonurl explicitly uses WHATWG mode. Each library runs in a separate binary on the same runner, sequentially per backend.
- Nine absolute inputs cover short/long ASCII, normalization, Unicode/IDNA, IPv4, IPv6, file URLs, and credentials. Separate cases measure parse only and parse plus canonical serialization. Short/long inputs additionally use UTF-16 view offset 1. Three relative inputs use pre-parsed bases. Form-query cases include decoding and serialization.
- Data construction is outside timing. Required public API adapters are timed, including StringView-to-String for urllib and UTF-8 conversion for moonurl's form decoder. Generic adapter callbacks and bench.keep optimizer barriers are included for every library. Getter allocation and eager/lazy serialization choices therefore affect roundtrip measurements.
- The SIMD request uses checked V128 scans on native/Wasm and scalar fallback on Wasm GC/JS. Its canonical UTF-16 guard stays scalar below 64 code units; general UTF-8 scans use 16-byte blocks. This port does not use Ada's architecture-specific AVX-512 IP kernels or optional simdutf dependency.
- Release mode, 10 batch samples, and 5% winsorization. Calibration targets about 100 ms; fast cases use 100000 iterations per batch. **Bold** marks the smallest measured mean in a row; `*` marks CV >= 5%. Compare within a runner/backend; these are workload-specific hosted measurements.

## Runner context

| OS | CPU | Architecture / logical CPUs | Runner / image | Node.js |
| --- | --- | --- | --- | --- |
| linux | AMD EPYC 9V45 96-Core Processor | x86_64 / 4 | ubuntu-latest / ubuntu26 / 20261116.202.1 | v24.22.3 |
| macos | Apple M1 (Virtual) | arm64 / 3 | macos-latest / macos26 / 20261117.0516.1 | v24.22.3 |
| windows | AMD EPYC 7763 64-Core Processor                 | AMD64 / 4 | windows-latest / win25-vs2026 / 20261116.315.1 | v24.22.3 |

## Short absolute URL: parse latency (ns) (20 UTF-8 bytes)

| OS / backend | ours scalar | ours SIMD request | tonyfettes | moonbitstack | connect0459 | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 160.175 | **158.204** | 1758.129 | 942.449* | 840.724 | 1.012x | 5.314x |
| linux / wasm | 390.83 | **368.473** | 3863.869 | 2459.265 | 2854.262* | 1.061x | 6.674x |
| linux / wasm-gc | 111.807 | **110.723** | 1912.087 | 1045.519 | 1160.041 | 1.01x | 9.443x |
| linux / js | **241.948** | 261.299 | 4311.536 | 2349.987 | 1353.481 | 0.926x | 5.594x |
| macos / native | **261.785** | 269.87* | 2067.013 | 1398.448 | 1580.631* | 0.97x* | 5.342x |
| macos / wasm | **666.028*** | 695.408* | 7265.958* | 3878.244* | 5140.117* | 0.958x* | 5.823x* |
| macos / wasm-gc | **265.103*** | 346.565* | 3079.136* | 1471.989* | 1790.293* | 0.765x* | 5.553x* |
| macos / js | 379.667* | **371.897** | 6539.334 | 3674.835* | 2765.945* | 1.021x* | 7.437x* |
| windows / native | 1064.969* | **782.577** | 5082.706 | 3455.777 | 3507.83 | 1.361x* | 4.416x |
| windows / wasm | 760.751 | **733.884** | 7271.135 | 4396.754 | 5402.669 | 1.037x | 5.991x |
| windows / wasm-gc | 247.957 | **242.861** | 3817.275 | 2021.717 | 2226.009 | 1.021x | 8.325x |
| windows / js | **543.778*** | 559.105 | 8016.459 | 4045.57 | 2559.472 | 0.973x* | 4.707x* |

## ASCII path/query/fragment: parse latency (ns) (60 UTF-8 bytes)

| OS / backend | ours scalar | ours SIMD request | tonyfettes | moonbitstack | connect0459 | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 242.058 | **240.982** | 3847.295 | 2764.343 | 1326.241* | 1.004x | 5.503x* |
| linux / wasm | **504.158** | 523.138 | 10668.302 | 5683.005 | 4311.805* | 0.964x | 8.552x* |
| linux / wasm-gc | **242.615** | 251.777 | 3702.775 | 2323.765* | 1952.727* | 0.964x | 8.049x* |
| linux / js | **476.233** | 501.011 | 7102.552 | 4376.798 | 2652.796 | 0.951x | 5.57x |
| macos / native | 486.517* | **448.784*** | 6651.459* | 3014.239 | 2110.368* | 1.084x* | 4.702x* |
| macos / wasm | **908.708*** | 1049.322* | 17403.507* | 10558.965* | 6927.521* | 0.866x* | 7.623x* |
| macos / wasm-gc | **514.094*** | 712.058* | 8297.539* | 3723.967* | 4341.586* | 0.722x* | 7.244x* |
| macos / js | **802.579** | 853.861* | 14202.025* | 6633.191* | 4332.644* | 0.94x* | 5.398x* |
| windows / native | 980.228 | **969.225** | 14287.902 | 8972.468 | 5239.021* | 1.011x | 5.405x* |
| windows / wasm | **1036.136** | 1052.03* | 20552.765 | 11013.305 | 7943.36 | 0.985x* | 7.666x |
| windows / wasm-gc | 520.733 | **506.305** | 7557.682 | 4245.306 | 3588.271 | 1.028x | 7.087x |
| windows / js | 988.011 | **966.961** | 12602.311 | 7709.893 | 4766.697 | 1.022x | 4.93x |

## Long ASCII URL: parse latency (us) (5399 UTF-8 bytes)

| OS / backend | ours scalar | ours SIMD request | tonyfettes | moonbitstack | connect0459 | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 11.746 | **4.34** | 500.103 | 252.414* | 56.227 | 2.706x | 12.954x |
| linux / wasm | 22.541 | **10.633*** | 714.689* | 478.822 | 173.222 | 2.12x* | 16.292x* |
| linux / wasm-gc | **17.358** | 18.613 | 841.695* | 177.872 | 108.061 | 0.933x | 6.225x |
| linux / js | 34.858* | **33.707** | 491.947 | 271.844 | 146.536 | 1.034x* | 4.347x |
| macos / native | 24.242 | **11.467*** | 382.249 | 308.665 | 100.659* | 2.114x* | 8.778x* |
| macos / wasm | 49.738* | **20.562*** | 1182.501* | 1062.107* | 368.531* | 2.419x* | 17.923x* |
| macos / wasm-gc | 51.181* | **50.956*** | 1335.798* | 267.764* | 158.896* | 1.004x* | 3.118x* |
| macos / js | 75.911* | **66.162** | 685.539 | 489.638* | 272.476* | 1.147x* | 4.118x* |
| windows / native | 22.596 | **11.727** | 1803.146 | 863.168 | 269.032* | 1.927x | 22.942x* |
| windows / wasm | 45.576 | **18.985** | 1359.827 | 910.252 | 313.122 | 2.401x | 16.493x |
| windows / wasm-gc | **39.613** | 40.875 | 1170.996 | 317.296 | 199.742 | 0.969x | 5.042x |
| windows / js | **69.432** | 77.827* | 858.239 | 505.344 | 262.029 | 0.892x* | 3.774x |

## Long ASCII URL: UTF-8-equivalent throughput (GiB/s) (5399 UTF-8 bytes)

| OS / backend | ours scalar | ours SIMD request | tonyfettes | moonbitstack | connect0459 | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 0.428 | **1.158** | 0.01 | 0.02* | 0.089 | 2.706x | 12.954x |
| linux / wasm | 0.223 | **0.473*** | 0.007* | 0.011 | 0.029 | 2.12x* | 16.292x* |
| linux / wasm-gc | **0.29** | 0.27 | 0.006* | 0.028 | 0.047 | 0.933x | 6.225x |
| linux / js | 0.144* | **0.149** | 0.01 | 0.018 | 0.034 | 1.034x* | 4.347x |
| macos / native | 0.207 | **0.438*** | 0.013 | 0.016 | 0.05* | 2.114x* | 8.778x* |
| macos / wasm | 0.101* | **0.245*** | 0.004* | 0.005* | 0.014* | 2.419x* | 17.923x* |
| macos / wasm-gc | 0.098* | **0.099*** | 0.004* | 0.019* | 0.032* | 1.004x* | 3.118x* |
| macos / js | 0.066* | **0.076** | 0.007 | 0.01* | 0.018* | 1.147x* | 4.118x* |
| windows / native | 0.223 | **0.429** | 0.003 | 0.006 | 0.019* | 1.927x | 22.942x* |
| windows / wasm | 0.11 | **0.265** | 0.004 | 0.006 | 0.016 | 2.401x | 16.493x |
| windows / wasm-gc | **0.127** | 0.123 | 0.004 | 0.016 | 0.025 | 0.969x | 5.042x |
| windows / js | **0.072** | 0.065* | 0.006 | 0.01 | 0.019 | 0.892x* | 3.774x |

## Unicode URL with IDNA: parse latency (us) (49 UTF-8 bytes)

| OS / backend | ours scalar | ours SIMD request | tonyfettes | moonbitstack | connect0459 | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 1.923 | 1.834 | 4.255 | 3.541 | **1.392** | 1.048x | 0.759x |
| linux / wasm | 4.745 | 4.575 | 12.013 | 8.563 | **4.521** | 1.037x | 0.988x |
| linux / wasm-gc | 2.141 | 2.269 | 3.814 | 3.544* | **1.812** | 0.944x | 0.846x |
| linux / js | 6.681 | 6.674 | 10.695* | 9.642 | **2.756*** | 1.001x | 0.413x* |
| macos / native | **2.205** | 2.312* | 6.25* | 6.129* | 2.293* | 0.954x* | 1.04x* |
| macos / wasm | **6.75*** | 6.954* | 16.891* | 16.567* | 7.563* | 0.971x* | 1.121x* |
| macos / wasm-gc | 3.652* | 3.627* | 6.354* | 5.274* | **2.558*** | 1.007x* | 0.705x* |
| macos / js | 6.596* | 7.266* | 11.267* | 10.841 | **4.048** | 0.908x* | 0.614x* |
| windows / native | 7.292 | 6.952 | 16.729 | 13.85 | **5.4** | 1.049x | 0.777x |
| windows / wasm | 9.246 | **8.248** | 20.815 | 17.968 | 8.271 | 1.121x | 1.003x |
| windows / wasm-gc | 4.102 | 4.226 | 7.202 | 6.46 | **3.393** | 0.97x | 0.827x |
| windows / js | 10.306 | 10.217 | 15.142* | 15.294 | **4.696** | 1.009x | 0.46x |

## Normalization and serialization: latency (us) (36 UTF-8 bytes)

| OS / backend | ours scalar | ours SIMD request | tonyfettes | moonbitstack | connect0459 | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 1.03 | **0.995** | 2.696 | 1.735 | 1.413* | 1.036x | 1.42x* |
| linux / wasm | 2.763 | **2.658*** | 6.098* | 4.552 | 3.964 | 1.04x* | 1.491x* |
| linux / wasm-gc | **1.016** | 1.093 | 3.036 | 1.859 | 1.869 | 0.93x | 1.83x |
| linux / js | 7.332 | 7.334 | 7.037 | 3.634* | **2.197** | 1x | 0.3x |
| macos / native | 1.435* | **1.43** | 3.62* | 3.021* | 2.156* | 1.004x* | 1.508x* |
| macos / wasm | 4.698* | **4.443** | 10.542* | 8.731* | 7.248* | 1.057x* | 1.631x* |
| macos / wasm-gc | **1.22** | 1.616* | 4.995 | 2.525* | 3.266* | 0.755x* | 2.069x* |
| macos / js | 5.861* | 5.388* | 8.71 | 5.061* | **3.404*** | 1.088x* | 0.632x* |
| windows / native | 4.202 | **4.086** | 8.436 | 7.17 | 5.162 | 1.028x | 1.263x |
| windows / wasm | 5.299 | **4.746** | 11.836 | 8.844 | 7.528 | 1.116x | 1.586x |
| windows / wasm-gc | **1.789** | 1.876 | 5.785 | 3.418 | 3.51 | 0.954x | 1.91x |
| windows / js | 8.522 | 8.63 | 11.573 | 5.864 | **4.026** | 0.987x | 0.472x |

## Relative path resolution and serialization: latency (us) (15 UTF-8 bytes)

| OS / backend | ours scalar | ours SIMD request | tonyfettes | moonbitstack | connect0459 | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 0.747 | 0.758 | 0.81 | 2.865 | **0.513** | 0.986x | 0.686x |
| linux / wasm | 2.28 | 2.298 | 2.757 | 8.015* | **1.526** | 0.992x | 0.669x |
| linux / wasm-gc | 0.876 | 0.89 | 0.977* | 2.631 | **0.434** | 0.985x | 0.496x |
| linux / js | 3.323 | 3.288 | 1.418 | 4.727 | **0.493** | 1.011x | 0.15x |
| macos / native | 1.224* | 1.048* | 1.377* | 4.113 | **0.881*** | 1.168x* | 0.84x* |
| macos / wasm | 3.474* | 3.678* | 4.826* | 17.143* | **3.111*** | 0.945x* | 0.896x* |
| macos / wasm-gc | 1.019 | 1.202 | 1.835* | 4.45 | **0.955*** | 0.847x | 0.937x* |
| macos / js | 3.931* | 2.816 | 1.777 | 6.258* | **0.975*** | 1.396x* | 0.346x* |
| windows / native | 3.196 | 2.818 | 3.983 | 13.209 | **2.396** | 1.134x | 0.85x |
| windows / wasm | 4.068 | 4.11 | 4.983 | 15.752 | **2.847** | 0.99x | 0.7x |
| windows / wasm-gc | 1.56 | 1.559 | 1.948 | 5.269 | **0.962** | 1x | 0.617x |
| windows / js | 4.171 | 4.219 | 2.533 | 8.478 | **1.155** | 0.989x | 0.277x |

## Long offset-1 view and serialization: latency (us) (5399 UTF-8 bytes)

| OS / backend | ours scalar | ours SIMD request | tonyfettes | moonbitstack | connect0459 | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 11.762 | **4.364** | 500.069 | 178.346 | 62.131* | 2.696x | 14.238x* |
| linux / wasm | 26.886 | **19.335** | 669.209 | 476.065 | 177.783 | 1.391x | 9.195x |
| linux / wasm-gc | **26.018*** | 27.93 | 774.24 | 182.119 | 121.077 | 0.932x* | 4.653x* |
| linux / js | **29.929** | 30.707* | 543.091* | 258.042 | 148.036 | 0.975x* | 4.946x |
| macos / native | 27.817* | **12.775** | 431.316 | 272.39 | 129.841* | 2.177x* | 10.164x* |
| macos / wasm | 60.037 | **36.924*** | 1392.705* | 879.628* | 319.636* | 1.626x* | 8.657x* |
| macos / wasm-gc | 67.005 | **62.756*** | 1480.58 | 306.145* | 195.179* | 1.068x* | 3.11x* |
| macos / js | 62.581* | **55.527*** | 670.16* | 439.406* | 324.331* | 1.127x* | 5.841x* |
| windows / native | 22.922 | **11.837** | 1175.28 | 868.16 | 215.947 | 1.936x | 18.243x |
| windows / wasm | 56.821 | **28.304** | 1364.276 | 963.225 | 326.237 | 2.008x | 11.526x |
| windows / wasm-gc | **50.83** | 52.332 | 1194.847 | 323.235 | 218.065 | 0.971x | 4.29x |
| windows / js | 57.863 | **57.651** | 851.855 | 492.116 | 270.397 | 1.004x | 4.69x |

## Decoded form query and serialization: latency (us) (77 UTF-8 bytes)

| OS / backend | justjavac | tonyfettes | moonbitstack | connect0459 | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: |
| linux / native | 1.882 | 2.413 | **1.234** | 2.667 | 0.656x |
| linux / wasm | 5.122 | 6.48 | **2.998** | 8.782 | 0.585x |
| linux / wasm-gc | 1.85 | 2.041* | **1.14** | 1.997 | 0.616x |
| linux / js | 26.781* | 20.279 | 14.21 | **2.556** | 0.095x* |
| macos / native | 3.346* | 4.96* | **2.171** | 5.777* | 0.649x* |
| macos / wasm | 11.167* | 12.563 | **5.849*** | 17.681* | 0.524x* |
| macos / wasm-gc | 2.633* | 3.576* | **2.302*** | 3.252 | 0.874x* |
| macos / js | 15.975 | 14.124 | 10.238* | **6.095*** | 0.382x* |
| windows / native | 9.895 | 12.091 | **5.791*** | 14.489 | 0.585x* |
| windows / wasm | 9.915 | 12.464 | **6.13** | 16.508 | 0.618x |
| windows / wasm-gc | 3.545 | 3.993 | **2.412** | 4.258 | 0.68x |
| windows / js | 24.211 | 19.847 | 15.621 | **4.878** | 0.201x |

<details>
<summary>Toolchain, commands, and reproduction</summary>

**linux:**

~~~text
moon 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moon
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) ~/.moon/bin/moonc
moonrun 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moonrun
~~~

native: 2026-11-24T12:40:14Z to 2026-11-24T12:44:17Z (UTC).

~~~text
moon -C benchmarks bench --target native --release --no-parallelize -p justjavac/benchmarks/url/own -p justjavac/benchmarks/url/tonyfettes -p justjavac/benchmarks/url/moonbitstack -p justjavac/benchmarks/url/connect0459
~~~

wasm: 2026-11-24T12:44:17Z to 2026-11-24T12:47:20Z (UTC).

~~~text
moon -C benchmarks bench --target wasm --release --no-parallelize -p justjavac/benchmarks/url/own -p justjavac/benchmarks/url/tonyfettes -p justjavac/benchmarks/url/moonbitstack -p justjavac/benchmarks/url/connect0459
~~~

wasm-gc: 2026-11-24T12:47:20Z to 2026-11-24T12:50:11Z (UTC).

~~~text
moon -C benchmarks bench --target wasm-gc --release --no-parallelize -p justjavac/benchmarks/url/own -p justjavac/benchmarks/url/tonyfettes -p justjavac/benchmarks/url/moonbitstack -p justjavac/benchmarks/url/connect0459
~~~

js: 2026-11-24T12:50:11Z to 2026-11-24T12:53:09Z (UTC).

~~~text
moon -C benchmarks bench --target js --release --no-parallelize -p justjavac/benchmarks/url/own -p justjavac/benchmarks/url/tonyfettes -p justjavac/benchmarks/url/moonbitstack -p justjavac/benchmarks/url/connect0459
~~~

**macos:**

~~~text
moon 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moon
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) ~/.moon/bin/moonc
moonrun 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moonrun
~~~

native: 2026-11-24T12:41:57Z to 2026-11-24T12:46:31Z (UTC).

~~~text
moon -C benchmarks bench --target native --release --no-parallelize -p justjavac/benchmarks/url/own -p justjavac/benchmarks/url/tonyfettes -p justjavac/benchmarks/url/moonbitstack -p justjavac/benchmarks/url/connect0459
~~~

wasm: 2026-11-24T12:46:31Z to 2026-11-24T12:49:41Z (UTC).

~~~text
moon -C benchmarks bench --target wasm --release --no-parallelize -p justjavac/benchmarks/url/own -p justjavac/benchmarks/url/tonyfettes -p justjavac/benchmarks/url/moonbitstack -p justjavac/benchmarks/url/connect0459
~~~

wasm-gc: 2026-11-24T12:49:41Z to 2026-11-24T12:52:43Z (UTC).

~~~text
moon -C benchmarks bench --target wasm-gc --release --no-parallelize -p justjavac/benchmarks/url/own -p justjavac/benchmarks/url/tonyfettes -p justjavac/benchmarks/url/moonbitstack -p justjavac/benchmarks/url/connect0459
~~~

js: 2026-11-24T12:52:43Z to 2026-11-24T12:55:48Z (UTC).

~~~text
moon -C benchmarks bench --target js --release --no-parallelize -p justjavac/benchmarks/url/own -p justjavac/benchmarks/url/tonyfettes -p justjavac/benchmarks/url/moonbitstack -p justjavac/benchmarks/url/connect0459
~~~

**windows:**

~~~text
moon 0.1.20261120 (aaf8010 2026-11-20) ~\.moon\bin\moon.exe
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) ~\.moon\bin\moonc.exe
moonrun 0.1.20261120 (aaf8010 2026-11-20) ~\.moon\bin\moonrun.exe
~~~

native: 2026-11-24T12:41:52Z to 2026-11-24T12:45:13Z (UTC).

~~~text
moon -C benchmarks bench --target native --release --no-parallelize -p justjavac/benchmarks/url/own -p justjavac/benchmarks/url/tonyfettes -p justjavac/benchmarks/url/moonbitstack -p justjavac/benchmarks/url/connect0459
~~~

wasm: 2026-11-24T12:45:13Z to 2026-11-24T12:48:23Z (UTC).

~~~text
moon -C benchmarks bench --target wasm --release --no-parallelize -p justjavac/benchmarks/url/own -p justjavac/benchmarks/url/tonyfettes -p justjavac/benchmarks/url/moonbitstack -p justjavac/benchmarks/url/connect0459
~~~

wasm-gc: 2026-11-24T12:48:23Z to 2026-11-24T12:51:24Z (UTC).

~~~text
moon -C benchmarks bench --target wasm-gc --release --no-parallelize -p justjavac/benchmarks/url/own -p justjavac/benchmarks/url/tonyfettes -p justjavac/benchmarks/url/moonbitstack -p justjavac/benchmarks/url/connect0459
~~~

js: 2026-11-24T12:51:24Z to 2026-11-24T12:54:30Z (UTC).

~~~text
moon -C benchmarks bench --target js --release --no-parallelize -p justjavac/benchmarks/url/own -p justjavac/benchmarks/url/tonyfettes -p justjavac/benchmarks/url/moonbitstack -p justjavac/benchmarks/url/connect0459
~~~

Run `moon -C benchmarks test --target all`, then `moon run scripts/benchmark.mbtx url` for local measurements. CI uses the same release commands sequentially. The report generator rejects local data, incomplete case sets, mixed revisions/runs/attempts, and changed dependency versions. Raw logs are retained for 90 days; the committed JSON preserves the complete snapshot.

</details>
