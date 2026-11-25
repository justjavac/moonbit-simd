# UUID performance comparison

[CI run 45514337662](https://github.com/justjavac/moonbit-simd/actions/runs/45514337662) | [source 081b964](https://github.com/justjavac/moonbit-simd/commit/081b9648c887ba34e485a0c3143e3735c3fa279d) | attempt 1

**Scope:** 3 operating systems x 4 backends x 193 cases = **2316 measurements**. [BENCHMARK-DATA.json](BENCHMARK-DATA.json) retains every unrounded statistic, UUID count, byte/code-unit length, view/output offset, command, timestamp, dependency, and runner detail.

**Speedups:** `SIMD speedup` = scalar mean / SIMD-request mean; `Best ours vs ref` = fastest reference mean / fastest shown `ours` mean. Ratios use unrounded latencies within each OS/backend: above 1 is faster, below 1 is slower. `*` marks CV >= 5% in either measurement. The best measured path can differ from automatic dispatch; a SIMD request can use scalar fallback.

## At a glance

Native hyphenated parsing, 36 ASCII code units per UUID:

- **linux:** SIMD request 46.947 ns; **0.876x** scalar and **1.519x** the fastest external mean (wulisususu).
- **macos:** SIMD request 27.383 ns; **1.644x** scalar and **2.586x** the fastest external mean (wulisususu).
- **windows:** SIMD request 125.968 ns; **0.832x** scalar and **0.962x** the fastest external mean (bobzhang).

Ratios below 1 mean slower execution. These are workload-specific measured means; variability marks and the full distributions qualify the comparisons.

## Implementations

| Label | Package / pinned version | Public API measured |
| --- | --- | --- |
| ours scalar | justjavac/uuid / source above | parse and format with Scalar |
| ours SIMD request | justjavac/uuid / source above | parse and format with Simd |
| bobzhang | bobzhang/uuidm / 0.2.0 | from_string/from_urn(String), Uuid::to_string/to_string_simple |
| f4ah6o | f4ah6o/uuidm / 0.2.1 | from_string/from_urn(String), Uuid::to_string/to_string_simple; bobzhang fork |
| moonbitstack | moonbitstack/moonuuid / 0.2.1 | parse(StringView), Uuid::to_string/hex |
| wulisususu | wulisususu/moonuuid / 0.1.0 | parse_permissive(String), to_string; no compact formatter |

## Method

- Every adapter matches independent binary values and arithmetic formatting oracles, including a deterministic 1024-UUID corpus. f4ah6o is a bobzhang fork; agreement is not independent proof of complete grammar conformance.
- Parse-only and parse-plus-canonical-formatting are separate. Formatting starts from UUID values prepared outside the timer. Batch callbacks include public calls, adapter logic, and a keep barrier for each of 1024 distinct UUIDs.
- Input construction and subview selection are outside timing. Required StringView-to-String conversions for bobzhang, f4ah6o, and wulisususu stay inside timing. Full views can reuse their String; offset-1 views materialize their contents. bobzhang/f4ah6o use from_urn for the URN case.
- bobzhang/f4ah6o expose no braced parser; those cases are omitted. wulisususu exposes no compact formatter; it is omitted from that comparison. Uppercase formatting, arbitrary-byte parsing, and reusable-buffer writes compare our scalar and SIMD paths separately.
- The SIMD request executes checked portable V128 kernels on native and linear-memory Wasm, with scalar fallback on Wasm GC/JS. UTF-16 loads account for the view's code-unit start; byte loads and output stores stay inside their ranges. Output-string allocation and ASCII decoding are timed; write_* reuses a prepared buffer.
- Release mode, sequential backends, 10 batch samples, and 5% winsorization. Calibration targets about 100 ms; submicrosecond cases use 100000 calls per batch. Timings include bench.keep. **Bold** marks the smallest mean in a row; `*` marks CV >= 5% and possible noise, not statistical significance.

## Runner context

| OS | CPU | Architecture / logical CPUs | Runner / image | Node.js |
| --- | --- | --- | --- | --- |
| linux | Intel(R) Xeon(R) 6975P-C | x86_64 / 4 | ubuntu-latest / ubuntu26 / 20261116.88.1 | v24.22.3 |
| macos | Apple M2 Pro (Virtual) | arm64 / 5 | macos-latest / macos26 / 20261117.0516.1 | v24.22.3 |
| windows | AMD EPYC 9V45 96-Core Processor                 | AMD64 / 4 | windows-latest / win25-vs2026 / 20261116.315.1 | v24.22.3 |

## Hyphenated UUID: parse latency (ns)

| OS / backend | ours scalar | ours SIMD request | bobzhang | f4ah6o | moonbitstack | wulisususu | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | **41.146** | 46.947 | 71.935 | 1239.201 | 616.112 | 71.314 | 0.876x | 1.733x |
| linux / wasm | 148.096 | **95.143** | 130.985 | 3490.463 | 1786.315 | 139.508 | 1.557x | 1.377x |
| linux / wasm-gc | 91.437 | 89.86 | **67.219** | 568.237 | 702.737 | 86.511 | 1.018x | 0.748x |
| linux / js | 507.671 | 501.93 | **192.182** | 398.774 | 1696.489 | 872.287 | 1.011x | 0.383x |
| macos / native | 45.027 | **27.383** | 77.27* | 1527.317 | 617.13 | 70.813 | 1.644x | 2.586x |
| macos / wasm | 134.524 | **93.869** | 171.922 | 3872.631 | 1790.501 | 154.21* | 1.433x | 1.643x* |
| macos / wasm-gc | 102.477 | 87.592 | **85.96** | 690.181 | 733.219 | 109.603* | 1.17x | 0.981x |
| macos / js | 413.752 | 460.624 | **185.265** | 388.731 | 1655.263* | 999.953 | 0.898x | 0.448x |
| windows / native | **104.821** | 125.968 | 121.18 | 3824.654 | 1188.512 | 140.158 | 0.832x | 1.156x |
| windows / wasm | 102.036 | **87.842** | 114.848* | 4076.027* | 1506.836 | 111.095 | 1.162x | 1.265x |
| windows / wasm-gc | 78.178* | 65.336 | **57.08** | 525.954 | 612.174 | 72.362 | 1.197x* | 0.874x |
| windows / js | 428.705* | 407.918 | **116.136** | 321.287 | 1357.328 | 908.984 | 1.051x* | 0.285x |

## Compact UUID: parse latency (ns)

| OS / backend | ours scalar | ours SIMD request | bobzhang | f4ah6o | moonbitstack | wulisususu | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 50.008* | 44.947 | 58.641 | 1194.671 | 587.428 | **43.939** | 1.113x* | 0.978x |
| linux / wasm | 122.313 | **88.964** | 129.504 | 4005.511 | 1731.59 | 117.976* | 1.375x | 1.326x* |
| linux / wasm-gc | 60.743 | 60.191 | **58.485** | 597.693 | 679.941 | 62.028 | 1.009x | 0.972x |
| linux / js | 451.487 | 423.551 | **176.201** | 399.771 | 1670.53 | 908.155 | 1.066x | 0.416x |
| macos / native | 43.521 | **29.669*** | 66.53 | 1521.892* | 552.405 | 39.928 | 1.467x* | 1.346x* |
| macos / wasm | 121.103* | **92.58** | 163* | 4556.949* | 1722.874 | 143.898 | 1.308x* | 1.554x |
| macos / wasm-gc | 58.459 | **54.233** | 68.183 | 710.869* | 678.114* | 76.992* | 1.078x | 1.257x |
| macos / js | 410.269 | 389.285 | **179.383** | 366.557 | 1345.424 | 950.752 | 1.054x | 0.461x |
| windows / native | **88.423** | 128.985* | 115.498 | 4045.207 | 1139.824 | 119.675 | 0.686x* | 1.306x |
| windows / wasm | 111.567 | **83.69** | 113.786 | 3909.831 | 1633.604* | 106.238* | 1.333x | 1.269x* |
| windows / wasm-gc | 42.788 | **40.459** | 55.729* | 549.008 | 563.634* | 55.334* | 1.058x | 1.368x* |
| windows / js | 379.815 | 360.581 | **110.78** | 322.066 | 1328.2 | 913.395 | 1.053x | 0.307x |

## Hyphenated UUID: parse and canonical output (ns)

| OS / backend | ours scalar | ours SIMD request | bobzhang | f4ah6o | moonbitstack | wulisususu | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 125.665 | **118.418** | 1294.966 | 2475 | 1020.395 | 223.257 | 1.061x | 1.885x |
| linux / wasm | 365.948 | **247.039** | 4237.531 | 7113.055 | 2655.837 | 531.849 | 1.481x | 2.153x |
| linux / wasm-gc | 313.373 | 310.717 | 810.12 | 1306.701 | 1165.14 | **261.64** | 1.009x | 0.842x |
| linux / js | 2005.526 | 2006.233 | **408.411** | 627.876 | 2816.714 | 1853.842 | 1x | 0.204x |
| macos / native | 133.594 | **89.394** | 1457.774 | 3018.938 | 1018.199 | 215.981 | 1.494x | 2.416x |
| macos / wasm | 343.897 | **247.389** | 3678.793 | 7195.902 | 2351.131 | 496.929* | 1.39x | 2.009x* |
| macos / wasm-gc | 299.562 | **267.452** | 889.829 | 1540.327* | 1147.056 | 303.319* | 1.12x | 1.134x* |
| macos / js | 1495.358 | 1647.687 | **523.748** | 631.966 | 2672.97 | 2027.032 | 0.908x | 0.35x |
| windows / native | **298.303** | 310.197 | 3864.777 | 7526.558 | 1892.002 | 383.074 | 0.962x | 1.284x |
| windows / wasm | 249.594 | **227.759** | 3540.245* | 6992.015* | 2351.436 | 451.053 | 1.096x | 1.98x |
| windows / wasm-gc | **211.877** | 240.076* | 692.934 | 1167.068 | 1020.843 | 225.591 | 0.883x* | 1.065x |
| windows / js | 1689.747 | 1699.129 | **272.999** | 523.623* | 2524.653 | 2100.912* | 0.994x | 0.162x |

## Prepared UUID: hyphenated formatting (ns)

| OS / backend | ours scalar | ours SIMD request | bobzhang | f4ah6o | moonbitstack | wulisususu | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 86.657 | **73.279** | 1218.364 | 1224.573 | 363.939 | 160.712 | 1.183x | 2.193x |
| linux / wasm | 231.577 | **126.642** | 3350.342 | 3269.357 | 822.282 | 380.835 | 1.829x | 3.007x |
| linux / wasm-gc | 225.046 | **224.143** | 701.439 | 665.647 | 356.513 | 228.852 | 1.004x | 1.021x |
| linux / js | 1450.558 | 1508.749 | 202.341 | **200.866** | 955.156 | 871.583 | 0.961x | 0.138x |
| macos / native | 94.779 | **70.408** | 1293.279* | 1404.263 | 343.891* | 151.068 | 1.346x | 2.146x |
| macos / wasm | 212.659 | **133.72** | 3677.339* | 3481.212* | 732.063 | 347.431 | 1.59x | 2.598x |
| macos / wasm-gc | **200.213** | 202.37 | 812.54 | 800.371* | 382.228* | 265.662 | 0.989x | 1.327x |
| macos / js | 1135.571 | 991.275 | **306.92** | 319.51* | 962.362* | 993.99 | 1.146x | 0.31x |
| windows / native | 219.311 | **209.949** | 3670.089 | 3876.624* | 735.335 | 263.776 | 1.045x | 1.256x |
| windows / wasm | 161.865 | **112.402** | 2795.04 | 2992.326 | 702.956 | 348.997 | 1.44x | 3.105x |
| windows / wasm-gc | 169.658* | **148.19** | 655.081 | 618.903 | 311.231 | 203.26 | 1.145x* | 1.372x |
| windows / js | 1168.003 | 1178.678 | 158.173 | **157.585** | 897.752 | 808.964 | 0.991x | 0.135x |

## Prepared UUID: compact formatting (ns)

| OS / backend | ours scalar | ours SIMD request | bobzhang | f4ah6o | moonbitstack | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 77.833 | **60.44** | 1192.436 | 1195.616 | 158.384 | 1.288x | 2.621x |
| linux / wasm | 175.899 | **107.965** | 3274.23 | 3117.034 | 319.551 | 1.629x | 2.96x |
| linux / wasm-gc | 144.319 | **142.328** | 577.182 | 565.507 | 171.388 | 1.014x | 1.204x |
| linux / js | 1395.525 | 1476.798 | **156.36** | 157.489 | 664.427 | 0.945x | 0.112x |
| macos / native | 73.407 | **64.384*** | 1314.796 | 1318.756 | 180.175 | 1.14x* | 2.798x* |
| macos / wasm | 156.425 | **111.464** | 3427.155 | 3500.228 | 300.641 | 1.403x | 2.697x |
| macos / wasm-gc | 127.917 | **117.438** | 712.262 | 749.881 | 189.766 | 1.089x | 1.616x |
| macos / js | 1132.548 | 999.516 | **170.09** | 190.145 | 730.944 | 1.133x | 0.17x |
| windows / native | 173.242 | **166.551** | 3732.191 | 3618.629 | 338.562* | 1.04x | 2.033x* |
| windows / wasm | 130.876 | **130.716*** | 2827.474 | 2903.884 | 258.383 | 1.001x* | 1.977x* |
| windows / wasm-gc | **104.606** | 106.165 | 597.945 | 565.004 | 135.587 | 0.985x | 1.296x |
| windows / js | 1114.731 | 1141.301 | 139.404* | **131.759** | 623.827 | 0.977x | 0.118x |

## Hyphenated UUID: offset-1 StringView parsing (ns)

| OS / backend | ours scalar | ours SIMD request | bobzhang | f4ah6o | moonbitstack | wulisususu | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | **42.326** | 46.931 | 78.254 | 1263.02 | 621.544 | 77.454 | 0.902x | 1.83x |
| linux / wasm | 145.175 | **104.42** | 260.251 | 3519.694 | 1689.152 | 275.942 | 1.39x | 2.492x |
| linux / wasm-gc | 90.991 | **89.931** | 128.764 | 636.116 | 702.242 | 150.036 | 1.012x | 1.432x |
| linux / js | 507.138 | 499.97 | **231.323** | 438.304 | 1656.474 | 888.769 | 1.014x | 0.463x |
| macos / native | 45.233 | **27.462** | 84.038 | 1515.691 | 642.293 | 71.449 | 1.647x | 2.602x |
| macos / wasm | 127.987 | **111.423** | 255.889 | 3786.87 | 1890.567 | 256.081 | 1.149x | 2.297x |
| macos / wasm-gc | 98.038 | **86.447** | 184.395 | 823.063* | 767.323 | 192.333 | 1.134x | 2.133x |
| macos / js | 410.537 | 456.665* | **208.216** | 383.303 | 1726.311 | 1070.86 | 0.899x* | 0.507x |
| windows / native | **112.512*** | 151.067* | 149.128 | 3876.399 | 1280.144* | 165.83 | 0.745x* | 1.325x* |
| windows / wasm | 101.635 | **92.72** | 221.358* | 3622.001* | 1544.171* | 203.618 | 1.096x | 2.196x |
| windows / wasm-gc | **63.777** | 67.466* | 119.336 | 587.121 | 592.127 | 139.349 | 0.945x* | 1.871x |
| windows / js | 398.835 | 411.211* | **140.493*** | 347.149 | 1351.069 | 884.216 | 0.97x* | 0.352x* |

## 1024 distinct UUIDs: batch parse latency (us)

| OS / backend | ours scalar | ours SIMD request | bobzhang | f4ah6o | moonbitstack | wulisususu | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| linux / native | 42.279 | **38.412** | 168.788 | 1366.823 | 644.454 | 157.664 | 1.101x | 4.105x |
| linux / wasm | 132.943 | **88.905** | 271.744 | 3849.79 | 1839.61 | 250.524 | 1.495x | 2.818x |
| linux / wasm-gc | **89.468** | 90.073 | 160.322 | 821.552 | 723.719 | 205.91 | 0.993x | 1.792x |
| linux / js | 508.542 | 493.496 | **304.258** | 667.064 | 1765.192 | 1057.756 | 1.03x | 0.617x |
| macos / native | 48.947 | **31.567** | 75.694 | 1708.094 | 550.934 | 137.522 | 1.551x | 2.398x |
| macos / wasm | 128.56* | **89.999** | 276.005 | 4139.162 | 1622.498 | 219.049 | 1.428x* | 2.434x |
| macos / wasm-gc | 88.447 | **86.696** | 170.21 | 988.322 | 663.316 | 173.368 | 1.02x | 1.963x |
| macos / js | 474.483* | 403.833 | **286.556** | 578.27 | 1628.937 | 1104.555 | 1.175x* | 0.71x |
| windows / native | **118.085** | 142.153 | 167.495* | 4288.956 | 1259.379 | 217.939* | 0.831x | 1.418x* |
| windows / wasm | 99.932 | **93.119*** | 176.283 | 4011.45* | 1521.128 | 150.424 | 1.073x* | 1.615x* |
| windows / wasm-gc | 64.256 | 63.939 | **62.197** | 632.986 | 606.858 | 112.174 | 1.005x | 0.973x |
| windows / js | 398.468 | 412.076 | **204.798*** | 535.974 | 1522.07 | 1036.821 | 0.967x | 0.514x* |

## Hyphenated bytes: offset-1 parsing (ns)

| OS / backend | ours scalar | ours SIMD request | SIMD speedup |
| --- | ---: | ---: | ---: |
| linux / native | 40.246 | **36.229** | 1.111x |
| linux / wasm | 129.736 | **94.465** | 1.373x |
| linux / wasm-gc | 91.147 | **90.535** | 1.007x |
| linux / js | 434.67 | **430.096** | 1.011x |
| macos / native | 38.56 | **27.83** | 1.386x |
| macos / wasm | 110.151 | **102.117** | 1.079x |
| macos / wasm-gc | 81.246 | **79.726** | 1.019x |
| macos / js | 427.631 | **374.808** | 1.141x |
| windows / native | **96.621** | 116.184 | 0.832x |
| windows / wasm | **82.345** | 97.224* | 0.847x* |
| windows / wasm-gc | 61.454 | **61.399** | 1.001x |
| windows / js | **369.724** | 381.05 | 0.97x |

## Reusable output buffer: offset-1 hyphenated write (ns)

| OS / backend | ours scalar | ours SIMD request | SIMD speedup |
| --- | ---: | ---: | ---: |
| linux / native | 46.47 | **24.704** | 1.881x |
| linux / wasm | 155.213 | **53.22** | 2.916x |
| linux / wasm-gc | 89.971 | **89.943** | 1x |
| linux / js | 813.48 | **799.083** | 1.018x |
| macos / native | 45.362 | **22.607** | 2.007x |
| macos / wasm | 139.404 | **66.788** | 2.087x |
| macos / wasm-gc | 97.701 | **90.316** | 1.082x |
| macos / js | 803.847 | **707.6** | 1.136x |
| windows / native | 99.875* | **84.727** | 1.179x* |
| windows / wasm | 91.134 | **60.669*** | 1.502x* |
| windows / wasm-gc | **61.733** | 62.561 | 0.987x |
| windows / js | **763.57** | 790.38 | 0.966x |

<details>
<summary>Toolchain, commands, and reproduction</summary>

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

Run `moon -C benchmarks test --target all`, then `moon run scripts/benchmark.mbtx uuid` for local measurements. Select uuid in the Benchmarks workflow for a complete CI snapshot. The collector and report validator require the exact 193-case inventory; the report also rejects local data, incomplete matrices, mixed runs/attempts/source revisions, changed dependency pins, invalid statistics, and mismatched length metadata. Raw logs are retained for 90 days. Reports retain the measured source commit when committed later.

</details>
