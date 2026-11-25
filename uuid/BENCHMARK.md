# UUID performance comparison

[CI run 45514337662](https://github.com/justjavac/moonbit-simd/actions/runs/45514337662) | [source 081b964](https://github.com/justjavac/moonbit-simd/commit/081b9648c887ba34e485a0c3143e3735c3fa279d) | attempt 1

**Scope:** 3 operating systems x 4 backends x 193 cases = **2316 measurements**. [BENCHMARK-DATA.json](BENCHMARK-DATA.json) retains every unrounded statistic, UUID count, byte/code-unit length, view/output offset, command, timestamp, dependency, and runner detail.

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

| OS / backend | ours scalar | ours SIMD request | bobzhang | f4ah6o | moonbitstack | wulisususu |
| --- | --- | --- | --- | --- | --- | --- |
| linux / native | **41.146** | 46.947 | 71.935 | 1239.201 | 616.112 | 71.314 |
| linux / wasm | 148.096 | **95.143** | 130.985 | 3490.463 | 1786.315 | 139.508 |
| linux / wasm-gc | 91.437 | 89.86 | **67.219** | 568.237 | 702.737 | 86.511 |
| linux / js | 507.671 | 501.93 | **192.182** | 398.774 | 1696.489 | 872.287 |
| macos / native | 45.027 | **27.383** | 77.27* | 1527.317 | 617.13 | 70.813 |
| macos / wasm | 134.524 | **93.869** | 171.922 | 3872.631 | 1790.501 | 154.21* |
| macos / wasm-gc | 102.477 | 87.592 | **85.96** | 690.181 | 733.219 | 109.603* |
| macos / js | 413.752 | 460.624 | **185.265** | 388.731 | 1655.263* | 999.953 |
| windows / native | **104.821** | 125.968 | 121.18 | 3824.654 | 1188.512 | 140.158 |
| windows / wasm | 102.036 | **87.842** | 114.848* | 4076.027* | 1506.836 | 111.095 |
| windows / wasm-gc | 78.178* | 65.336 | **57.08** | 525.954 | 612.174 | 72.362 |
| windows / js | 428.705* | 407.918 | **116.136** | 321.287 | 1357.328 | 908.984 |

## Compact UUID: parse latency (ns)

| OS / backend | ours scalar | ours SIMD request | bobzhang | f4ah6o | moonbitstack | wulisususu |
| --- | --- | --- | --- | --- | --- | --- |
| linux / native | 50.008* | 44.947 | 58.641 | 1194.671 | 587.428 | **43.939** |
| linux / wasm | 122.313 | **88.964** | 129.504 | 4005.511 | 1731.59 | 117.976* |
| linux / wasm-gc | 60.743 | 60.191 | **58.485** | 597.693 | 679.941 | 62.028 |
| linux / js | 451.487 | 423.551 | **176.201** | 399.771 | 1670.53 | 908.155 |
| macos / native | 43.521 | **29.669*** | 66.53 | 1521.892* | 552.405 | 39.928 |
| macos / wasm | 121.103* | **92.58** | 163* | 4556.949* | 1722.874 | 143.898 |
| macos / wasm-gc | 58.459 | **54.233** | 68.183 | 710.869* | 678.114* | 76.992* |
| macos / js | 410.269 | 389.285 | **179.383** | 366.557 | 1345.424 | 950.752 |
| windows / native | **88.423** | 128.985* | 115.498 | 4045.207 | 1139.824 | 119.675 |
| windows / wasm | 111.567 | **83.69** | 113.786 | 3909.831 | 1633.604* | 106.238* |
| windows / wasm-gc | 42.788 | **40.459** | 55.729* | 549.008 | 563.634* | 55.334* |
| windows / js | 379.815 | 360.581 | **110.78** | 322.066 | 1328.2 | 913.395 |

## Hyphenated UUID: parse and canonical output (ns)

| OS / backend | ours scalar | ours SIMD request | bobzhang | f4ah6o | moonbitstack | wulisususu |
| --- | --- | --- | --- | --- | --- | --- |
| linux / native | 125.665 | **118.418** | 1294.966 | 2475 | 1020.395 | 223.257 |
| linux / wasm | 365.948 | **247.039** | 4237.531 | 7113.055 | 2655.837 | 531.849 |
| linux / wasm-gc | 313.373 | 310.717 | 810.12 | 1306.701 | 1165.14 | **261.64** |
| linux / js | 2005.526 | 2006.233 | **408.411** | 627.876 | 2816.714 | 1853.842 |
| macos / native | 133.594 | **89.394** | 1457.774 | 3018.938 | 1018.199 | 215.981 |
| macos / wasm | 343.897 | **247.389** | 3678.793 | 7195.902 | 2351.131 | 496.929* |
| macos / wasm-gc | 299.562 | **267.452** | 889.829 | 1540.327* | 1147.056 | 303.319* |
| macos / js | 1495.358 | 1647.687 | **523.748** | 631.966 | 2672.97 | 2027.032 |
| windows / native | **298.303** | 310.197 | 3864.777 | 7526.558 | 1892.002 | 383.074 |
| windows / wasm | 249.594 | **227.759** | 3540.245* | 6992.015* | 2351.436 | 451.053 |
| windows / wasm-gc | **211.877** | 240.076* | 692.934 | 1167.068 | 1020.843 | 225.591 |
| windows / js | 1689.747 | 1699.129 | **272.999** | 523.623* | 2524.653 | 2100.912* |

## Prepared UUID: hyphenated formatting (ns)

| OS / backend | ours scalar | ours SIMD request | bobzhang | f4ah6o | moonbitstack | wulisususu |
| --- | --- | --- | --- | --- | --- | --- |
| linux / native | 86.657 | **73.279** | 1218.364 | 1224.573 | 363.939 | 160.712 |
| linux / wasm | 231.577 | **126.642** | 3350.342 | 3269.357 | 822.282 | 380.835 |
| linux / wasm-gc | 225.046 | **224.143** | 701.439 | 665.647 | 356.513 | 228.852 |
| linux / js | 1450.558 | 1508.749 | 202.341 | **200.866** | 955.156 | 871.583 |
| macos / native | 94.779 | **70.408** | 1293.279* | 1404.263 | 343.891* | 151.068 |
| macos / wasm | 212.659 | **133.72** | 3677.339* | 3481.212* | 732.063 | 347.431 |
| macos / wasm-gc | **200.213** | 202.37 | 812.54 | 800.371* | 382.228* | 265.662 |
| macos / js | 1135.571 | 991.275 | **306.92** | 319.51* | 962.362* | 993.99 |
| windows / native | 219.311 | **209.949** | 3670.089 | 3876.624* | 735.335 | 263.776 |
| windows / wasm | 161.865 | **112.402** | 2795.04 | 2992.326 | 702.956 | 348.997 |
| windows / wasm-gc | 169.658* | **148.19** | 655.081 | 618.903 | 311.231 | 203.26 |
| windows / js | 1168.003 | 1178.678 | 158.173 | **157.585** | 897.752 | 808.964 |

## Prepared UUID: compact formatting (ns)

| OS / backend | ours scalar | ours SIMD request | bobzhang | f4ah6o | moonbitstack |
| --- | --- | --- | --- | --- | --- |
| linux / native | 77.833 | **60.44** | 1192.436 | 1195.616 | 158.384 |
| linux / wasm | 175.899 | **107.965** | 3274.23 | 3117.034 | 319.551 |
| linux / wasm-gc | 144.319 | **142.328** | 577.182 | 565.507 | 171.388 |
| linux / js | 1395.525 | 1476.798 | **156.36** | 157.489 | 664.427 |
| macos / native | 73.407 | **64.384*** | 1314.796 | 1318.756 | 180.175 |
| macos / wasm | 156.425 | **111.464** | 3427.155 | 3500.228 | 300.641 |
| macos / wasm-gc | 127.917 | **117.438** | 712.262 | 749.881 | 189.766 |
| macos / js | 1132.548 | 999.516 | **170.09** | 190.145 | 730.944 |
| windows / native | 173.242 | **166.551** | 3732.191 | 3618.629 | 338.562* |
| windows / wasm | 130.876 | **130.716*** | 2827.474 | 2903.884 | 258.383 |
| windows / wasm-gc | **104.606** | 106.165 | 597.945 | 565.004 | 135.587 |
| windows / js | 1114.731 | 1141.301 | 139.404* | **131.759** | 623.827 |

## Hyphenated UUID: offset-1 StringView parsing (ns)

| OS / backend | ours scalar | ours SIMD request | bobzhang | f4ah6o | moonbitstack | wulisususu |
| --- | --- | --- | --- | --- | --- | --- |
| linux / native | **42.326** | 46.931 | 78.254 | 1263.02 | 621.544 | 77.454 |
| linux / wasm | 145.175 | **104.42** | 260.251 | 3519.694 | 1689.152 | 275.942 |
| linux / wasm-gc | 90.991 | **89.931** | 128.764 | 636.116 | 702.242 | 150.036 |
| linux / js | 507.138 | 499.97 | **231.323** | 438.304 | 1656.474 | 888.769 |
| macos / native | 45.233 | **27.462** | 84.038 | 1515.691 | 642.293 | 71.449 |
| macos / wasm | 127.987 | **111.423** | 255.889 | 3786.87 | 1890.567 | 256.081 |
| macos / wasm-gc | 98.038 | **86.447** | 184.395 | 823.063* | 767.323 | 192.333 |
| macos / js | 410.537 | 456.665* | **208.216** | 383.303 | 1726.311 | 1070.86 |
| windows / native | **112.512*** | 151.067* | 149.128 | 3876.399 | 1280.144* | 165.83 |
| windows / wasm | 101.635 | **92.72** | 221.358* | 3622.001* | 1544.171* | 203.618 |
| windows / wasm-gc | **63.777** | 67.466* | 119.336 | 587.121 | 592.127 | 139.349 |
| windows / js | 398.835 | 411.211* | **140.493*** | 347.149 | 1351.069 | 884.216 |

## 1024 distinct UUIDs: batch parse latency (us)

| OS / backend | ours scalar | ours SIMD request | bobzhang | f4ah6o | moonbitstack | wulisususu |
| --- | --- | --- | --- | --- | --- | --- |
| linux / native | 42.279 | **38.412** | 168.788 | 1366.823 | 644.454 | 157.664 |
| linux / wasm | 132.943 | **88.905** | 271.744 | 3849.79 | 1839.61 | 250.524 |
| linux / wasm-gc | **89.468** | 90.073 | 160.322 | 821.552 | 723.719 | 205.91 |
| linux / js | 508.542 | 493.496 | **304.258** | 667.064 | 1765.192 | 1057.756 |
| macos / native | 48.947 | **31.567** | 75.694 | 1708.094 | 550.934 | 137.522 |
| macos / wasm | 128.56* | **89.999** | 276.005 | 4139.162 | 1622.498 | 219.049 |
| macos / wasm-gc | 88.447 | **86.696** | 170.21 | 988.322 | 663.316 | 173.368 |
| macos / js | 474.483* | 403.833 | **286.556** | 578.27 | 1628.937 | 1104.555 |
| windows / native | **118.085** | 142.153 | 167.495* | 4288.956 | 1259.379 | 217.939* |
| windows / wasm | 99.932 | **93.119*** | 176.283 | 4011.45* | 1521.128 | 150.424 |
| windows / wasm-gc | 64.256 | 63.939 | **62.197** | 632.986 | 606.858 | 112.174 |
| windows / js | 398.468 | 412.076 | **204.798*** | 535.974 | 1522.07 | 1036.821 |

## Hyphenated bytes: offset-1 parsing (ns)

| OS / backend | ours scalar | ours SIMD request |
| --- | --- | --- |
| linux / native | 40.246 | **36.229** |
| linux / wasm | 129.736 | **94.465** |
| linux / wasm-gc | 91.147 | **90.535** |
| linux / js | 434.67 | **430.096** |
| macos / native | 38.56 | **27.83** |
| macos / wasm | 110.151 | **102.117** |
| macos / wasm-gc | 81.246 | **79.726** |
| macos / js | 427.631 | **374.808** |
| windows / native | **96.621** | 116.184 |
| windows / wasm | **82.345** | 97.224* |
| windows / wasm-gc | 61.454 | **61.399** |
| windows / js | **369.724** | 381.05 |

## Reusable output buffer: offset-1 hyphenated write (ns)

| OS / backend | ours scalar | ours SIMD request |
| --- | --- | --- |
| linux / native | 46.47 | **24.704** |
| linux / wasm | 155.213 | **53.22** |
| linux / wasm-gc | 89.971 | **89.943** |
| linux / js | 813.48 | **799.083** |
| macos / native | 45.362 | **22.607** |
| macos / wasm | 139.404 | **66.788** |
| macos / wasm-gc | 97.701 | **90.316** |
| macos / js | 803.847 | **707.6** |
| windows / native | 99.875* | **84.727** |
| windows / wasm | 91.134 | **60.669*** |
| windows / wasm-gc | **61.733** | 62.561 |
| windows / js | **763.57** | 790.38 |

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
