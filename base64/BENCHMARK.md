# Base64 cross-library performance

[CI run 45428865533](https://github.com/justjavac/moonbit-simd/actions/runs/45428865533) | [source bc46449](https://github.com/justjavac/moonbit-simd/commit/bc464495f39b33fa5b668a3012dbc1ffdb027748) | attempt 2

Complete snapshot: **3 operating systems x 4 backends x 200 cases = 2400 measurements**. [BENCHMARK-DATA.json](BENCHMARK-DATA.json) preserves every unrounded statistic, exact input/output length, and runner/toolchain record.

## Key findings

One MiB binary payload, native public allocating APIs; ratios are SIMD-request throughput divided by scalar throughput:

- **linux:** encoding 2.518x; string decoding 6.848x.
- **macos:** encoding 3.683x; string decoding 6.1x.
- **windows:** encoding 0.23x; string decoding 0.056x.

A ratio below one indicates lower SIMD-request throughput. Defaults select scalar on native/Wasm GC/JS and vectors on Wasm; explicit requests are preserved in every comparison. Native lowering of several V128 operations uses core scalar helpers on this toolchain. Revalidate this choice after compiler upgrades.

## Implementations

| Label | Package / version | Public API measured |
| --- | --- | --- |
| ours scalar / SIMD request | justjavac/base64 / source above | encode_to_string, decode_string; explicit simd=false/true |
| core | moonbitlang/core/encoding/base64 / toolchain-bundled | encode(BytesView), decode(StringView) |
| gmlewis | gmlewis/base64 / 0.16.15 | std/url_encode2str(FixedArray), std/url_decode2bytes(String) |
| kujirahand | kujirahand/base64 / 0.1.1 | encode_bytes(Bytes), decode_bytes(String) |
| moonbase | moonbitstack/moonbase/base64 / 0.5.1 | encode(BytesView), decode(StringView)/decode_bytes(BytesView), strict=true |

## Method and limits

- Corpus construction and independent per-bit reference encoding are outside timed callbacks. All public adapters pass identical encoded strings and decoded bytes for every measured variant before timing. This establishes corpus agreement, including binary data, rather than full conformance of permissive competitors.
- Standard padded encoding/decoding uses binary sizes 0, 1, 2, 3, 16, 64, 4096, and 1048576 bytes. Standard unpadded and both URL-safe policies use 2 and 4096 bytes. Kujirahand supplies only a padded standard binary encoder, so it participates only in that policy; its quadratic string-concatenation encoder is limited to 4096-byte inputs. Its linear decoder retains the large cases. Tonyfettes 0.1.0 is excluded because its legacy module metadata cannot be installed by the recorded toolchain.
- Common encoding allocates a String; common decoding accepts StringView and allocates Bytes. Gmlewis requires BytesView-to-FixedArray conversion on encoding and StringView-to-String on decoding, both timed. Kujirahand's required owned Bytes/String conversion is timed. Full views can reuse their original owned value; offset-1 views require materialization where the API needs ownership. Moonbase decoding explicitly selects strict=true and the matching padding policy.
- Our StringView decoder reads UTF-16 directly; it does not first allocate UTF-8. Our allocating encoder builds ASCII bytes then converts them to String. Byte-input decoding is reported separately. Buffer-reuse cases prepare destination arrays outside the timer; in-place decoding includes an encoded-input copy inside each invocation so every call receives Base64 input. Validation cases allocate no output. All calls retain bench.keep barriers.
- Case names use workload:implementation:binary_payload_bytes:view_offset. Decoder throughput uses the actual encoded ASCII input length, including padding; each JSON summary records input_bytes, input_code_units, output_bytes, input_offset, and offset_unit. ASCII wire bytes and UTF-16 code-unit counts are distinguished; UTF-16 backing storage uses two bytes per code unit. Empty-input throughput is n/a.
- The port adapts base64-simd/vsimd 0.8.0's scalar, ALSW lookup, and portable vector bit transforms to V128. Native and Wasm explicit requests process bounded 16-byte loads; other backends fall back to scalar. Encoding consumes twelve source bytes per vector, decoding writes exactly twelve output bytes per sixteen characters, and remainders stay scalar. Rust runtime CPU dispatch and AVX2/NEON-specific 256-bit kernels are outside this portable port.
- Release mode and sequential backends on each runner. Core calibrates near 100 ms, takes 10 batch samples, and applies 5% winsorization; fast cases use 100000 iterations per batch. Bold marks the lowest observed mean in a row, and * marks CV >= 5% as possible noise. These hosted means describe the recorded workloads; variation must inform significance claims.

## Encode 64 bytes to String (ns)

| OS / backend | ours scalar | ours SIMD request | core | gmlewis | kujirahand | moonbase |
| --- | --- | --- | --- | --- | --- | --- |
| linux / native | 205.681 | 175.734 | **71.556** | 729.76 | 5437.287 | 376.037 |
| linux / wasm | 633.256 | 379.461 | **249.368** | 2794.375 | 15402.741 | 1359.622 |
| linux / wasm-gc | **423.058** | 423.229 | 523.634 | 1479 | 3729.969 | 708.04 |
| linux / js | 2560.196* | 2310.078* | 731.476 | 7890.041 | **599.139** | 925.65 |
| macos / native | 154.562 | 113.862 | **60.644*** | 694.457* | 5290.7* | 473.428* |
| macos / wasm | 507.333* | 288.491* | **217.138*** | 2250.185* | 15656.463* | 1171.458* |
| macos / wasm-gc | **359.572** | 398.736* | 364.897 | 1226.245 | 2883.854 | 569.846 |
| macos / js | 948.842* | 966.041* | 720.815 | 4415.036 | **490.308** | 734.765 |
| windows / native | **608.383** | 1683.105 | 1324.567 | 1764.584 | 16305.846 | 707.536 |
| windows / wasm | 632.185 | 408.369* | **303.177*** | 3239.718* | 16337.006* | 1527.718 |
| windows / wasm-gc | **447.517** | 455.049 | 533.833 | 1596.403 | 4632.996 | 782.293 |
| windows / js | 1871.441* | 1565.174 | 737.796 | 6221.089 | **600.669** | 930.821 |

## Decode 88 ASCII characters to 64 bytes (ns)

| OS / backend | ours scalar | ours SIMD request | core | gmlewis | kujirahand | moonbase |
| --- | --- | --- | --- | --- | --- | --- |
| linux / native | 255.306 | **118.88** | 142.957 | 1152.972 | 199.249 | 218.187 |
| linux / wasm | 1050.839 | **305.271** | 425.683 | 3965.053 | 1548.594 | 633.069 |
| linux / wasm-gc | 494.607 | 499.435 | 654.762 | 1806.903 | 613.83 | **309.66** |
| linux / js | 715.603 | **697.228** | 1450.363 | 5924.416 | 1384.696 | 1262.182 |
| macos / native | 196.281* | **73.764** | 108.362* | 995.021* | 178.402* | 158.849* |
| macos / wasm | 821.584* | **216.355*** | 318.298 | 2962.872 | 936.451 | 514.084* |
| macos / wasm-gc | 344.932 | 348.461 | 487.625 | 1537.453* | 360.292* | **272.173** |
| macos / js | 617.474* | **581.171** | 815.208 | 3798.304 | 1213.331* | 727.453 |
| windows / native | 428.156 | 2854.164 | 1440.765 | 3257.778 | 480.811* | **311.389** |
| windows / wasm | 1671.012* | **327.104*** | 436.668 | 4097.203 | 1616.207 | 703.518 |
| windows / wasm-gc | 515.147 | 519.062 | 681.179 | 1906.412 | 635.236 | **343.056** |
| windows / js | **724.084** | 727.023 | 1247.058 | 4913.616 | 1321.319 | 1118.846* |

## Encode 1 MiB to String (GiB/s of binary input)

| OS / backend | ours scalar | ours SIMD request | core | gmlewis | moonbase |
| --- | --- | --- | --- | --- | --- |
| linux / native | 0.602 | 1.516 | **1.696** | 0.122 | 0.241 |
| linux / wasm | 0.142 | 0.814 | 1.171 | 0.027 | **1.913** |
| linux / wasm-gc | 0.118* | **0.121** | 0.104 | 0.034 | 0.066 |
| linux / js | 0.092* | **0.121** | 0.013* | 0.009* | 0.014* |
| macos / native | 0.619* | 2.279* | **3.032*** | 0.163 | 0.198* |
| macos / wasm | 0.188* | 0.967* | 1.342* | 0.034* | **2.284*** |
| macos / wasm-gc | 0.161* | 0.187* | **0.194*** | 0.054* | 0.102* |
| macos / js | 0.105* | **0.145** | 0.016* | 0.011* | 0.02* |
| windows / native | 0.137 | 0.032 | 0.023 | 0.05 | **0.148** |
| windows / wasm | 0.134 | 0.785* | 1.131 | 0.028 | **1.845** |
| windows / wasm-gc | 0.145 | **0.148** | 0.143 | 0.041 | 0.083 |
| windows / js | 0.085* | **0.109** | 0.013* | 0.008* | 0.014* |

## Decode a 1 MiB payload (GiB/s of 1398104 encoded bytes)

| OS / backend | ours scalar | ours SIMD request | core | gmlewis | kujirahand | moonbase |
| --- | --- | --- | --- | --- | --- | --- |
| linux / native | 0.453 | **3.101** | 1.789* | 0.097 | 0.703 | 0.461 |
| linux / wasm | 0.091 | 1.626 | 1.285 | 0.026 | 0.065 | **1.809** |
| linux / wasm-gc | 0.168 | 0.169 | 0.072 | 0.045 | 0.136 | **0.277** |
| linux / js | **0.139** | 0.137 | 0.059 | 0.025 | 0.089 | 0.135* |
| macos / native | 0.673* | 4.106* | **5.024** | 0.125 | 1.379 | 0.726* |
| macos / wasm | 0.128* | 1.735 | 1.733* | 0.03* | 0.111* | **2.159*** |
| macos / wasm-gc | 0.266* | 0.27 | 0.085 | 0.061* | 0.327* | **0.37*** |
| macos / js | **0.162*** | 0.161* | 0.073* | 0.027* | 0.097* | 0.157* |
| windows / native | 0.333 | 0.019 | 0.068 | 0.032 | 0.4 | **0.49** |
| windows / wasm | 0.091 | 1.563 | 1.263 | 0.026 | 0.064 | **1.835** |
| windows / wasm-gc | 0.182 | 0.179 | 0.074 | 0.048 | 0.153 | **0.308** |
| windows / js | **0.13** | 0.129 | 0.057 | 0.025 | 0.085 | 0.121* |

<details>
<summary>Other variants, partial views, buffer APIs, and runner context</summary>

## URL-safe unpadded encoding, 4 KiB (microseconds)

| OS / backend | ours scalar | ours SIMD request | core | gmlewis | moonbase |
| --- | --- | --- | --- | --- | --- |
| linux / native | 6.237 | 2.556 | **1.939** | 28.725 | 15.069 |
| linux / wasm | 26.353 | 4.722 | 3.056 | 127.066 | **3.051** |
| linux / wasm-gc | **21.825** | 21.85 | 27.734 | 79.363 | 37.526 |
| linux / js | **32.371** | 32.467 | 43.715 | 220.088 | 53.277 |
| macos / native | 5.129 | 1.432* | **1.102*** | 26.451* | 17.064* |
| macos / wasm | 21.332* | 4.442* | 2.876* | 98.941* | **2.664*** |
| macos / wasm-gc | 18.646* | 18.421* | **17.589** | 67.343* | 30.311* |
| macos / js | 27.723* | **24.443*** | 54.224 | 179.871 | 42.715 |
| windows / native | 24.775 | 106.397 | 91.206 | 64.517 | **19.471** |
| windows / wasm | 27.937* | 5.277* | 3.688* | 146.698* | **3.273*** |
| windows / wasm-gc | 22.413 | **22.337** | 27.063 | 78.791 | 38.392 |
| windows / js | **32.191*** | 32.843 | 41.167 | 208.339 | 53.583 |

## URL-safe unpadded decoding, 4 KiB (microseconds)

| OS / backend | ours scalar | ours SIMD request | core | gmlewis | moonbase |
| --- | --- | --- | --- | --- | --- |
| linux / native | 11.216 | **1.663** | 55.341 | 51.782 | 10.718 |
| linux / wasm | 55.709 | **3.314** | 110.291 | 195.038 | 4.983 |
| linux / wasm-gc | 26.274 | 26.12 | 37.883 | 99.16 | **14.414** |
| linux / js | 42.791* | 44.022 | 66.642 | 197.337* | **42.354*** |
| macos / native | 5.886* | **1.468*** | 13.468* | 46.107* | 5.578* |
| macos / wasm | 40.546* | **3.501*** | 116.174 | 176.487* | 5.145* |
| macos / wasm-gc | 18.406 | 18.752* | 46.385* | 80.054 | **12.719** |
| macos / js | 36.025* | 33.765* | 62.328 | 138.955 | **33.422*** |
| windows / native | 14.603 | 257.301 | 25.064 | 155.943 | **8.682** |
| windows / wasm | 61.191* | **3.685*** | 121.788* | 212.467* | 5.797* |
| windows / wasm-gc | 26.524 | 26.867 | 40.102 | 101.053 | **14.896** |
| windows / js | **37.742** | 39.842* | 68.095* | 186.979* | 38.868* |

## Encode 1 MiB from view offset 1 (GiB/s)

| OS / backend | ours scalar | ours SIMD request | core | gmlewis | moonbase |
| --- | --- | --- | --- | --- | --- |
| linux / native | 0.588 | 1.505 | **1.692** | 0.124 | 0.243 |
| linux / wasm | 0.285 | 1.16 | 1.328 | 0.046 | **1.935** |
| linux / wasm-gc | 0.118* | 0.122 | **0.177** | 0.037 | 0.084 |
| linux / js | 0.099* | **0.108*** | 0.013* | 0.009* | 0.014* |
| macos / native | 0.695* | 2.767* | **2.829*** | 0.149* | 0.21* |
| macos / wasm | 0.288* | 1.207* | 1.843* | 0.056* | **1.98*** |
| macos / wasm-gc | 0.197* | 0.21 | **0.374** | 0.059* | 0.161 |
| macos / js | **0.14*** | 0.136* | 0.018* | 0.012* | 0.02* |
| windows / native | 0.136 | 0.032 | 0.036 | 0.048 | **0.143** |
| windows / wasm | 0.287 | 1.177 | 1.298 | 0.046 | **1.713** |
| windows / wasm-gc | 0.145 | 0.148 | **0.25** | 0.047 | 0.115 |
| windows / js | **0.09*** | 0.088* | 0.012* | 0.009* | 0.014* |

## Decode 1 MiB from UTF-16 view offset 1 (GiB/s of encoded bytes)

| OS / backend | ours scalar | ours SIMD request | core | gmlewis | kujirahand | moonbase |
| --- | --- | --- | --- | --- | --- | --- |
| linux / native | 0.451 | **3.098** | 1.829 | 0.096 | 0.659 | 0.463 |
| linux / wasm | 0.268 | **2.198** | 1.399 | 0.03 | 0.202 | 1.843 |
| linux / wasm-gc | 0.298 | **0.298** | 0.096 | 0.036 | 0.132 | 0.278 |
| linux / js | **0.119*** | 0.116* | 0.054* | 0.03 | 0.099* | 0.118* |
| macos / native | 0.896* | 3.557* | **4.371*** | 0.104* | 1.066* | 0.823* |
| macos / wasm | 0.279 | 1.674* | 1.937* | 0.031* | 0.189* | **2.004*** |
| macos / wasm-gc | **0.484** | 0.476 | 0.114 | 0.05 | 0.21 | 0.42 |
| macos / js | 0.151* | **0.155*** | 0.072* | 0.036 | 0.118* | 0.152* |
| windows / native | 0.331 | 0.019 | 0.067 | 0.032 | 0.317 | **0.49** |
| windows / wasm | 0.267 | **2.19** | 1.395 | 0.029 | 0.202 | 1.837 |
| windows / wasm-gc | **0.34** | 0.34 | 0.097 | 0.041 | 0.174 | 0.311 |
| windows / js | 0.112* | **0.119*** | 0.053* | 0.028 | 0.093* | 0.11* |

## Decode prepared ASCII bytes, 1 MiB payload (GiB/s)

| OS / backend | ours scalar | ours SIMD request | moonbase |
| --- | --- | --- | --- |
| linux / native | 0.405 | **2.951** | 0.335 |
| linux / wasm | 0.293 | **2.161** | 0.414 |
| linux / wasm-gc | 0.303 | **0.303** | 0.126 |
| linux / js | 0.17* | **0.173** | 0.027* |
| macos / native | 0.931* | **3.885*** | 0.557* |
| macos / wasm | 0.28* | **1.749*** | 0.375* |
| macos / wasm-gc | **0.5*** | 0.492* | 0.19 |
| macos / js | **0.201** | 0.181* | 0.043 |
| windows / native | **0.353** | 0.01 | 0.276 |
| windows / wasm | 0.29 | **2.135** | 0.414 |
| windows / wasm-gc | **0.351** | 0.35 | 0.158 |
| windows / js | **0.162** | 0.161 | 0.032* |

## encode-into-standard, 1 MiB payload (microseconds)

| OS / backend | ours scalar | ours SIMD request |
| --- | --- | --- |
| linux / native | 1395.341 | **446.117** |
| linux / wasm | 3066.611 | **522.349** |
| linux / wasm-gc | 2810.271 | **2809.052** |
| linux / js | **3388.448** | 3789.423 |
| macos / native | 1288.822* | **182.618*** |
| macos / wasm | 2596.374 | **407.528*** |
| macos / wasm-gc | 2112.576 | **2104.006** |
| macos / js | **2283.296** | 2449.509 |
| windows / native | **1793.878** | 25693.016 |
| windows / wasm | 3103.019 | **533.4** |
| windows / wasm-gc | 2823.112 | **2822.759** |
| windows / js | **3467.984** | 3841.553 |

## decode-into-standard, 1 MiB payload (microseconds)

| OS / backend | ours scalar | ours SIMD request |
| --- | --- | --- |
| linux / native | 3178.199 | **416.914** |
| linux / wasm | 4414.326 | **586.623** |
| linux / wasm-gc | 3183.526 | **3165.918** |
| linux / js | 4061.087 | **4054.475** |
| macos / native | 1469.527* | **282.791*** |
| macos / wasm | 3950.917* | **566.76** |
| macos / wasm-gc | 2565.489* | **2359.099** |
| macos / js | **3135.664*** | 3145.559 |
| windows / native | **3431.976** | 69853.388 |
| windows / wasm | 4796.284* | **588.831** |
| windows / wasm-gc | **3176.666** | 3180.938 |
| windows / js | **4121.932** | 4495.426 |

## decode-inplace-standard, 1 MiB payload (microseconds)

| OS / backend | ours scalar | ours SIMD request |
| --- | --- | --- |
| linux / native | 2949.167 | **433.832** |
| linux / wasm | 7607 | **611.398** |
| linux / wasm-gc | 3011.174 | **2980.378** |
| linux / js | 8415.901* | **8170.606*** |
| macos / native | 1417.981* | **307.033*** |
| macos / wasm | 5425.271 | **551.685** |
| macos / wasm-gc | 2138.772* | **2031.388** |
| macos / js | 7422.543* | **7296.531** |
| windows / native | **3787.249** | 123962.506 |
| windows / wasm | 7829.906 | **599.84** |
| windows / wasm-gc | **2642.711** | 2648.2 |
| windows / js | 8574.483* | **8469.896*** |

## check-standard, 1 MiB payload (microseconds)

| OS / backend | ours scalar | ours SIMD request |
| --- | --- | --- |
| linux / native | 3057.512 | **302.5** |
| linux / wasm | 3504.19 | **384.157** |
| linux / wasm-gc | 2510.299 | **2510.073** |
| linux / js | 3733.297 | **3717.523** |
| macos / native | 1146.903* | **161.756*** |
| macos / wasm | 3223.882* | **370.606*** |
| macos / wasm-gc | 1917.354 | **1901.518** |
| macos / js | 3011.395* | **2736.204** |
| windows / native | **3335.702** | 111248.68 |
| windows / wasm | 3547.198 | **388.268** |
| windows / wasm-gc | 2582.238 | **2545.849** |
| windows / js | 3875.98* | **3748.501** |

## Runner context

| OS | Runner | CPU | Architecture | Image |
| --- | --- | --- | --- | --- |
| linux | ubuntu-latest | AMD EPYC 7763 64-Core Processor | x86_64 | ubuntu26 / 20261116.202.1 |
| macos | macos-15 | Apple M1 (Virtual) | arm64 | macos15 / 20261118.0550.1 |
| windows | windows-latest | AMD EPYC 7763 64-Core Processor                 | AMD64 | win25-vs2026 / 20261116.315.1 |

### linux

~~~text
moon 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moon
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) ~/.moon/bin/moonc
moonrun 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moonrun
Node v24.22.3
~~~

- native: 2026-11-24T16:03:19Z to 2026-11-24T16:05:59Z
- wasm: 2026-11-24T16:05:59Z to 2026-11-24T16:09:03Z
- wasm-gc: 2026-11-24T16:09:03Z to 2026-11-24T16:11:45Z
- js: 2026-11-24T16:11:45Z to 2026-11-24T16:15:03Z

~~~text
moon -C benchmarks bench --target native --release --no-parallelize -p justjavac/benchmarks/base64
~~~

### macos

~~~text
moon 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moon
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) ~/.moon/bin/moonc
moonrun 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moonrun
Node v24.22.3
~~~

- native: 2026-11-24T16:03:27Z to 2026-11-24T16:06:01Z
- wasm: 2026-11-24T16:06:01Z to 2026-11-24T16:09:05Z
- wasm-gc: 2026-11-24T16:09:05Z to 2026-11-24T16:11:45Z
- js: 2026-11-24T16:11:45Z to 2026-11-24T16:14:46Z

~~~text
moon -C benchmarks bench --target native --release --no-parallelize -p justjavac/benchmarks/base64
~~~

### windows

~~~text
moon 0.1.20261120 (aaf8010 2026-11-20) ~\.moon\bin\moon.exe
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) ~\.moon\bin\moonc.exe
moonrun 0.1.20261120 (aaf8010 2026-11-20) ~\.moon\bin\moonrun.exe
Node v24.22.3
~~~

- native: 2026-11-24T16:04:02Z to 2026-11-24T16:07:19Z
- wasm: 2026-11-24T16:07:19Z to 2026-11-24T16:10:22Z
- wasm-gc: 2026-11-24T16:10:23Z to 2026-11-24T16:13:06Z
- js: 2026-11-24T16:13:07Z to 2026-11-24T16:16:21Z

~~~text
moon -C benchmarks bench --target native --release --no-parallelize -p justjavac/benchmarks/base64
~~~

Run moon -C benchmarks test --target all, then moon run scripts/benchmark.mbtx base64. Published reports reject local data, incomplete inventories or matrices, mismatched lengths, changed dependencies, and mixed source commits/runs/attempts/toolchains. Raw stdout/stderr logs are retained as CI artifacts for 90 days. The measured source revision remains unchanged when this report is committed later.

</details>
