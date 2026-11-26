# Base64 cross-library performance

[CI run 45803878181](https://github.com/justjavac/moonbit-simd/actions/runs/45803878181) | [source be029e0](https://github.com/justjavac/moonbit-simd/commit/be029e024627b370da14275afcb6fb7b0c008c98) | attempt 1

Complete snapshot: **3 operating systems x 4 backends x 200 cases = 2400 measurements**. [BENCHMARK-DATA.json](BENCHMARK-DATA.json) preserves every unrounded statistic, exact input/output length, and runner/toolchain record.

**Speedups:** `SIMD speedup` = scalar mean / SIMD-request mean; `Best ours vs ref` = fastest reference mean / fastest shown `ours` mean. Ratios use unrounded latencies within each OS/backend: above 1 is faster, below 1 is slower. `*` marks CV >= 5% in either measurement. The best measured path can differ from automatic dispatch; a SIMD request can use scalar fallback.

## Key findings

One MiB binary payload, native public allocating APIs; ratios are SIMD-request throughput divided by scalar throughput:

- **linux:** encoding 1.541x; string decoding 2.319x.
- **macos:** encoding 1.272x; string decoding 2.031x.
- **windows:** encoding 0.135x; string decoding 0.023x.

A ratio below one indicates lower SIMD-request throughput. Defaults select scalar on native/Wasm GC/JS and vectors on Wasm; explicit requests are preserved in every comparison. Native lowering of several V128 operations uses core scalar helpers on this toolchain. Revalidate this choice after compiler upgrades.

The scalar codec uses packed lookup tables adapted from aklomp/base64. Allocating byte APIs return their freshly filled buffers directly. [Algorithm and attribution](README.md#algorithm-and-backend-behavior)

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

| OS / backend | ours scalar | ours SIMD request | core | gmlewis | kujirahand | moonbase | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 86.632 | 74.415 | **35.242** | 400.457 | 2598.803 | 199.805 | 1.164x | 0.474x |
| linux / wasm | 194.283 | **123.511** | 146.861 | 1634.239 | 8530.534 | 741.67 | 1.573x | 1.189x |
| linux / wasm-gc | 206.749 | **198.772** | 272.311 | 901.929* | 1904.398 | 422.519 | 1.04x | 1.37x |
| linux / js | 666.91 | 711.947 | 386.718 | 5002.788 | **328.827** | 538.043 | 0.937x | 0.493x |
| macos / native | 213.939* | 106.422* | **45.854** | 636.407* | 7231.324* | 488.628* | 2.01x* | 0.431x* |
| macos / wasm | 452.261* | **303.924*** | 487.094* | 3025.774* | 22631.027* | 1527.325* | 1.488x* | 1.603x* |
| macos / wasm-gc | **483.498*** | 507.107* | 508.733* | 1826.368* | 4355.963* | 800.7* | 0.953x* | 1.052x* |
| macos / js | 529.714* | **467.015** | 728.086 | 4984.657* | 545.759* | 764.371* | 1.134x* | 1.169x* |
| windows / native | **408.455** | 1217.575 | 931.085 | 1345.653 | 12695.898 | 558.014 | 0.335x | 1.366x |
| windows / wasm | 298.751 | **186.716** | 215.521 | 2159.488 | 12514.747 | 1016.428 | 1.6x | 1.154x |
| windows / wasm-gc | **318.417** | 323.359 | 514.445 | 1234.081 | 3810.948 | 727.801 | 0.985x | 1.616x |
| windows / js | 643.012 | 651.698 | 637.132 | 5093.156 | **500.338** | 780.07 | 0.987x | 0.778x |

## Decode 88 ASCII characters to 64 bytes (ns)

| OS / backend | ours scalar | ours SIMD request | core | gmlewis | kujirahand | moonbase | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 67.028 | **50.19** | 66.74 | 689.91 | 96.622 | 111.899 | 1.335x | 1.33x |
| linux / wasm | 193.937 | **127.785** | 206.542 | 2190.709 | 770.806 | 382.217 | 1.518x | 1.616x |
| linux / wasm-gc | 178.913 | **166.081** | 394.052* | 1045.279 | 253.505 | 166.132 | 1.077x | 1x |
| linux / js | 259.454 | **257.451** | 823.371 | 3555.335 | 673.524 | 804.707 | 1.008x | 2.616x |
| macos / native | 135.246* | **88.213*** | 114.135* | 1089.001* | 172.906* | 143.569* | 1.533x* | 1.294x* |
| macos / wasm | 459.477* | **303.543*** | 501.753* | 4827.737* | 1516.1* | 778.045* | 1.514x* | 1.653x* |
| macos / wasm-gc | **269.379*** | 289.956* | 796.124* | 2301.752* | 562.867* | 359.22* | 0.929x* | 1.334x* |
| macos / js | 496.092* | **465.605** | 820.421 | 3788.083 | 1114.537 | 993.507* | 1.065x* | 1.762x |
| windows / native | **216.53** | 2185.492 | 1117.301 | 2489.505 | 377.56 | 241.819 | 0.099x | 1.117x |
| windows / wasm | 270.727 | **200.704** | 338.818 | 3283.141 | 1226.853 | 520.101 | 1.349x | 1.688x |
| windows / wasm-gc | 257.496 | 252.37 | 734.605 | 1378.478 | 389.045 | **239.743** | 1.02x | 0.95x |
| windows / js | 394.614 | **391.443** | 1013.593 | 4121.182* | 1021.429 | 841.499 | 1.008x | 2.15x |

## Encode 1 MiB to String (GiB/s of binary input)

| OS / backend | ours scalar | ours SIMD request | core | gmlewis | moonbase | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 2.527 | 3.893 | **4** | 0.249 | 0.521 | 1.541x | 0.973x |
| linux / wasm | 0.756 | 2.848 | 2.126 | 0.061 | **3.791** | 3.769x | 0.751x |
| linux / wasm-gc | 0.234 | **0.234** | 0.192 | 0.058 | 0.1* | 1.001x | 1.217x |
| linux / js | 0.373* | **0.65** | 0.023* | 0.016* | 0.021* | 1.745x* | 28.158x* |
| macos / native | 1.767* | 2.248* | **2.922*** | 0.144* | 0.215* | 1.272x* | 0.769x* |
| macos / wasm | 0.403* | 1.107* | 0.91* | 0.032* | **2.016*** | 2.749x* | 0.549x* |
| macos / wasm-gc | **0.142*** | 0.136* | 0.135* | 0.048* | 0.093* | 0.957x* | 1.054x* |
| macos / js | 0.207* | **0.437*** | 0.012* | 0.01* | 0.016* | 2.113x* | 27.472x* |
| windows / native | **0.201** | 0.027 | 0.045 | 0.06 | 0.166* | 0.135x | 1.209x* |
| windows / wasm | 0.484 | 1.637 | 1.395 | 0.036 | **2.369** | 3.38x | 0.691x |
| windows / wasm-gc | **0.203** | 0.201 | 0.168 | 0.051 | 0.094 | 0.995x | 1.203x |
| windows / js | 0.243* | **0.359** | 0.017* | 0.01* | 0.017* | 1.481x* | 20.921x* |

## Decode a 1 MiB payload (GiB/s of 1398104 encoded bytes)

| OS / backend | ours scalar | ours SIMD request | core | gmlewis | kujirahand | moonbase | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 2.18 | **5.055** | 3.872 | 0.166 | 1.6 | 0.914 | 2.319x | 1.305x |
| linux / wasm | 0.919 | 3.125 | 2.536 | 0.05* | 0.184 | **3.231** | 3.399x | 0.967x |
| linux / wasm-gc | 0.602 | **0.605** | 0.099 | 0.077* | 0.36 | 0.505 | 1.005x | 1.197x |
| linux / js | **0.364** | 0.357 | 0.092 | 0.048 | 0.185 | 0.29* | 0.98x | 1.256x* |
| macos / native | 1.612* | 3.274* | **4.623*** | 0.113* | 1.303* | 0.745* | 2.031x* | 0.708x* |
| macos / wasm | 0.497* | 1.062* | 1.37* | 0.029* | 0.095* | **1.553*** | 2.136x* | 0.684x* |
| macos / wasm-gc | **0.429*** | 0.341* | 0.075* | 0.058* | 0.268* | 0.307* | 0.795x* | 1.397x* |
| macos / js | **0.193** | 0.182* | 0.055* | 0.026* | 0.082* | 0.159* | 0.944x* | 1.213x* |
| windows / native | **0.991** | 0.023 | 0.095 | 0.041 | 0.437* | 0.607 | 0.023x | 1.633x |
| windows / wasm | 0.652 | 1.995 | 1.578 | 0.031 | 0.079 | **2.234** | 3.058x | 0.893x |
| windows / wasm-gc | 0.436 | **0.438** | 0.08 | 0.062 | 0.266 | 0.404 | 1.004x | 1.083x |
| windows / js | **0.228** | 0.224* | 0.069 | 0.029 | 0.106 | 0.161* | 0.984x* | 1.411x* |

<details>
<summary>Other variants, partial views, buffer APIs, and runner context</summary>

## URL-safe unpadded encoding, 4 KiB (microseconds)

| OS / backend | ours scalar | ours SIMD request | core | gmlewis | moonbase | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 1.399 | 0.969* | **0.846** | 15.361 | 7.498 | 1.444x* | 0.873x* |
| linux / wasm | 5.552 | **1.423** | 1.773 | 67.315 | 1.667* | 3.902x | 1.171x* |
| linux / wasm-gc | 11.75* | **11.581** | 14.29 | 46.823 | 22.328 | 1.015x* | 1.234x |
| linux / js | **6.411** | 6.563 | 23.218 | 110.015 | 28.853 | 0.977x | 3.622x |
| macos / native | 2.483* | 1.527* | **1.027*** | 27.916* | 23.723* | 1.627x* | 0.673x* |
| macos / wasm | 9.475* | 3.615* | 3.205* | 113.68* | **2.877*** | 2.621x* | 0.796x* |
| macos / wasm-gc | **21.021*** | 27.688* | 26.308* | 124.725* | 43.581* | 0.759x* | 1.252x* |
| macos / js | **7.433** | 8.431* | 43.458 | 209.052* | 43.737* | 0.882x* | 5.847x |
| windows / native | **15.83** | 67.546 | 107.107 | 52.128 | 16.432 | 0.234x | 1.038x |
| windows / wasm | 10.17 | 2.493 | 2.621 | 104.179 | **2.354** | 4.079x | 0.944x |
| windows / wasm-gc | 18.382* | **17.679*** | 28.347 | 64.539 | 36.404 | 1.04x* | 1.603x* |
| windows / js | **9.797** | 9.965 | 35.491 | 169.664 | 44.988 | 0.983x | 3.623x |

## URL-safe unpadded decoding, 4 KiB (microseconds)

| OS / backend | ours scalar | ours SIMD request | core | gmlewis | moonbase | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 2.318 | **1.053** | 40.593 | 30.922 | 5.929* | 2.202x | 5.631x* |
| linux / wasm | 6.534 | **1.788** | 75.393 | 104.783 | 2.796 | 3.655x | 1.564x |
| linux / wasm-gc | **7.332** | 7.396 | 20.131 | 54.208 | 7.429 | 0.991x | 1.013x |
| linux / js | 14.683 | **14.041** | 33.079 | 95.16* | 18.207 | 1.046x | 1.297x |
| macos / native | 3.136* | **1.353*** | 12.726* | 55.705* | 6.648* | 2.317x* | 4.913x* |
| macos / wasm | 13.34* | **3.712*** | 124.987 | 203.043* | 6.196* | 3.594x* | 1.669x* |
| macos / wasm-gc | **13.913*** | 14.863* | 98.688* | 111.802* | 17.592* | 0.936x* | 1.264x* |
| macos / js | **24.183*** | 27.632* | 67.991* | 188.341* | 33.991* | 0.875x* | 1.406x* |
| windows / native | **4.473** | 134.753 | 21.361 | 121.103 | 6.81 | 0.033x | 1.523x |
| windows / wasm | 7.868 | **2.698** | 87.756 | 164.931 | 3.928 | 2.916x | 1.456x |
| windows / wasm-gc | 12.255* | 11.91* | 42.332 | 77.916 | **11.65*** | 1.029x* | 0.978x* |
| windows / js | **21.061** | 21.247 | 50.925 | 138.817 | 29.625 | 0.991x | 1.407x |

## Encode 1 MiB from view offset 1 (GiB/s)

| OS / backend | ours scalar | ours SIMD request | core | gmlewis | moonbase | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 2.662 | **4.098** | 3.951 | 0.246 | 0.501 | 1.539x | 1.037x |
| linux / wasm | 1.245 | 2.936 | 3.176 | 0.088 | **3.75** | 2.358x | 0.783x |
| linux / wasm-gc | 0.271 | 0.268 | **0.283*** | 0.061 | 0.139 | 0.989x | 0.957x* |
| linux / js | **0.347*** | 0.343* | 0.021* | 0.015* | 0.023* | 0.988x* | 14.779x* |
| macos / native | 1.634* | 2.552* | **2.893*** | 0.103* | 0.172* | 1.562x* | 0.882x* |
| macos / wasm | 0.646* | 1.206* | 1.498* | 0.043* | **1.65*** | 1.868x* | 0.731x* |
| macos / wasm-gc | 0.131* | 0.213* | **0.219*** | 0.024* | 0.11* | 1.627x* | 0.974x* |
| macos / js | 0.259* | **0.335*** | 0.01* | 0.011* | 0.014* | 1.295x* | 23.953x* |
| windows / native | **0.2** | 0.04 | 0.046 | 0.061 | 0.164 | 0.2x | 1.22x |
| windows / wasm | 0.896 | 1.63 | 1.647 | 0.06 | **2.261** | 1.818x | 0.721x |
| windows / wasm-gc | 0.227 | 0.229 | **0.297** | 0.053* | 0.131 | 1.007x | 0.771x |
| windows / js | 0.246* | **0.255*** | 0.015* | 0.01* | 0.017* | 1.038x* | 15.225x* |

## Decode 1 MiB from UTF-16 view offset 1 (GiB/s of encoded bytes)

| OS / backend | ours scalar | ours SIMD request | core | gmlewis | kujirahand | moonbase | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 2.275 | **5.103** | 3.853 | 0.162 | 1.541 | 0.913 | 2.243x | 1.324x |
| linux / wasm | 0.921 | **4.113** | 3.055 | 0.052 | 0.375 | 3.28 | 4.467x | 1.254x |
| linux / wasm-gc | **0.87** | 0.86 | 0.132 | 0.06 | 0.197* | 0.499 | 0.989x | 1.743x |
| linux / js | 0.317* | **0.318*** | 0.083* | 0.056 | 0.171* | 0.236* | 1.005x* | 1.349x* |
| macos / native | 1.717* | 3.08* | **3.683*** | 0.08* | 0.866* | 0.62* | 1.794x* | 0.836x* |
| macos / wasm | 0.405* | 1.516* | 1.566* | 0.023* | 0.175* | **1.597*** | 3.742x* | 0.949x* |
| macos / wasm-gc | 0.481* | **0.49*** | 0.071* | 0.035* | 0.157* | 0.301* | 1.019x* | 1.626x* |
| macos / js | 0.169* | **0.176*** | 0.064* | 0.034 | 0.105* | 0.141* | 1.042x* | 1.245x* |
| windows / native | **0.992** | 0.023 | 0.05 | 0.04 | 0.37 | 0.603 | 0.023x | 1.646x |
| windows / wasm | 0.655 | **2.619** | 1.75 | 0.037 | 0.243 | 2.253 | 4.001x | 1.163x |
| windows / wasm-gc | 0.646 | **0.653** | 0.112 | 0.047 | 0.198 | 0.405 | 1.01x | 1.613x |
| windows / js | 0.209* | **0.211*** | 0.063* | 0.036 | 0.113* | 0.147* | 1.009x* | 1.433x* |

## Decode prepared ASCII bytes, 1 MiB payload (GiB/s)

| OS / backend | ours scalar | ours SIMD request | moonbase | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: |
| linux / native | 2.839 | **5.331** | 0.691 | 1.878x | 7.715x |
| linux / wasm | 0.933 | **4.219** | 0.729 | 4.523x | 5.789x |
| linux / wasm-gc | 0.896 | **0.91** | 0.185* | 1.015x | 4.923x* |
| linux / js | 0.556 | **0.566** | 0.061 | 1.018x | 9.346x |
| macos / native | 1.445* | **3.51*** | 0.515* | 2.429x* | 6.809x* |
| macos / wasm | 0.626* | **1.484*** | 0.262* | 2.371x* | 5.666x* |
| macos / wasm-gc | 0.428* | **0.541*** | 0.118* | 1.265x* | 4.59x* |
| macos / js | 0.377* | **0.38*** | 0.027* | 1.007x* | 14.001x* |
| windows / native | **1.16** | 0.023 | 0.333 | 0.02x | 3.486x |
| windows / wasm | 0.706 | **2.629** | 0.494 | 3.724x | 5.317x |
| windows / wasm-gc | **0.689** | 0.688 | 0.194 | 0.999x | 3.553x |
| windows / js | **0.338** | 0.33 | 0.041* | 0.977x | 8.297x* |

## encode-into-standard, 1 MiB payload (microseconds)

| OS / backend | ours scalar | ours SIMD request | SIMD speedup |
| --- | ---: | ---: | ---: |
| linux / native | 255.871 | **130.187** | 1.965x |
| linux / wasm | 619.985 | **191.42** | 3.239x |
| linux / wasm-gc | **905.259** | 908.337 | 0.997x |
| linux / js | 1291.301 | **1248.056** | 1.035x |
| macos / native | 329.288* | **189.367*** | 1.739x* |
| macos / wasm | 1036.408* | **398.075*** | 2.604x* |
| macos / wasm-gc | 1660.387* | **1598.362*** | 1.039x* |
| macos / js | **1629.484** | 1633.172 | 0.998x |
| windows / native | **321.329** | 20072.631 | 0.016x |
| windows / wasm | 862.264 | **368.877** | 2.338x |
| windows / wasm-gc | **1384.834** | 1388.409 | 0.997x |
| windows / js | 2073.604 | **2062.566** | 1.005x |

## decode-into-standard, 1 MiB payload (microseconds)

| OS / backend | ours scalar | ours SIMD request | SIMD speedup |
| --- | ---: | ---: | ---: |
| linux / native | 449.958 | **229.108** | 1.964x |
| linux / wasm | 1373.019 | **302.886** | 4.533x |
| linux / wasm-gc | 1032.48 | **1026.798** | 1.006x |
| linux / js | 2198.429 | **2051.358** | 1.072x |
| macos / native | 760.491* | **358.375*** | 2.122x* |
| macos / wasm | 2991.747* | **958.451*** | 3.121x* |
| macos / wasm-gc | 1773.264 | **1769.487*** | 1.002x* |
| macos / js | **3330.621** | 3675.152* | 0.906x* |
| windows / native | **902.937** | 55880.963 | 0.016x |
| windows / wasm | 1831.077 | **483.77** | 3.785x |
| windows / wasm-gc | **1635.799** | 1638.514 | 0.998x |
| windows / js | 3627.8 | **3318.479** | 1.093x |

## decode-inplace-standard, 1 MiB payload (microseconds)

| OS / backend | ours scalar | ours SIMD request | SIMD speedup |
| --- | ---: | ---: | ---: |
| linux / native | 414.433 | **261.171** | 1.587x |
| linux / wasm | 1190.82 | **309.302** | 3.85x |
| linux / wasm-gc | 1425.048 | **1420.393** | 1.003x |
| linux / js | 4386.094* | **4310.308** | 1.018x* |
| macos / native | 647.957* | **426.769*** | 1.518x* |
| macos / wasm | 2333.15* | **758.487*** | 3.076x* |
| macos / wasm-gc | **2246.275*** | 3546.159* | 0.633x* |
| macos / js | 8150.252* | **7957.227** | 1.024x* |
| windows / native | **1009.076** | 56121.022 | 0.018x |
| windows / wasm | 1715.117 | **479.963** | 3.573x |
| windows / wasm-gc | 1722.387 | **1716.291** | 1.004x |
| windows / js | 7296.302 | **7264.67** | 1.004x |

## check-standard, 1 MiB payload (microseconds)

| OS / backend | ours scalar | ours SIMD request | SIMD speedup |
| --- | ---: | ---: | ---: |
| linux / native | 313.914 | **99.615** | 3.151x |
| linux / wasm | 539.25* | **192.533*** | 2.801x* |
| linux / wasm-gc | 495.935 | **494.413** | 1.003x |
| linux / js | 753.449 | **753.429** | 1x |
| macos / native | 511.045* | **196.241*** | 2.604x* |
| macos / wasm | 1069.63* | **509.114*** | 2.101x* |
| macos / wasm-gc | **1071.728*** | 1200.488* | 0.893x* |
| macos / js | **1187.303*** | 1400.719* | 0.848x* |
| windows / native | **322.602** | 56875.851* | 0.006x* |
| windows / wasm | 751.193 | **302.911** | 2.48x |
| windows / wasm-gc | 736.955 | **729.435** | 1.01x |
| windows / js | 1182.097 | **1176.116** | 1.005x |

## Runner context

| OS | Runner | CPU | Architecture | Image |
| --- | --- | --- | --- | --- |
| linux | ubuntu-latest | AMD EPYC 9V45 96-Core Processor | x86_64 | ubuntu26 / 20261116.202.1 |
| macos | macos-15 | Apple M1 (Virtual) | arm64 | macos15 / 20261118.0550.1 |
| windows | windows-latest | AMD EPYC 9V74 80-Core Processor                 | AMD64 | win25-vs2026 / 20261116.315.1 |

### linux

~~~text
moon 0.1.20261126 (cc21d04 2026-11-26) ~/.moon/bin/moon
moonc v1.0.0-rc1+546870549-nightly (2026-11-25) ~/.moon/bin/moonc
moonrun 0.1.20261126 (cc21d04 2026-11-26) ~/.moon/bin/moonrun
Node v24.22.3
~~~

- native: 2026-11-26T10:43:41Z to 2026-11-26T10:46:08Z
- wasm: 2026-11-26T10:46:08Z to 2026-11-26T10:48:53Z
- wasm-gc: 2026-11-26T10:48:53Z to 2026-11-26T10:51:24Z
- js: 2026-11-26T10:51:24Z to 2026-11-26T10:54:23Z

~~~text
moon -C benchmarks bench --target native --release --no-parallelize -p justjavac/benchmarks/base64
~~~

### macos

~~~text
moon 0.1.20261126 (cc21d04 2026-11-26) ~/.moon/bin/moon
moonc v1.0.0-rc1+546870549-nightly (2026-11-25) ~/.moon/bin/moonc
moonrun 0.1.20261126 (cc21d04 2026-11-26) ~/.moon/bin/moonrun
Node v24.22.3
~~~

- native: 2026-11-26T10:44:09Z to 2026-11-26T10:46:47Z
- wasm: 2026-11-26T10:46:47Z to 2026-11-26T10:49:55Z
- wasm-gc: 2026-11-26T10:49:55Z to 2026-11-26T10:52:39Z
- js: 2026-11-26T10:52:39Z to 2026-11-26T10:55:44Z

~~~text
moon -C benchmarks bench --target native --release --no-parallelize -p justjavac/benchmarks/base64
~~~

### windows

~~~text
moon 0.1.20261126 (cc21d04 2026-11-26) ~\.moon\bin\moon.exe
moonc v1.0.0-rc1+546870549-nightly (2026-11-25) ~\.moon\bin\moonc.exe
moonrun 0.1.20261126 (cc21d04 2026-11-26) ~\.moon\bin\moonrun.exe
Node v24.22.3
~~~

- native: 2026-11-26T10:45:01Z to 2026-11-26T10:48:05Z
- wasm: 2026-11-26T10:48:06Z to 2026-11-26T10:51:02Z
- wasm-gc: 2026-11-26T10:51:02Z to 2026-11-26T10:53:40Z
- js: 2026-11-26T10:53:40Z to 2026-11-26T10:56:40Z

~~~text
moon -C benchmarks bench --target native --release --no-parallelize -p justjavac/benchmarks/base64
~~~

Run moon -C benchmarks test --target all, then moon run scripts/benchmark.mbtx base64. Published reports reject local data, incomplete inventories or matrices, mismatched lengths, changed dependencies, and mixed source commits/runs/attempts/toolchains. Raw stdout/stderr logs are retained as CI artifacts for 90 days. The measured source revision remains unchanged when this report is committed later.

</details>
