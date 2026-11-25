# CRC32 performance comparison

[CI run 45514958793](https://github.com/justjavac/moonbit-simd/actions/runs/45514958793) | [source 10197eb](https://github.com/justjavac/moonbit-simd/commit/10197eb25a16de559b15875df601ee0ddbefca36) | attempt 1

**Scope:** 3 operating systems x 4 backends x 207 cases = **2484 measurements**. Key comparisons are below; [BENCHMARK-DATA.json](BENCHMARK-DATA.json) preserves every case, mean, median, range, standard deviation, quartile, sample count, command, timestamp, and environment.

**Speedups:** `SIMD speedup` = scalar mean / SIMD-request mean; `Best ours vs ref` = fastest reference mean / fastest shown `ours` mean. Ratios use unrounded latencies within each OS/backend: above 1 is faster, below 1 is slower. `*` marks CV >= 5% in either measurement. The best measured path can differ from automatic dispatch; a SIMD request can use scalar fallback.

## At a glance

Native, 1 MiB owned input; ratios compare throughput:

- **linux:** scalar 2.064 GiB/s, **0.991x** the fastest external library (gaato); SIMD **1.788x** scalar.
- **macos:** scalar 1.563 GiB/s, **0.959x** the fastest external library (gaato); SIMD **1.729x** scalar.
- **windows:** scalar 1.929 GiB/s, **1.008x** the fastest external library (gaato); SIMD **1.116x** scalar.

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
| linux | AMD EPYC 9V45 96-Core Processor | x86_64 / 4 | ubuntu26 / 20261116.202.1 | v24.22.3 |
| macos | Apple M1 (Virtual) | arm64 / 3 | macos26 / 20261117.0516.1 | v24.22.3 |
| windows | AMD EPYC 9V74 80-Core Processor                 | AMD64 / 4 | win25-vs2026 / 20261116.315.1 | v24.22.3 |

## 1 MiB owned input: throughput (GiB/s)

| OS / backend | ours scalar | ours SIMD request | gaato | gmlewis | kujirahand | mooncrypt | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 2.064 | **3.692** | 2.083 | 0.517 | 0.503* | 0.512 | 1.788x | 1.772x |
| linux / wasm | 1.945 | **2.068** | 1.888 | 0.384 | 0.42* | 0.437 | 1.063x | 1.095x |
| linux / wasm-gc | 1.331* | **1.346** | 1.262 | 0.395 | 0.441 | 0.444 | 1.011x* | 1.066x |
| linux / js | 0.812 | **1.59** | 1.383* | 0.28 | 0.465 | 0.465 | 1.958x | 1.149x* |
| macos / native | 1.563* | **2.702*** | 1.629 | 0.244* | 0.351 | 0.309 | 1.729x* | 1.658x* |
| macos / wasm | 1.003* | **1.181*** | 0.639* | 0.146* | 0.189 | 0.183 | 1.178x* | 1.85x* |
| macos / wasm-gc | 0.774* | **0.823*** | 0.782 | 0.141 | 0.253 | 0.234 | 1.064x* | 1.052x* |
| macos / js | 1.074 | **1.134** | 1.06 | 0.12* | 0.241 | 0.241* | 1.056x | 1.069x |
| windows / native | 1.929 | **2.153** | 1.915 | 0.424 | 0.425 | 0.425 | 1.116x | 1.125x |
| windows / wasm | **1.578** | 1.399 | 1.469 | 0.194 | 0.22 | 0.229 | 0.886x | 1.074x |
| windows / wasm-gc | 0.724* | 0.708 | **0.831*** | 0.201 | 0.328 | 0.339 | 0.978x* | 0.871x* |
| windows / js | **1.054** | 1.047 | 0.91 | 0.323 | 0.366 | 0.371 | 0.994x | 1.158x |

## 4 KiB owned input: latency (us)

| OS / backend | ours scalar | ours SIMD request | gaato | gmlewis | kujirahand | mooncrypt | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 1.868 | **1.053** | 1.883 | 7.348 | 7.295 | 7.308 | 1.775x | 1.789x |
| linux / wasm | 1.895 | **1.759** | 1.905 | 9.948 | 9.51 | 8.939 | 1.078x | 1.083x |
| linux / wasm-gc | **2.939** | 2.948 | 3.125* | 9.694 | 8.665 | 8.666 | 0.997x | 1.063x* |
| linux / js | 4.759 | **2.421** | 2.729 | 13.71 | 8.287 | 8.242 | 1.966x | 1.127x |
| macos / native | 2.176 | **1.275** | 2.233 | 15.034 | 11.626* | 13.258* | 1.706x | 1.751x |
| macos / wasm | 4.196* | **3.568*** | 3.571 | 25.347 | 22.728* | 20.632 | 1.176x* | 1.001x* |
| macos / wasm-gc | 4.676 | 4.791 | **4.676** | 24.652 | 14.455 | 16.075 | 0.976x | 1x |
| macos / js | 3.952* | **3.824** | 3.936 | 26.597 | 14.555 | 15.059* | 1.033x* | 1.029x |
| windows / native | 2.008 | **1.75** | 2.003 | 9.024 | 8.995 | 9.037 | 1.147x | 1.144x |
| windows / wasm | **2.453** | 2.689 | 2.604 | 19.753 | 17.344 | 16.485 | 0.912x | 1.062x |
| windows / wasm-gc | 4.843 | 5.094 | **4.269** | 19.342 | 11.456 | 11.202 | 0.951x | 0.881x |
| windows / js | **3.672** | 3.72 | 4.291 | 11.88 | 10.431 | 10.356 | 0.987x | 1.169x |

## 64-byte owned input: latency (ns)

| OS / backend | ours scalar | ours SIMD request | gaato | gmlewis | kujirahand | mooncrypt | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 26.455 | **21.664** | 27.199 | 114.039 | 105.1 | 111.667 | 1.221x | 1.256x |
| linux / wasm | **41.629** | 47.333 | 42.584 | 194.353 | 204.429 | 179.443 | 0.879x | 1.023x |
| linux / wasm-gc | **53.414** | 62.489 | 58.19 | 166.955 | 136.364 | 137.097 | 0.855x | 1.089x |
| linux / js | 89.321* | **54.946** | 62.968 | 246.227 | 126.865 | 139.954 | 1.626x* | 1.146x |
| macos / native | 28.478 | **26.007*** | 44.983* | 200.654* | 151.659* | 156.623* | 1.095x* | 1.73x* |
| macos / wasm | **113.656*** | 124.479* | 116.959* | 559.771* | 555.985* | 671.779* | 0.913x* | 1.029x* |
| macos / wasm-gc | **81.239** | 83.569 | 82.947 | 372.968 | 210.032 | 210.32 | 0.972x | 1.021x |
| macos / js | **66.994** | 72.832* | 86.332 | 261.933* | 212.923* | 258.677 | 0.92x* | 1.289x |
| windows / native | **56.121** | 60.444 | 56.543 | 197.167 | 171.043 | 198.754 | 0.928x | 1.008x |
| windows / wasm | **60.075** | 72.157 | 66.866 | 371.613 | 301.009 | 318.18 | 0.833x | 1.113x |
| windows / wasm-gc | 91.26* | 96.217 | **80.923** | 332.084 | 189.426* | 171.591 | 0.948x* | 0.887x* |
| windows / js | **69.712** | 83.589 | 96.115 | 205.25 | 165.794 | 180.502 | 0.834x | 1.379x |

## 64 KiB stream, 4 KiB chunks: latency (us)

| OS / backend | ours scalar | ours SIMD request | gaato | gmlewis | kujirahand | mooncrypt | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 29.827 | **16.623** | 29.738 | 117.778 | 119.58 | 119.646 | 1.794x | 1.789x |
| linux / wasm | 32.154 | **29.978** | 32.058 | 156.722 | 131.892 | 125.655 | 1.073x | 1.069x |
| linux / wasm-gc | **46.513** | 46.911 | 46.683 | 149.04 | 131.67 | 131.386 | 0.992x | 1.004x |
| linux / js | 39.955 | **39.331** | 45.623 | 176.52 | 161.529 | 133.578 | 1.016x | 1.16x |
| macos / native | 36.776 | **23.213*** | 40.431* | 326.79* | 329.214* | 239.465* | 1.584x* | 1.742x* |
| macos / wasm | 52.281* | **49.723*** | 56.143* | 361.844* | 346.995 | 208.822 | 1.051x* | 1.129x* |
| macos / wasm-gc | 75.889 | **75.115** | 77.982 | 407.856 | 235.518 | 257.839 | 1.01x | 1.038x |
| macos / js | **59.559*** | 63.761* | 61.281 | 302.058 | 282.743* | 254.226 | 0.934x* | 1.029x* |
| windows / native | 31.729 | **27.731** | 31.824 | 143.719 | 143.811 | 143.604 | 1.144x | 1.148x |
| windows / wasm | **38.857** | 42.796 | 40.166 | 314.844 | 155.19 | 144.94 | 0.908x | 1.034x |
| windows / wasm-gc | 78.195 | 78.695 | **68.37** | 281.525 | 171.896 | 178.96 | 0.994x | 0.874x |
| windows / js | 59.001 | **58.921** | 69.318 | 216.966 | 197.356 | 164.158 | 1.001x | 1.176x |

## 1 MiB offset-1 view: end-to-end latency (us)

| OS / backend | ours scalar | ours SIMD request | gaato | gmlewis | kujirahand | mooncrypt | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 501.397 | **277.319** | 485.418 | 1878.608 | 1899.568 | 1873.743 | 1.808x | 1.75x |
| linux / wasm | 510.262 | **472.186** | 518.138 | 2262.713 | 2074.274 | 2005.98 | 1.081x | 1.097x |
| linux / wasm-gc | 648.542 | **635.646** | 694.403 | 2352.643 | 2545.637 | 2125.624 | 1.02x | 1.092x |
| linux / js | 637.55* | **632.007** | 707.272 | 2345.797 | 3039.431 | 2121.877 | 1.009x* | 1.119x |
| macos / native | 619.728* | **401.632*** | 597.927* | 4157.867* | 2936.666* | 3319.803* | 1.543x* | 1.489x* |
| macos / wasm | 902.69* | **723.883*** | 980.669 | 7286.286* | 4005.515* | 3873.369 | 1.247x* | 1.355x* |
| macos / wasm-gc | 988.35 | **965.934** | 1099.113 | 4494.861 | 3868.439 | 3983.724 | 1.023x | 1.138x |
| macos / js | **1110.9*** | 1192.258* | 1474.632* | 5318.585* | 7321.392* | 4894.5 | 0.932x* | 1.327x* |
| windows / native | 506.995 | **450.475** | 506.729 | 2305.978 | 2540.27 | 2297.576 | 1.125x | 1.125x |
| windows / wasm | **620.022** | 701.427 | 640.297 | 2595.742 | 2476.246 | 2311.032 | 0.884x | 1.033x |
| windows / wasm-gc | **939.283** | 942.686 | 1021.353 | 2893.458 | 3252.043 | 2868.671 | 0.996x | 1.087x |
| windows / js | 970.249 | **964.66** | 1074.497 | 3028.905 | 4593.534 | 2634.027 | 1.006x | 1.114x |

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
