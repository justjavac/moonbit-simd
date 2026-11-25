# UTF-8 performance comparison

[CI run 45538333335](https://github.com/justjavac/moonbit-simd/actions/runs/45538333335) | [source 33ab134](https://github.com/justjavac/moonbit-simd/commit/33ab134ea8eb5627e797d16dd97d0ee0c78c0104) | attempt 1

**Scope:** 3 OS x 4 backends x 158 cases = **1896 measurements**. [BENCHMARK-DATA.json](BENCHMARK-DATA.json) preserves every case and unrounded statistic, sample metadata, commands, timestamps, manifests, dependencies, CPU, and toolchain.

**Speedups:** `SIMD speedup` = scalar mean / SIMD-request mean; `Best ours vs ref` = fastest reference mean / fastest shown `ours` mean. Ratios use unrounded latencies within each OS/backend: above 1 is faster, below 1 is slower. `*` marks CV >= 5% in either measurement. The best measured path can differ from automatic dispatch; a SIMD request can use scalar fallback.

## APIs and adaptation

| Label | Public API measured |
| --- | --- |
| ours basic scalar / SIMD request | is_valid(BytesView, simd=false/true); no UTF-16 decoding |
| ours compat | validate(BytesView, simd=true), including exact error recovery |
| tonyfettes wrapper | Utf8.of_bytesview; wrapper allocation and partial-view materialization |
| core decode acceptance | Strict decode(ignore_bom=false), including UTF-16 allocation |
| ours scalar / SIMD decoding | from_utf8, including validation and UTF-16 decoding |
| tonyfettes / core decoding | Strict decode with identical final UTF-16 output |

| Dependency | Pinned version | License |
| --- | --- | --- |
| tonyfettes/utf8 | 0.2.4 | Apache-2.0 |
| moonbitlang/core/encoding/utf8 | moonc v0.10.22+7b085e9a4-nightly (2026-11-22) | Apache-2.0 |

The tonyfettes 0.2.4 copy has manifest/syntax compatibility edits for this toolchain; its original source hash and exact changes are recorded in benchmarks/vendor/tonyfettes-utf8/UPSTREAM.md and JSON metadata. Range checks and decoding formulas are preserved. Core lacks a standalone validation API, so its acceptance baseline necessarily includes decoding. Read the separate decoding tables for equivalent returned-string operations.

## Method

- All adapters pass the same acceptance and decoded-text corpus before timing. Inputs cover ASCII, Latin, CJK, emoji, mixed text, invalid first/last bytes, a middle overlong sequence, and a truncated suffix. Selected 4 KiB inputs have offset-one views with rejected sentinels outside the view.
- Input construction and owned stream chunks are prepared outside timing. Public API calls, conversions, error adaptation, state creation/finalization, generic callbacks, and bench.keep barriers are timed. All implementations run in the same binary and on the same runner.
- SIMD requests use native V128 range masks with sign-flipped comparisons and UInt64 predecessor assembly, or the pinned lookup3 algorithm on linear-memory Wasm. Inputs below 64 bytes and Wasm GC/JS use scalar fallback. Native avoids byte permutation and unsigned-compare emulation on the validated x86 toolchain. The basic vector path aggregates errors; compat and scalar paths can stop early. Invalid-input cases report latency, not whole-buffer throughput.
- Release mode and sequential backends, with --no-parallelize. The core runner records 10 batch samples and 5% winsorization after calibration around 100 ms; fast cases use 100000 iterations per batch. **Bold** marks the best measured mean; `*` marks CV >= 5% and possible noise. Compare within an OS/backend; a best mean is not evidence of significance.

## Runner context

| OS | CPU | Architecture / logical CPUs | Node.js |
| --- | --- | --- | --- |
| linux | AMD EPYC 7763 64-Core Processor | x86_64 / 4 | v24.22.3 |
| macos | Apple M1 (Virtual) | arm64 / 3 | v24.22.3 |
| windows | AMD EPYC 7763 64-Core Processor                 | AMD64 / 4 | v24.22.3 |

## 1 MiB ASCII validation: throughput (GiB/s)

| OS / backend | ours basic scalar | ours basic SIMD request | ours compat | tonyfettes wrapper | core decode | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 2.574 | **37.366** | 37.3 | 3.396 | 7.484 | 14.515x | 4.993x |
| linux / wasm | 1.322 | **18.551** | 18.372 | 1.326 | 5.125 | 14.03x | 3.62x |
| linux / wasm-gc | **1.323** | 1.317 | 1.321 | 1.074 | 0.335* | 0.995x | 1.232x |
| linux / js | 2.145 | 2.144 | 2.129 | 0.408 | **6.797*** | 1x | 0.316x* |
| macos / native | 1.695* | **31.589*** | 22.844* | 1.636* | 6.51* | 18.64x* | 4.852x* |
| macos / wasm | 0.916* | **11.447*** | 8.767* | 0.799* | 2.81* | 12.492x* | 4.074x* |
| macos / wasm-gc | **0.995*** | 0.883* | 0.983* | 0.78* | 0.293* | 0.887x* | 1.276x* |
| macos / js | 1.768* | 1.224* | 1.155* | 0.314* | **3.524*** | 0.692x* | 0.502x* |
| windows / native | 3.701 | **36.523** | 36.223 | 3.696 | 0.284 | 9.868x | 9.882x |
| windows / wasm | 1.265 | **16.939** | 16.764* | 1.229* | 4.006* | 13.388x | 4.229x* |
| windows / wasm-gc | 1.304 | 1.297 | **1.31** | 1.044 | 0.414* | 0.995x | 1.255x |
| windows / js | 2.12 | 2.098 | 2.126 | 0.403 | **3.317** | 0.99x | 0.641x |

## 1 MiB CJK validation: throughput (GiB/s)

| OS / backend | ours basic scalar | ours basic SIMD request | ours compat | tonyfettes wrapper | core decode | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 1.118 | 1.606 | 1.583 | 1.49 | **3.932** | 1.437x | 0.408x |
| linux / wasm | 0.745 | **3.068** | 2.965 | 0.813 | 0.277 | 4.118x | 3.776x |
| linux / wasm-gc | 0.522 | 0.522 | 0.521 | **0.555** | 0.283 | 0.999x | 0.941x |
| linux / js | 0.483 | 0.479 | 0.482 | 0.155 | **1.515** | 0.992x | 0.319x |
| macos / native | 1.436* | 2.601* | **3.054*** | 1.317* | 1.929* | 1.812x* | 1.583x* |
| macos / wasm | 0.616* | **4.272*** | 3.756* | 0.543* | 0.233* | 6.935x* | 7.863x* |
| macos / wasm-gc | 0.403* | **0.487*** | 0.304* | 0.383* | 0.217* | 1.21x* | 1.272x* |
| macos / js | 0.548 | 0.55 | 0.574 | 0.537* | **2.637** | 1.003x | 0.218x |
| windows / native | 1.449 | **1.85** | 1.78 | 1.265 | 0.394 | 1.277x | 1.462x |
| windows / wasm | 0.729 | **3.022** | 2.895 | 0.798 | 0.264 | 4.149x | 3.787x |
| windows / wasm-gc | 0.522 | 0.524 | 0.522 | **0.551** | 0.301 | 1.003x | 0.951x |
| windows / js | 0.481 | 0.476 | 0.486 | 0.514 | **2.139** | 0.99x | 0.227x |

## 1 MiB emoji validation: throughput (GiB/s)

| OS / backend | ours basic scalar | ours basic SIMD request | ours compat | tonyfettes wrapper | core decode | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 1.318 | 1.605 | 1.582 | 1.699 | **1.732** | 1.217x | 0.927x |
| linux / wasm | 0.745 | **3.069** | 2.973 | 0.746 | 0.295 | 4.118x | 4.115x |
| linux / wasm-gc | 0.571 | 0.57 | 0.572 | **0.599** | 0.282 | 0.998x | 0.955x |
| linux / js | 0.555 | 0.551 | 0.552 | 0.58 | **0.758** | 0.993x | 0.732x |
| macos / native | 1.013* | **2.065*** | 1.966* | 0.819* | 1.337* | 2.038x* | 1.544x* |
| macos / wasm | 0.552* | 3.627* | **3.795*** | 0.619* | 0.272* | 6.575x* | 6.135x* |
| macos / wasm-gc | 0.439* | 0.469* | 0.418* | **0.55*** | 0.311* | 1.07x* | 0.854x* |
| macos / js | 0.598* | 0.554* | 0.534* | 0.593 | **1.685** | 0.927x* | 0.355x* |
| windows / native | 1.29 | **1.819** | 1.753 | 1.464 | 0.387 | 1.41x | 1.242x |
| windows / wasm | 0.739 | **2.997** | 2.907 | 0.735 | 0.285 | 4.057x | 4.08x |
| windows / wasm-gc | 0.567 | 0.571 | 0.571 | **0.59** | 0.308 | 1.007x | 0.967x |
| windows / js | 0.559 | 0.558 | 0.556 | 0.584 | **0.977** | 0.998x | 0.572x |

## 64-byte ASCII validation: latency (ns)

| OS / backend | ours basic scalar | ours basic SIMD request | ours compat | tonyfettes wrapper | core decode | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 34.481 | **19.059** | 21.27 | 31.264 | 61.016 | 1.809x | 1.64x |
| linux / wasm | 79.543 | **44.508** | 47.629 | 82.289 | 107.947 | 1.787x | 1.849x |
| linux / wasm-gc | **62.283** | 64.769 | 68.134 | 78.139 | 143.641 | 0.962x | 1.255x |
| linux / js | 55.019 | 51.71 | **51.146** | 181.89 | 182.268 | 1.064x | 3.556x |
| macos / native | 34.261* | **16.751*** | 30.59* | 31.895* | 59.035* | 2.045x* | 1.904x* |
| macos / wasm | 108.287* | **53.582*** | 56.823* | 95.93* | 225.033* | 2.021x* | 1.79x* |
| macos / wasm-gc | 146.107* | 104.526* | **76.37*** | 102.132* | 181.953* | 1.398x* | 1.337x* |
| macos / js | 56.702* | 49.115* | **44.498** | 208.023* | 138.661* | 1.154x* | 3.116x* |
| windows / native | 66.164 | **55.944** | 58.993 | 74.024 | 305.41 | 1.183x | 1.323x |
| windows / wasm | 80.062 | **44.726** | 66.457* | 120.824* | 115.05* | 1.79x | 2.572x* |
| windows / wasm-gc | **62.803** | 64.8 | 68.805 | 80.723 | 158.712 | 0.969x | 1.285x |
| windows / js | **51.349** | 51.7 | 51.566 | 179.677 | 195.595 | 0.993x | 3.499x |

## 4 KiB offset-one CJK validation: latency (us)

| OS / backend | ours basic scalar | ours basic SIMD request | ours compat | tonyfettes wrapper | core decode | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 3.418 | 2.393 | 2.425 | 2.69 | **1.09** | 1.428x | 0.455x |
| linux / wasm | 5.154 | **1.305** | 1.348 | 4.867 | 13.797 | 3.951x | 3.731x |
| linux / wasm-gc | 7.348 | 7.364 | 7.401 | **7.254** | 12.144 | 0.998x | 0.987x |
| linux / js | 8.076 | 7.841 | 7.815 | 32.822 | **1.611** | 1.03x | 0.206x |
| macos / native | 3.649* | **1.7*** | 2.44* | 4.422* | 2.133* | 2.147x* | 1.255x* |
| macos / wasm | 7.39* | 1.24* | **1.152*** | 7.518* | 18.722* | 5.959x* | 6.526x* |
| macos / wasm-gc | **8.25*** | 8.793* | 9.791* | 9.287* | 15.349* | 0.938x* | 1.126x* |
| macos / js | 9.546* | 8.039* | 10.261* | 34.25* | **3.287*** | 1.187x* | 0.409x* |
| windows / native | 2.655 | **2.125** | 2.23 | 3.238 | 10.04 | 1.249x | 1.524x |
| windows / wasm | 5.209 | **1.312** | 1.356 | 4.954 | 13.922 | 3.97x | 3.775x |
| windows / wasm-gc | 7.42 | 7.435 | 7.399 | **7.235** | 12.23 | 0.998x | 0.978x |
| windows / js | 7.869 | 7.862 | 7.866 | 16.379 | **1.583** | 1.001x | 0.201x |

## Invalid first byte in 64 KiB: latency (ns)

| OS / backend | ours basic scalar | ours basic SIMD request | ours compat | tonyfettes wrapper | core decode | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | **22.563** | 1658.028 | 72.391 | 26.053 | 4104.879 | 0.014x | 1.155x |
| linux / wasm | **81.32** | 3307.786 | 173.341 | 92.713 | 5379.638 | 0.025x | 1.14x |
| linux / wasm-gc | **25.894** | 27.966 | 58.188 | 27.561 | 127896.996 | 0.926x | 1.064x |
| linux / js | 46.214 | **41.878** | 68.704 | 61.153 | 3966.894 | 1.104x | 1.46x |
| macos / native | 46.299* | 2414.965* | 74.953* | **34.954*** | 7653.975* | 0.019x* | 0.755x* |
| macos / wasm | **50.428*** | 4941.379* | 122.017* | 51.215 | 8462.074* | 0.01x* | 1.016x* |
| macos / wasm-gc | **22.424*** | 23.562* | 47.564* | 27.327* | 89605.01* | 0.952x* | 1.219x* |
| macos / js | **25.691** | 36.583* | 38.521* | 52.689* | 3248.833* | 0.702x* | 2.051x* |
| windows / native | **90.255** | 1738.682 | 178.818 | 99.697* | 48582.516 | 0.052x | 1.105x* |
| windows / wasm | **82.86** | 3398.954 | 171.585 | 90.614 | 5517.532 | 0.024x | 1.094x |
| windows / wasm-gc | **25.532** | 28.875 | 59.369 | 28.312 | 109266.001 | 0.884x | 1.109x |
| windows / js | **26.248** | 27.868 | 40.567 | 62.287 | 5057.913 | 0.942x | 2.373x |

## Invalid last byte in 64 KiB: latency (us)

| OS / backend | ours basic scalar | ours basic SIMD request | ours compat | tonyfettes wrapper | core decode | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 23.553 | **1.697** | 1.724 | 17.93 | 8.14 | 13.881x | 4.797x |
| linux / wasm | 46.034 | **3.32** | 3.401 | 46.087 | 11.43 | 13.867x | 3.443x |
| linux / wasm-gc | 46.094 | **46.066** | 92.23 | 56.344 | 200.987 | 1.001x | 1.223x |
| linux / js | 35.859 | **35.833** | 71.71 | 147.364 | 54.515 | 1.001x | 1.521x |
| macos / native | 30.401* | **1.593*** | 1.8* | 30.034* | 10.097* | 19.087x* | 6.34x* |
| macos / wasm | 58.821* | **5.19*** | 5.611* | 59.095* | 15.473* | 11.333x* | 2.981x* |
| macos / wasm-gc | 66.35* | **55.379*** | 112.708 | 63.827* | 173.379* | 1.198x* | 1.153x* |
| macos / js | **31.012** | 31.85* | 65.597* | 119.604 | 56.612* | 0.974x* | 1.826x* |
| windows / native | 16.683 | **1.743** | 1.868 | 16.545 | 192.942 | 9.569x | 9.49x |
| windows / wasm | 47.064 | **3.544** | 3.615 | 46.739 | 11.607 | 13.278x | 3.275x |
| windows / wasm-gc | 46.825 | **46.505** | 95.675* | 57.947 | 177.925 | 1.007x | 1.246x |
| windows / js | **36.442** | 36.833 | 73.062 | 151.573 | 58.974 | 0.989x | 1.618x |

## Truncated 64 KiB UTF-8 suffix: latency (us)

| OS / backend | ours basic scalar | ours basic SIMD request | ours compat | tonyfettes wrapper | core decode | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 23.554 | **1.684** | 1.711 | 17.927 | 7.942 | 13.986x | 4.716x |
| linux / wasm | 46.074 | **3.335** | 3.47 | 46.116 | 11.263 | 13.815x | 3.377x |
| linux / wasm-gc | 46.615 | **46.286** | 92.31 | 56.486 | 200.425 | 1.007x | 1.22x |
| linux / js | 41.04 | **40.94** | 81.973 | 55.557 | 60.814 | 1.002x | 1.357x |
| macos / native | 31.603* | **1.461*** | 1.752* | 30.585* | 9.526 | 21.633x* | 6.521x* |
| macos / wasm | 69.433* | **6.113*** | 7.221* | 77.391* | 21.902* | 11.358x* | 3.583x* |
| macos / wasm-gc | **61.156*** | 62.02* | 125.77* | 73.47* | 215.078* | 0.986x* | 1.201x* |
| macos / js | **28.198** | 28.857 | 61.774* | 46.787* | 48.595 | 0.977x | 1.659x* |
| windows / native | 16.518 | **1.803** | 1.887 | 16.497 | 193.546 | 9.162x | 9.15x |
| windows / wasm | 46.522 | **3.478** | 3.541 | 46.446 | 11.407 | 13.377x | 3.28x |
| windows / wasm-gc | 47.366 | **46.735** | 93.295 | 56.82 | 176.557 | 1.013x | 1.216x |
| windows / js | **36.217** | 36.258 | 73.941 | 55.104 | 61.903 | 0.999x | 1.522x |

## 4 KiB mixed text: validation and decoding (us)

| OS / backend | ours scalar | ours SIMD request | tonyfettes decode | core decode | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 8.592 | 5.299 | 9.819 | **2.779** | 1.621x | 0.524x |
| linux / wasm | 17.096 | **8.803** | 23.766 | 13.451 | 1.942x | 1.528x |
| linux / wasm-gc | 36.195 | 36.063 | 25.42 | **20.928** | 1.004x | 0.58x |
| linux / js | 39.267 | 39.32 | 53.428 | **3.668** | 0.999x | 0.093x |
| macos / native | 9.748* | 5.263* | 10.883* | **3.627*** | 1.852x* | 0.689x* |
| macos / wasm | 22.393* | **11.752*** | 29.897* | 23.423* | 1.905x* | 1.993x* |
| macos / wasm-gc | 29.046* | 29.421* | 22.171* | **20.421*** | 0.987x* | 0.703x* |
| macos / js | 32.805* | 30.755 | 28.512 | **3.526** | 1.067x* | 0.115x |
| windows / native | 11.828 | **9.738** | 11.609 | 11.47 | 1.215x | 1.178x |
| windows / wasm | 17.244 | **8.847** | 23.461 | 13.53 | 1.949x | 1.529x |
| windows / wasm-gc | 44.039* | 39.305* | 27.426* | **22.072** | 1.12x* | 0.562x* |
| windows / js | 39.72 | 39.621 | 32.564 | **3.341** | 1.002x | 0.084x |

## 1 MiB CJK: validation and decoding (us)

| OS / backend | ours scalar | ours SIMD request | tonyfettes decode | core decode | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 1171.712 | 904.373 | 1502.831 | **248.716** | 1.296x | 0.275x |
| linux / wasm | 3328.466 | **2319.231** | 2980.596 | 3535.618 | 1.435x | 1.285x |
| linux / wasm-gc | 5465.095 | 5482.305 | 4741.721 | **3472.858** | 0.997x | 0.635x |
| linux / js | 2539.655 | 2588.052* | 27032.983* | **644.013** | 0.981x* | 0.254x |
| macos / native | 992.7* | 710.396* | 1530.674* | **348.38*** | 1.397x* | 0.49x* |
| macos / wasm | 4850.857* | **2850.158*** | 3362.316* | 4019.844* | 1.702x* | 1.18x* |
| macos / wasm-gc | 4901.762* | 4479.102* | **2969.179*** | 4779.487* | 1.094x* | 0.663x* |
| macos / js | 2699.575* | 2635.463* | 16679.367* | **314.94*** | 1.024x* | 0.12x* |
| windows / native | 2658.297 | 2550.799 | **2140.25*** | 2522.516 | 1.042x | 0.839x* |
| windows / wasm | 3459.416 | **2313.664** | 2942.279 | 3562.649 | 1.495x | 1.272x |
| windows / wasm-gc | 4666.92 | 4667.395 | 3786.906 | **3201.354** | 1x | 0.686x |
| windows / js | 2483.791 | 2478.926 | 17750.676* | **452.48** | 1.002x | 0.183x |

## 4 KiB offset-one CJK: validation and decoding (us)

| OS / backend | ours scalar | ours SIMD request | tonyfettes decode | core decode | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 4.549 | 3.563 | 5.971 | **1.09** | 1.277x | 0.306x |
| linux / wasm | 12.67 | **8.881** | 12.132 | 13.767 | 1.427x | 1.366x |
| linux / wasm-gc | 16.474 | 16.511 | 12.558 | **12.194** | 0.998x | 0.74x |
| linux / js | 9.079 | 9.084 | 18.262 | **1.611** | 0.999x | 0.177x |
| macos / native | 4.345* | 2.681* | 5.822* | **1.655*** | 1.621x* | 0.617x* |
| macos / wasm | 17.582* | **9.808*** | 14.377* | 16.22* | 1.793x* | 1.466x* |
| macos / wasm-gc | 14.143* | 15.027* | **9.974*** | 11.961* | 0.941x* | 0.705x* |
| macos / js | 7.952* | 7.495 | 13.812 | **1.503*** | 1.061x* | 0.201x* |
| windows / native | 8.65 | 8.096 | **6.923** | 10.02 | 1.068x | 0.855x |
| windows / wasm | 12.781 | **9.209*** | 12.131 | 13.977 | 1.388x* | 1.317x* |
| windows / wasm-gc | 18.12* | 18.141* | 13.55* | **13.318*** | 0.999x* | 0.735x* |
| windows / js | 9.317 | 9.189 | 18.334 | **1.65** | 1.014x | 0.18x |

## 64 KiB mixed stream, 4 KiB chunks: latency (us)

| OS / backend | ours scalar | ours SIMD request | SIMD speedup |
| --- | ---: | ---: | ---: |
| linux / native | 91.967 | **38.207** | 2.407x |
| linux / wasm | 152.213 | **20.339** | 7.484x |
| linux / wasm-gc | **283.535** | 284.007 | 0.998x |
| linux / js | 232.313 | **232.234** | 1x |
| macos / native | 100.75* | **21.856*** | 4.61x* |
| macos / wasm | 230.745* | **19.833*** | 11.634x* |
| macos / wasm-gc | 243.978* | **227.153*** | 1.074x* |
| macos / js | 237.574 | **200.739** | 1.183x |
| windows / native | 75.323 | **34.158** | 2.205x |
| windows / wasm | 153.8 | **20.957** | 7.339x |
| windows / wasm-gc | 286.066 | **284.983** | 1.004x |
| windows / js | **234.229** | 235.159 | 0.996x |

<details>
<summary>Toolchain and reproduction</summary>

**linux:**

~~~text
moon 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moon
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) ~/.moon/bin/moonc
moonrun 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moonrun
~~~

**native:** 2026-11-25T03:13:12Z to 2026-11-25T03:16:06Z

~~~text
moon -C benchmarks bench --target native --release --no-parallelize -p justjavac/benchmarks/utf8
~~~

**wasm:** 2026-11-25T03:16:06Z to 2026-11-25T03:19:01Z

~~~text
moon -C benchmarks bench --target wasm --release --no-parallelize -p justjavac/benchmarks/utf8
~~~

**wasm-gc:** 2026-11-25T03:19:01Z to 2026-11-25T03:21:57Z

~~~text
moon -C benchmarks bench --target wasm-gc --release --no-parallelize -p justjavac/benchmarks/utf8
~~~

**js:** 2026-11-25T03:21:57Z to 2026-11-25T03:24:52Z

~~~text
moon -C benchmarks bench --target js --release --no-parallelize -p justjavac/benchmarks/utf8
~~~

**macos:**

~~~text
moon 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moon
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) ~/.moon/bin/moonc
moonrun 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moonrun
~~~

**native:** 2026-11-25T03:13:36Z to 2026-11-25T03:16:31Z

~~~text
moon -C benchmarks bench --target native --release --no-parallelize -p justjavac/benchmarks/utf8
~~~

**wasm:** 2026-11-25T03:16:31Z to 2026-11-25T03:19:25Z

~~~text
moon -C benchmarks bench --target wasm --release --no-parallelize -p justjavac/benchmarks/utf8
~~~

**wasm-gc:** 2026-11-25T03:19:25Z to 2026-11-25T03:22:20Z

~~~text
moon -C benchmarks bench --target wasm-gc --release --no-parallelize -p justjavac/benchmarks/utf8
~~~

**js:** 2026-11-25T03:22:20Z to 2026-11-25T03:25:16Z

~~~text
moon -C benchmarks bench --target js --release --no-parallelize -p justjavac/benchmarks/utf8
~~~

**windows:**

~~~text
moon 0.1.20261120 (aaf8010 2026-11-20) ~\.moon\bin\moon.exe
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) ~\.moon\bin\moonc.exe
moonrun 0.1.20261120 (aaf8010 2026-11-20) ~\.moon\bin\moonrun.exe
~~~

**native:** 2026-11-25T03:14:04Z to 2026-11-25T03:17:06Z

~~~text
moon -C benchmarks bench --target native --release --no-parallelize -p justjavac/benchmarks/utf8
~~~

**wasm:** 2026-11-25T03:17:06Z to 2026-11-25T03:20:00Z

~~~text
moon -C benchmarks bench --target wasm --release --no-parallelize -p justjavac/benchmarks/utf8
~~~

**wasm-gc:** 2026-11-25T03:20:00Z to 2026-11-25T03:22:57Z

~~~text
moon -C benchmarks bench --target wasm-gc --release --no-parallelize -p justjavac/benchmarks/utf8
~~~

**js:** 2026-11-25T03:22:57Z to 2026-11-25T03:25:52Z

~~~text
moon -C benchmarks bench --target js --release --no-parallelize -p justjavac/benchmarks/utf8
~~~

Run `moon -C benchmarks test utf8 --target all`, then `moon run scripts/benchmark.mbtx utf8`. A complete CI snapshot requires all three systems and all four backends with identical source/run/attempt/dependencies. Local rendering uses `moon run scripts/benchmark_report.mbtx --local utf8 _build/benchmarks/utf8/windows.json _build/utf8-report` and writes explicitly LOCAL-named artifacts. Raw CI logs are retained for 90 days.

</details>
