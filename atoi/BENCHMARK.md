# Decimal integer performance comparison

[CI run 45536066680](https://github.com/justjavac/moonbit-simd/actions/runs/45536066680) | [source 10d48a2](https://github.com/justjavac/moonbit-simd/commit/10d48a228cc58d668af857c24dc79a782b4d6f55) | attempt 1

**Scope:** 3 OS x 4 backends x 176 cases = **2112 measurements**. [BENCHMARK-DATA.json](BENCHMARK-DATA.json) preserves every unrounded statistic, case, offset, command, timestamp, source/run/attempt, dependency version, CPU, runner image, and toolchain.

**Speedups:** `SIMD speedup` = scalar mean / SIMD-request mean; `Best ours vs ref` = fastest reference mean / fastest shown `ours` mean. Ratios use unrounded latencies within each OS/backend: above 1 is faster, below 1 is slower. `*` marks CV >= 5% in either measurement. The best measured path can differ from automatic dispatch; a SIMD request can use scalar fallback.

## Vector gains within this library

Ratios divide scalar latency by SIMD-request latency for the same public operation. Ratios above one favor the SIMD request.

| OS / backend | UInt64, 16 digits | UInt128, maximum |
| --- | --- | --- |
| linux / native | 1.134x | 1.207x |
| linux / wasm | 1.111x | 1.149x |
| macos / native | 0.971x* | 1.395x* |
| macos / wasm | 1.21x* | 1.02x* |
| windows / native | 1.107x | 1.14x |
| windows / wasm | 1.014x | 1.071x |

Core comparisons also include required UTF-8 conversion, different integer representation, prefix adaptation, and range checks. They do not isolate vector gains. **Bold** marks the best mean; `*` marks CV >= 5% and possible noise. A best mean does not establish statistical significance.

## One digit UInt64 (ns)

| OS / backend | ours scalar | ours SIMD request | core integer + UTF-8 | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: |
| linux / native | 80.741 | 81.511 | **72.968** | 0.991x | 0.904x |
| linux / wasm | 274.783 | 236.85 | **207.086** | 1.16x | 0.874x |
| linux / wasm-gc | 91.059 | 91.291 | **85.774** | 0.997x | 0.942x |
| linux / js | 122.272 | **114.471** | 305.746 | 1.068x | 2.671x |
| macos / native | 78.305* | 80.852* | **61.525*** | 0.969x* | 0.786x* |
| macos / wasm | 274.177* | 261.272* | **216.152*** | 1.049x* | 0.827x* |
| macos / wasm-gc | **66.84*** | 92.173* | 90.413* | 0.725x* | 1.353x* |
| macos / js | **90.121*** | 101.449* | 235.513* | 0.888x* | 2.613x* |
| windows / native | 290.66 | 291.171 | **210.759** | 0.998x | 0.725x |
| windows / wasm | 199.803* | 178.816* | **149.638** | 1.117x* | 0.837x* |
| windows / wasm-gc | **46.758** | 51.422* | 52.586 | 0.909x* | 1.125x |
| windows / js | 91.932 | **88.891** | 196.324 | 1.034x | 2.209x |

## Sixteen digit UInt64 (ns)

| OS / backend | ours scalar | ours SIMD request | core integer + UTF-8 | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: |
| linux / native | 94.963 | **83.737** | 212.624 | 1.134x | 2.539x |
| linux / wasm | 369.41 | **332.479** | 814.869 | 1.111x | 2.451x |
| linux / wasm-gc | **120.98** | 121.097 | 361.2 | 0.999x | 2.986x |
| linux / js | **356.658** | 357.959 | 904.468 | 0.996x | 2.536x |
| macos / native | **71.872** | 73.982* | 142.01 | 0.971x* | 1.976x |
| macos / wasm | 391.3* | **323.475*** | 690.003* | 1.21x* | 2.133x* |
| macos / wasm-gc | 194.862* | **148.834*** | 399.15* | 1.309x* | 2.682x* |
| macos / js | **358.018*** | 374.731* | 856.437* | 0.955x* | 2.392x* |
| windows / native | 333.216 | **300.888** | 393.492 | 1.107x | 1.308x |
| windows / wasm | 265.854 | **262.298** | 669.486 | 1.014x | 2.552x |
| windows / wasm-gc | **67.227*** | 143.307* | 405.217* | 0.469x* | 6.028x* |
| windows / js | 326.098* | **324.359** | 700.472* | 1.005x* | 2.16x* |

## Minimum Int64 (ns)

| OS / backend | ours scalar | ours SIMD request | core integer + UTF-8 | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: |
| linux / native | 117.037 | **102.86** | 241.306 | 1.138x | 2.346x |
| linux / wasm | 443.156* | **391.65** | 1079.066 | 1.132x* | 2.755x |
| linux / wasm-gc | 130.033 | **128.846** | 439.345 | 1.009x | 3.41x |
| linux / js | **506.439** | 507.082 | 933.861 | 0.999x | 1.844x |
| macos / native | **104.06*** | 130.315* | 286.27* | 0.799x* | 2.751x* |
| macos / wasm | **409.585*** | 414.035* | 892.828* | 0.989x* | 2.18x* |
| macos / wasm-gc | **143.59*** | 525.905* | 548.386* | 0.273x* | 3.819x* |
| macos / js | **466.202*** | 544.335* | 1160.063* | 0.856x* | 2.488x* |
| windows / native | 377.475 | **339.106** | 492.045* | 1.113x | 1.451x* |
| windows / wasm | 293.38 | **272.808** | 766.701 | 1.075x | 2.81x |
| windows / wasm-gc | **76.256** | 77.904* | 311.315 | 0.979x* | 4.082x |
| windows / js | 420.224 | **416.621** | 723.207 | 1.009x | 1.736x |

## Maximum UInt128 (ns)

| OS / backend | ours scalar | ours SIMD request | core bounded BigInt + UTF-8 | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: |
| linux / native | 226.069 | **187.291** | 324.966 | 1.207x | 1.735x |
| linux / wasm | 611.935 | **532.467** | 1020.558 | 1.149x | 1.917x |
| linux / wasm-gc | 206.744 | **205.714** | 284.88 | 1.005x | 1.385x |
| linux / js | 1234.096 | 1223.585 | **411.051** | 1.009x | 0.336x |
| macos / native | 229.488* | **164.526*** | 363.879* | 1.395x* | 2.212x* |
| macos / wasm | 642.451* | **630.088*** | 1163.193* | 1.02x* | 1.846x* |
| macos / wasm-gc | 267.769* | **229.13*** | 305.561* | 1.169x* | 1.334x* |
| macos / js | 1197.188* | 1227.195* | **310.312*** | 0.976x* | 0.259x* |
| windows / native | 664.448 | **582.976** | 884.431 | 1.14x | 1.517x |
| windows / wasm | 416.278 | **388.707** | 696.742 | 1.071x | 1.792x |
| windows / wasm-gc | 127.649* | **114.383** | 184.209* | 1.116x* | 1.61x* |
| windows / js | 911.332 | 928.908* | **283.238** | 0.981x* | 0.311x |

## UInt64 prefix with suffix (ns)

| OS / backend | ours scalar | ours SIMD request | core integer + UTF-8 | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: |
| linux / native | 86.391 | **75.022** | 215.291 | 1.152x | 2.87x |
| linux / wasm | 274.047 | **248.342** | 815.458 | 1.104x | 3.284x |
| linux / wasm-gc | **106.474** | 106.931 | 383.641 | 0.996x | 3.603x |
| linux / js | 361.994 | **360.402** | 1032.605 | 1.004x | 2.865x |
| macos / native | 63.274 | **63.192*** | 158.133* | 1.001x* | 2.502x* |
| macos / wasm | 290.612* | **274.652*** | 858.021* | 1.058x* | 3.124x* |
| macos / wasm-gc | **131.193*** | 138.297* | 383.365* | 0.949x* | 2.922x* |
| macos / js | 387.609* | **256.809*** | 688.003 | 1.509x* | 2.679x* |
| windows / native | 304.537* | **260.944** | 407.629 | 1.167x* | 1.562x |
| windows / wasm | 190.792 | **168.941*** | 688.133* | 1.129x* | 4.073x* |
| windows / wasm-gc | **60.519** | 62.993 | 291.469 | 0.961x | 4.816x |
| windows / js | 320.154* | **298.539** | 890.873* | 1.072x* | 2.984x* |

## Early rejection of 64 KiB nonzero UInt32 input (us)

| OS / backend | ours scalar | ours SIMD request | core integer + UTF-8 | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: |
| linux / native | 0.078 | **0.071** | 8.017 | 1.101x | 113.379x |
| linux / wasm | 0.226 | **0.194** | 12.221 | 1.163x | 62.846x |
| linux / wasm-gc | 0.098 | **0.097** | 206.429 | 1.001x | 2117.922x |
| linux / js | **0.437** | 0.437 | 5.896* | 0.998x | 13.507x* |
| macos / native | 0.086* | **0.076*** | 11.468* | 1.143x* | 151.814x* |
| macos / wasm | 0.233* | **0.228*** | 20.733* | 1.023x* | 91.008x* |
| macos / wasm-gc | 0.122* | **0.122*** | 185.805* | 1x* | 1524.345x* |
| macos / js | 0.276* | **0.264*** | 4.011* | 1.048x* | 15.199x* |
| windows / native | 0.254 | **0.213** | 142.812 | 1.191x | 669.852x |
| windows / wasm | 0.156 | **0.133** | 11.421 | 1.172x | 85.851x |
| windows / wasm-gc | 0.058 | **0.057** | 187.154 | 1.018x | 3288.839x |
| windows / js | 0.355* | **0.336*** | 4.752 | 1.058x* | 14.15x* |

## One MiB leading zeroes, complete parse (GiB/s)

| OS / backend | ours scalar | ours SIMD request | core integer + UTF-8 | SIMD speedup | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: | ---: |
| linux / native | **11.834** | 11.825 | 0.122 | 0.999x | 96.908x |
| linux / wasm | 5.656 | **5.661** | 0.021 | 1.001x | 269.864x |
| linux / wasm-gc | 1.53 | **1.532** | 0.049* | 1.001x | 31.44x* |
| linux / js | **2.163** | 2.149 | 0.023 | 0.994x | 93.769x |
| macos / native | 8.019* | **8.695** | 0.149* | 1.084x* | 58.498x* |
| macos / wasm | **2.318*** | 2.123* | 0.029* | 0.916x* | 81.035x* |
| macos / wasm-gc | 0.598* | **0.657*** | 0.042* | 1.099x* | 15.819x* |
| macos / js | 2.437* | **2.834** | 0.024* | 1.163x* | 120.17x* |
| windows / native | 6.011 | **6.022** | 0.073 | 1.002x | 81.96x |
| windows / wasm | **7.397** | 7.389 | 0.029 | 0.999x | 258.354x |
| windows / wasm-gc | 1.925 | **1.941** | 0.063 | 1.009x | 30.753x |
| windows / js | **2.481*** | 2.411* | 0.027* | 0.972x* | 92.348x* |

## APIs and method

- Decimal base ten. Tests check identical returned values, consumed prefix sizes, and accepted/rejected corpus cases before timing. Full and prefix parsing are separate workloads. An excessive-size workload measures only this library because core has no matching digit budget.
- Owned byte inputs, partial-view buffers, and rejected sentinels are prepared outside timing. Offsets 1, 3, and 15 exercise selected boundaries. Public calls, optional-result adaptation, generic callback dispatch, and bench.keep barriers are timed; decimal result formatting is confined to equivalence tests.
- Core string parsers require strict UTF-8-to-UTF-16 conversion. Its missing prefix API uses a per-byte ASCII scan; an enabled leading plus is removed for the BigInt parser while preserving consumption. Core BigInt is explicitly range-checked for signed/unsigned 128-bit results. These required costs remain in the timer.
- Scalar requests use upstream-derived eight-byte SWAR masks and decimal reduction, with byte-wise tails. SIMD requests use bounded V128 range masks and a 16-to-8-to-4-to-2-to-1 decimal reduction tree on native and linear-memory Wasm. Inputs below sixteen bytes and Wasm GC/JavaScript use scalar/SWAR fallback. Vector loads stay inside the input view.
- Prefix, invalid-input, overflow, and size workloads report latency rather than whole-buffer throughput. The one MiB zero case reads the whole input before returning zero with skip_zeroes=true. UInt128/Int128 use exact private UInt64 word pairs and checked base-2^32 carries.
- Release mode and --no-parallelize, with backends measured sequentially on each OS. The core runner calibrates around 100 ms, records 10 batch samples, and applies 5% winsorization; fast cases use 100000 iterations per batch. Every case retains runs and batch_size.

Leading-zero removal uses the measured SWAR path for both requests; an all-zero input can remain entirely scalar/SWAR with simd=true. The earlier local vector zero scan was slower on native and Wasm. Wide core range bounds are initialized outside timed callbacks, while their comparisons remain timed.

Port: [atoi_simd 0.18.1](https://crates.io/crates/atoi_simd/0.18.1), revision `f0952f7bb71ee581dcc2871841f9b2dbd241bd7e`, under its MIT option. Rust is an external correctness oracle and is not linked into or timed with the MoonBit library.

<details>
<summary>Dependencies, runners, commands, and reproduction</summary>

| Package | Version | License |
| --- | --- | --- |
| moonbitlang/core/string | moonc v0.10.22+7b085e9a4-nightly (2026-11-22) | Apache-2.0 |
| moonbitlang/core/encoding/utf8 | moonc v0.10.22+7b085e9a4-nightly (2026-11-22) | Apache-2.0 |
| moonbitlang/core/bigint | moonc v0.10.22+7b085e9a4-nightly (2026-11-22) | Apache-2.0 |

| OS | CPU | Architecture | Runner image |
| --- | --- | --- | --- |
| linux | AMD EPYC 7763 64-Core Processor | x86_64 | ubuntu26 20261116.202.1 |
| macos | Apple M1 (Virtual) | arm64 | macos15 20261118.0550.1 |
| windows | INTEL(R) XEON(R) PLATINUM 8573C | AMD64 | win25-vs2026 20261116.315.1 |

**linux:**

~~~text
moon 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moon
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) ~/.moon/bin/moonc
moonrun 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moonrun
~~~

native: 2026-11-25T02:53:44Z to 2026-11-25T02:55:12Z (UTC).

~~~text
moon -C benchmarks bench --target native --release --no-parallelize -p justjavac/benchmarks/atoi
~~~

wasm: 2026-11-25T02:55:12Z to 2026-11-25T02:57:40Z (UTC).

~~~text
moon -C benchmarks bench --target wasm --release --no-parallelize -p justjavac/benchmarks/atoi
~~~

wasm-gc: 2026-11-25T02:57:40Z to 2026-11-25T02:59:09Z (UTC).

~~~text
moon -C benchmarks bench --target wasm-gc --release --no-parallelize -p justjavac/benchmarks/atoi
~~~

js: 2026-11-25T02:59:09Z to 2026-11-25T03:01:48Z (UTC).

~~~text
moon -C benchmarks bench --target js --release --no-parallelize -p justjavac/benchmarks/atoi
~~~


**macos:**

~~~text
moon 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moon
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) ~/.moon/bin/moonc
moonrun 0.1.20261120 (aaf8010 2026-11-20) ~/.moon/bin/moonrun
~~~

native: 2026-11-25T02:53:59Z to 2026-11-25T02:55:27Z (UTC).

~~~text
moon -C benchmarks bench --target native --release --no-parallelize -p justjavac/benchmarks/atoi
~~~

wasm: 2026-11-25T02:55:27Z to 2026-11-25T02:57:58Z (UTC).

~~~text
moon -C benchmarks bench --target wasm --release --no-parallelize -p justjavac/benchmarks/atoi
~~~

wasm-gc: 2026-11-25T02:57:58Z to 2026-11-25T02:59:32Z (UTC).

~~~text
moon -C benchmarks bench --target wasm-gc --release --no-parallelize -p justjavac/benchmarks/atoi
~~~

js: 2026-11-25T02:59:32Z to 2026-11-25T03:02:03Z (UTC).

~~~text
moon -C benchmarks bench --target js --release --no-parallelize -p justjavac/benchmarks/atoi
~~~


**windows:**

~~~text
moon 0.1.20261120 (aaf8010 2026-11-20) ~\.moon\bin\moon.exe
moonc v0.10.22+7b085e9a4-nightly (2026-11-22) ~\.moon\bin\moonc.exe
moonrun 0.1.20261120 (aaf8010 2026-11-20) ~\.moon\bin\moonrun.exe
~~~

native: 2026-11-25T02:54:13Z to 2026-11-25T02:56:34Z (UTC).

~~~text
moon -C benchmarks bench --target native --release --no-parallelize -p justjavac/benchmarks/atoi
~~~

wasm: 2026-11-25T02:56:34Z to 2026-11-25T02:58:38Z (UTC).

~~~text
moon -C benchmarks bench --target wasm --release --no-parallelize -p justjavac/benchmarks/atoi
~~~

wasm-gc: 2026-11-25T02:58:38Z to 2026-11-25T02:59:59Z (UTC).

~~~text
moon -C benchmarks bench --target wasm-gc --release --no-parallelize -p justjavac/benchmarks/atoi
~~~

js: 2026-11-25T02:59:59Z to 2026-11-25T03:02:21Z (UTC).

~~~text
moon -C benchmarks bench --target js --release --no-parallelize -p justjavac/benchmarks/atoi
~~~

Run `moon -C benchmarks test atoi --target all`, then `moon run scripts/benchmark.mbtx atoi`. Local rendering uses `moon run scripts/benchmark_report.mbtx --local atoi _build/benchmarks/atoi/windows.json _build/atoi-report`. Publish only a complete three-OS/four-backend CI snapshot with identical source, run, attempt, manifests, and dependencies; the validator rejects mixed or partial data. Raw CI logs are retained for 90 days.

</details>
