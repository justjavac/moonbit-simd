# Decimal integer performance comparison

[CI run 45536066680](https://github.com/justjavac/moonbit-simd/actions/runs/45536066680) | [source 10d48a2](https://github.com/justjavac/moonbit-simd/commit/10d48a228cc58d668af857c24dc79a782b4d6f55) | attempt 1

**Scope:** 3 OS x 4 backends x 176 cases = **2112 measurements**. [BENCHMARK-DATA.json](BENCHMARK-DATA.json) preserves every unrounded statistic, case, offset, command, timestamp, source/run/attempt, dependency version, CPU, runner image, and toolchain.

## Vector gains within this library

Ratios divide scalar latency by SIMD-request latency for the same public operation. Ratios above one favor the SIMD request.

| OS / backend | UInt64, 16 digits | UInt128, maximum |
| --- | --- | --- |
| linux / native | 1.134x | 1.207x |
| linux / wasm | 1.111x | 1.149x |
| macos / native | 0.971x | 1.395x |
| macos / wasm | 1.21x | 1.02x |
| windows / native | 1.107x | 1.14x |
| windows / wasm | 1.014x | 1.071x |

Core comparisons also include required UTF-8 conversion, different integer representation, prefix adaptation, and range checks. They do not isolate vector gains. **Bold** marks the best mean; `*` marks CV >= 5% and possible noise. A best mean does not establish statistical significance.

## One digit UInt64 (ns)

| OS / backend | ours scalar | ours SIMD request | core integer + UTF-8 |
| --- | --- | --- | --- |
| linux / native | 80.741 | 81.511 | **72.968** |
| linux / wasm | 274.783 | 236.85 | **207.086** |
| linux / wasm-gc | 91.059 | 91.291 | **85.774** |
| linux / js | 122.272 | **114.471** | 305.746 |
| macos / native | 78.305* | 80.852* | **61.525*** |
| macos / wasm | 274.177* | 261.272* | **216.152*** |
| macos / wasm-gc | **66.84*** | 92.173* | 90.413* |
| macos / js | **90.121*** | 101.449* | 235.513* |
| windows / native | 290.66 | 291.171 | **210.759** |
| windows / wasm | 199.803* | 178.816* | **149.638** |
| windows / wasm-gc | **46.758** | 51.422* | 52.586 |
| windows / js | 91.932 | **88.891** | 196.324 |

## Sixteen digit UInt64 (ns)

| OS / backend | ours scalar | ours SIMD request | core integer + UTF-8 |
| --- | --- | --- | --- |
| linux / native | 94.963 | **83.737** | 212.624 |
| linux / wasm | 369.41 | **332.479** | 814.869 |
| linux / wasm-gc | **120.98** | 121.097 | 361.2 |
| linux / js | **356.658** | 357.959 | 904.468 |
| macos / native | **71.872** | 73.982* | 142.01 |
| macos / wasm | 391.3* | **323.475*** | 690.003* |
| macos / wasm-gc | 194.862* | **148.834*** | 399.15* |
| macos / js | **358.018*** | 374.731* | 856.437* |
| windows / native | 333.216 | **300.888** | 393.492 |
| windows / wasm | 265.854 | **262.298** | 669.486 |
| windows / wasm-gc | **67.227*** | 143.307* | 405.217* |
| windows / js | 326.098* | **324.359** | 700.472* |

## Minimum Int64 (ns)

| OS / backend | ours scalar | ours SIMD request | core integer + UTF-8 |
| --- | --- | --- | --- |
| linux / native | 117.037 | **102.86** | 241.306 |
| linux / wasm | 443.156* | **391.65** | 1079.066 |
| linux / wasm-gc | 130.033 | **128.846** | 439.345 |
| linux / js | **506.439** | 507.082 | 933.861 |
| macos / native | **104.06*** | 130.315* | 286.27* |
| macos / wasm | **409.585*** | 414.035* | 892.828* |
| macos / wasm-gc | **143.59*** | 525.905* | 548.386* |
| macos / js | **466.202*** | 544.335* | 1160.063* |
| windows / native | 377.475 | **339.106** | 492.045* |
| windows / wasm | 293.38 | **272.808** | 766.701 |
| windows / wasm-gc | **76.256** | 77.904* | 311.315 |
| windows / js | 420.224 | **416.621** | 723.207 |

## Maximum UInt128 (ns)

| OS / backend | ours scalar | ours SIMD request | core bounded BigInt + UTF-8 |
| --- | --- | --- | --- |
| linux / native | 226.069 | **187.291** | 324.966 |
| linux / wasm | 611.935 | **532.467** | 1020.558 |
| linux / wasm-gc | 206.744 | **205.714** | 284.88 |
| linux / js | 1234.096 | 1223.585 | **411.051** |
| macos / native | 229.488* | **164.526*** | 363.879* |
| macos / wasm | 642.451* | **630.088*** | 1163.193* |
| macos / wasm-gc | 267.769* | **229.13*** | 305.561* |
| macos / js | 1197.188* | 1227.195* | **310.312*** |
| windows / native | 664.448 | **582.976** | 884.431 |
| windows / wasm | 416.278 | **388.707** | 696.742 |
| windows / wasm-gc | 127.649* | **114.383** | 184.209* |
| windows / js | 911.332 | 928.908* | **283.238** |

## UInt64 prefix with suffix (ns)

| OS / backend | ours scalar | ours SIMD request | core integer + UTF-8 |
| --- | --- | --- | --- |
| linux / native | 86.391 | **75.022** | 215.291 |
| linux / wasm | 274.047 | **248.342** | 815.458 |
| linux / wasm-gc | **106.474** | 106.931 | 383.641 |
| linux / js | 361.994 | **360.402** | 1032.605 |
| macos / native | 63.274 | **63.192*** | 158.133* |
| macos / wasm | 290.612* | **274.652*** | 858.021* |
| macos / wasm-gc | **131.193*** | 138.297* | 383.365* |
| macos / js | 387.609* | **256.809*** | 688.003 |
| windows / native | 304.537* | **260.944** | 407.629 |
| windows / wasm | 190.792 | **168.941*** | 688.133* |
| windows / wasm-gc | **60.519** | 62.993 | 291.469 |
| windows / js | 320.154* | **298.539** | 890.873* |

## Early rejection of 64 KiB nonzero UInt32 input (us)

| OS / backend | ours scalar | ours SIMD request | core integer + UTF-8 |
| --- | --- | --- | --- |
| linux / native | 0.078 | **0.071** | 8.017 |
| linux / wasm | 0.226 | **0.194** | 12.221 |
| linux / wasm-gc | 0.098 | **0.097** | 206.429 |
| linux / js | **0.437** | 0.437 | 5.896* |
| macos / native | 0.086* | **0.076*** | 11.468* |
| macos / wasm | 0.233* | **0.228*** | 20.733* |
| macos / wasm-gc | 0.122* | **0.122*** | 185.805* |
| macos / js | 0.276* | **0.264*** | 4.011* |
| windows / native | 0.254 | **0.213** | 142.812 |
| windows / wasm | 0.156 | **0.133** | 11.421 |
| windows / wasm-gc | 0.058 | **0.057** | 187.154 |
| windows / js | 0.355* | **0.336*** | 4.752 |

## One MiB leading zeroes, complete parse (GiB/s)

| OS / backend | ours scalar | ours SIMD request | core integer + UTF-8 |
| --- | --- | --- | --- |
| linux / native | **11.834** | 11.825 | 0.122 |
| linux / wasm | 5.656 | **5.661** | 0.021 |
| linux / wasm-gc | 1.53 | **1.532** | 0.049* |
| linux / js | **2.163** | 2.149 | 0.023 |
| macos / native | 8.019* | **8.695** | 0.149* |
| macos / wasm | **2.318*** | 2.123* | 0.029* |
| macos / wasm-gc | 0.598* | **0.657*** | 0.042* |
| macos / js | 2.437* | **2.834** | 0.024* |
| windows / native | 6.011 | **6.022** | 0.073 |
| windows / wasm | **7.397** | 7.389 | 0.029 |
| windows / wasm-gc | 1.925 | **1.941** | 0.063 |
| windows / js | **2.481*** | 2.411* | 0.027* |

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
