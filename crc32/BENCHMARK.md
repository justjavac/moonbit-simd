# CRC32 performance comparison

[CI run 45386955613](https://github.com/justjavac/moonbit-simd/actions/runs/45386955613) | [source 5e561dd](https://github.com/justjavac/moonbit-simd/commit/5e561dd5680ca9eaf2550581fc8308b51b4c1330) | attempt 1

**Scope:** 3 operating systems x 4 backends x 207 cases = **2484 measurements**. Key comparisons are below; [BENCHMARK-DATA.json](BENCHMARK-DATA.json) preserves every case, mean, median, range, standard deviation, quartile, sample count, command, timestamp, and environment.

## At a glance

Native, 1 MiB owned input; ratios compare throughput:

- **linux:** scalar 1.401 GiB/s, **0.946x** the fastest external library (gaato); SIMD **0.488x** scalar.
- **macos:** scalar 1.514 GiB/s, **1.034x** the fastest external library (gaato); SIMD **0.442x** scalar.
- **windows:** scalar 1.914 GiB/s, **0.994x** the fastest external library (gaato); SIMD **0.398x** scalar.

Ratios below 1 mean lower throughput. Hosted measurements are workload-specific; consult variation marks in the tables.

## Implementations

| Label | Package / pinned version | Public API measured |
| --- | --- | --- |
| ours scalar | justjavac/crc32 / source above | hash and Hasher, simd=false |
| ours SIMD request | justjavac/crc32 / source above | hash and Hasher, simd=true |
| gaato | gaato/crc / 0.1.1 | crc32_update(0, data) |
| gmlewis | gmlewis/crc32 / 0.9.3 | Digest::new, write(Byte), digest |
| kujirahand | kujirahand/crc32 / 0.1.1 | checksum(Bytes), CRC32Stream |
| mooncrypt | moonbitstack/mooncrypt/sum/crc32 / 0.5.2 | crc32(data, kind=Ieee), Crc32 |

## Reading the results

- All libraries pass identical IEEE CRC-32 vectors and an independent bitwise oracle.
- Owned inputs and stream chunks are prepared before timing; state creation, public API calls, byte-wise adapter loops, and finalization are timed. gmlewis uses a byte-at-a-time API.
- The offset-1 view workload includes input materialization for kujirahand, whose API requires owned Bytes. Other adapters accept views or iterate their bytes.
- The SIMD request uses scalar fallback on Wasm GC/JS and inputs shorter than 16 bytes.
- **Bold** marks the best measured mean in a row; `*` marks CV >= 5% and possible noise. Lower latency and higher GiB/s are better. Compare within an OS/backend; hosted hardware differs.
- Release mode, deterministic binary inputs, 10 batch samples, and 5% winsorization. Calibration targets about 100 ms; fast cases use 100000 iterations per batch. Timings include the bench.keep barrier.

## Runner context

| OS | CPU | Architecture / logical CPUs | Image | Node.js |
| --- | --- | --- | --- | --- |
| linux | AMD EPYC 7763 64-Core Processor | x86_64 / 4 | ubuntu26 / 20261116.202.1 | v24.22.3 |
| macos | Apple M1 (Virtual) | arm64 / 3 | macos26 / 20261117.0516.1 | v24.22.3 |
| windows | AMD EPYC 9V74 80-Core Processor                 | AMD64 / 4 | win25-vs2026 / 20261116.315.1 | v24.22.3 |

## 1 MiB owned input: throughput (GiB/s)

| OS / backend | ours scalar | ours SIMD request | gaato | gmlewis | kujirahand | mooncrypt |
| --- | --- | --- | --- | --- | --- | --- |
| linux / native | 1.401 | 0.684 | **1.482** | 0.374 | 0.374 | 0.374 |
| linux / wasm | 0.255 | 0.532 | **1.337** | 0.239 | 0.188 | 0.213 |
| linux / wasm-gc | 0.677 | 0.673 | **0.779** | 0.248* | 0.288 | 0.32 |
| linux / js | **0.916** | 0.907 | 0.783 | 0.142 | 0.328 | 0.328 |
| macos / native | **1.514*** | 0.669* | 1.464 | 0.218* | 0.296 | 0.276 |
| macos / wasm | 0.355 | 0.437* | **1.03** | 0.147 | 0.171 | 0.082* |
| macos / wasm-gc | 0.781* | 0.793 | **0.795** | 0.128* | 0.215* | 0.221 |
| macos / js | **1.026** | 1.02 | 0.773* | 0.197 | 0.236 | 0.222 |
| windows / native | 1.914 | 0.762 | **1.925** | 0.424 | 0.425 | 0.424 |
| windows / wasm | 0.27 | 0.603 | **1.527** | 0.194 | 0.218 | 0.232 |
| windows / wasm-gc | 0.791 | 0.746 | **0.895** | 0.195 | 0.333 | 0.34 |
| windows / js | 1.03 | **1.033** | 0.911 | 0.167 | 0.366 | 0.371 |

## 4 KiB owned input: latency (us)

| OS / backend | ours scalar | ours SIMD request | gaato | gmlewis | kujirahand | mooncrypt |
| --- | --- | --- | --- | --- | --- | --- |
| linux / native | 2.718 | 5.578 | **2.568** | 10.208 | 10.182 | 10.201 |
| linux / wasm | 14.983 | 7.227 | **2.87** | 16.036 | 20.334 | 18.01 |
| linux / wasm-gc | 5.647 | 5.689 | **4.901** | 14.793 | 13.254 | 11.92 |
| linux / js | **4.179** | 4.229 | 4.898 | 26.89 | 11.7 | 11.775 |
| macos / native | 3.205* | 9.527* | **2.965*** | 17.961* | 11.711* | 13.125* |
| macos / wasm | 13.688* | 9.666 | **3.993** | 27.39* | 22.575 | 24.015 |
| macos / wasm-gc | **4.83*** | 5.868* | 5.262 | 27.032 | 16.047 | 16.765 |
| macos / js | **3.682** | 3.803 | 4.562 | 19.677 | 15.997 | 16.72 |
| windows / native | 2.029 | 5.013 | **2.002** | 9.032 | 8.984 | 9.027 |
| windows / wasm | 14.26 | 6.331 | **2.539** | 19.735 | 17.454 | 16.519 |
| windows / wasm-gc | 4.832 | 5.145 | **4.326** | 19.54 | 11.401 | 11.216 |
| windows / js | 3.72 | **3.713** | 4.226 | 22.585 | 10.433 | 10.317 |

## 64-byte owned input: latency (ns)

| OS / backend | ours scalar | ours SIMD request | gaato | gmlewis | kujirahand | mooncrypt |
| --- | --- | --- | --- | --- | --- | --- |
| linux / native | 46.641 | 94.815 | **43.049** | 172.771 | 151.169 | 174.546 |
| linux / wasm | 267.431 | 148.861 | **73.064** | 327.199 | 355.022 | 356.494 |
| linux / wasm-gc | 100.392 | 107.258 | **95.284** | 268.531 | 211.348 | 200.378 |
| linux / js | **85.631** | 86.234 | 97.966 | 312.585 | 190.357 | 198.975 |
| macos / native | 35.829* | 79.022* | **29.039*** | 216.091* | 188.593* | 198.592* |
| macos / wasm | 226.33* | 159.454* | **77.62*** | 490.027* | 389.368 | 415.121* |
| macos / wasm-gc | **82.983*** | 104.853* | 107.314* | 385.707 | 218.777 | 218.613 |
| macos / js | **84.579*** | 115.065* | 102.12* | 306.425* | 224.697 | 275.454 |
| windows / native | 64.273 | 114.581 | **56.917** | 197.041 | 162.952 | 199.31 |
| windows / wasm | 252.169 | 126.113 | **63.004** | 353.701 | 303.721 | 318.949 |
| windows / wasm-gc | 85.003 | 96.263 | **80.599** | 333.289 | 180.94 | 169.182 |
| windows / js | 72.605 | **72.148** | 85.956* | 261.066 | 163.829 | 168.718 |

## 64 KiB stream, 4 KiB chunks: latency (us)

| OS / backend | ours scalar | ours SIMD request | gaato | gmlewis | kujirahand | mooncrypt |
| --- | --- | --- | --- | --- | --- | --- |
| linux / native | 43.393 | 91.271 | **41.061** | 163.423 | 163.556 | 163.175 |
| linux / wasm | 243.672 | 109.726 | **45.6** | 238.677 | 175.926 | 167.641 |
| linux / wasm-gc | 90.504 | 90.577 | **78.354** | 231.774 | 195.22 | 190.092 |
| linux / js | **66.788** | 66.876 | 79.696 | 247.311 | 224.294 | 186.378 |
| macos / native | 40.094* | 76.427* | **36.748*** | 324.13* | 250.459* | 245.49 |
| macos / wasm | 233.019* | 136.732* | **65.277*** | 399.214* | 432.169* | 272.446 |
| macos / wasm-gc | 91.935* | 82.763 | **77.699*** | 402.653 | 233.102 | 275.444 |
| macos / js | 66.452 | 65.363 | **64.725** | 333.678* | 348.542* | 276.846 |
| windows / native | 32.564 | 81.197 | **32.005** | 143.981 | 143.92 | 143.745 |
| windows / wasm | 240.367 | 106.346* | **43.961*** | 317.389 | 167.477 | 156.634 |
| windows / wasm-gc | 77.865 | 78.136 | **68.113** | 285.94 | 171.432 | 179.088 |
| windows / js | 59.941 | **59.28** | 68.487 | 217.101 | 197.383 | 164.811 |

## 1 MiB offset-1 view: end-to-end latency (us)

| OS / backend | ours scalar | ours SIMD request | gaato | gmlewis | kujirahand | mooncrypt |
| --- | --- | --- | --- | --- | --- | --- |
| linux / native | 697.712 | 1427.929 | **660.159** | 2616.284 | 2678.62 | 2611.685 |
| linux / wasm | 1065.369 | 1839.128 | **730.444** | 3283.062 | 2940.933 | 2665.818 |
| linux / wasm-gc | **1063.061** | 1063.501 | 1177.468 | 3307.414 | 4017.278 | 3047.466 |
| linux / js | 1068.871 | **1068.671** | 1259.778 | 3275.116 | 5226.2 | 2942.431 |
| macos / native | 634.181 | 1520.182 | **620.311*** | 4342.591* | 3246.736* | 3509.517 |
| macos / wasm | **925.474*** | 2145.859 | 985.444* | 7231.448* | 3962.629* | 4409.028* |
| macos / wasm-gc | 1035.482 | **1028.995** | 1120.1 | 4824.581 | 4451.618 | 4485.309 |
| macos / js | 990.598* | **970.927** | 1303.22* | 5151.582* | 6218.187* | 4387.11 |
| windows / native | 511.454 | 1282.008 | **507.561** | 2304.273 | 2574.839 | 2299.243 |
| windows / wasm | 900.85 | 1617.387 | **639.429** | 2595.581 | 2491.816 | 2318.585 |
| windows / wasm-gc | **937.626** | 938.923 | 1022.721 | 2894.054 | 3247.483 | 2867.973 |
| windows / js | 942.126 | **939.199** | 1076.552 | 2903.171 | 4611.641 | 2610.804 |

<details>
<summary>Toolchain and reproduction</summary>

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

Run `moon -C benchmarks test --target all` before local measurements, then `moon run scripts/benchmark.mbtx crc32`. CI measures backends sequentially per OS. Raw artifacts are retained for 90 days; committed JSON preserves the full snapshot. Reports retain their measured source commit.

</details>
