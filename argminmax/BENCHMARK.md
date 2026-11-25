# ArgMinMax performance comparison

The development-only [comparison package](../benchmarks/argminmax) measures
162 cases per backend against an independent linear MoonBit reference. All
fourteen numeric kinds use identical prepared values. The Rust source is pinned
to `argminmax@0.7.1`, revision `f68aba5c251e9dc093f3939c0f9607c942228311`;
the Rust crate is not timed across languages.

## Dispatch and measured work

The scalar scan caches extrema values. Automatic searches select it on native,
Wasm GC, JavaScript, and unmeasured element types. On linear-memory Wasm,
unmasked, NaN-ignoring `Float` and `Double` searches of at least 4096 elements use vectors.
Explicit `simd=true` retains portable 8–64-bit vector requests on native/Wasm,
with short-input, 128-bit, and unsupported-backend scalar fallbacks.

This policy follows local Windows probes that measured both implementation
orders in the same process. Vector assembly must gather typed lanes because
the current bundled SIMD API does not load contiguous typed array views.
The complete public operation is measured, including gathers and index
reduction. Native scalar caching improved this comparison substantially;
Rust's advertised SIMD ratios do not describe this MoonBit implementation.
Integer and NaN-propagating vector results varied across the complete corpus,
so their automatic searches remain scalar. Masked defaults use a direct scalar
scan and overflow-safe 32-bit byte/bit positioning; this removes repeated
JavaScript BigInt index arithmetic and per-run result allocation.

Cases cover 33 and 4096 elements of all types; empty input; 1,048,576-element
Int/Double arrays and offset-one views; single extrema; first/last NaNs under
both policies; dense/sparse/all-null bitmaps with offset three; and narrow index
boundaries through 131105 elements. Half/wide wrappers and bitmap generation
are outside timing. Public calls, bitmap validation, callback dispatch,
single-index result adapters, and `bench.keep` remain inside.

Case names record operation/kind, implementation, numeric bytes, and element
offset. Numeric byte widths are 1/2/4/8/16; wrapper object storage and bitmap
metadata are additional memory. NaN propagation and all-null cases have
different read lengths, so their reports use latency without nominal throughput.

## Local Windows measurements

On 2026-11-25, the complete local run recorded 648 measurements on an Intel
Core i7-13650HX with the documented nightly toolchain. Its recorded checkout
was `a39373237b2b2b8ee0d544a9cc9fa0282d2d5854`, with a dirty working tree.
These are local observations; `*` marks CV >= 5% and possible noise.

| 4096-element workload / backend | Scalar (us) | SIMD request (us) | Linear reference (us) |
| --- | --- | --- | --- |
| Float / Wasm | 32.948* | 20.745* | 35.102 |
| Double / Wasm | 31.898* | 27.791* | 32.950* |
| Double / native | 41.428* | 107.137* | 162.556* |
| Double, dense bitmap / JS | 60.204* | 61.520* | 51.273* |

The generated local report contains all four backends and the full input
inventory, with unrounded statistics in its companion JSON. The high variation
supports conservative automatic dispatch; these rows do not establish a
universal speedup or statistical significance.

A separate same-process JavaScript probe compared the previous scalar bitmap
algorithm with the new direct scan, using identical prepared Double values and
bitmaps. Both call the same unmasked scalar kernel where required. Public work,
bitmap validation, callback dispatch, and `bench.keep` are inside timing.

| Bitmap / measurement order | Previous scan (us) | Direct scan (us) |
| --- | --- | --- |
| Dense / previous first | 106.407 | 19.025 |
| Dense / direct first | 150.683* | 32.440* |
| Sparse / previous first | 335.437* | 27.506* |
| Sparse / direct first | 534.783* | 33.185* |

The direct scan avoids repeated wide index arithmetic and per-run allocation.
Both orders favor it on this corpus; variation prevents treating the exact
ratios as guarantees. The probe's source, raw log, and complete statistics are
local build artifacts under `_build/argminmax-bitmap-probe/`.

## Reproduction and publication

```text
moon -C benchmarks test argminmax --target all
moon run scripts/benchmark.mbtx argminmax
moon run scripts/benchmark_report.mbtx --self-test
moon run scripts/benchmark_report.mbtx --local argminmax _build/benchmarks/argminmax/windows.json _build/argminmax-report
```

The collector runs native, Wasm, Wasm GC, and JavaScript sequentially in release
mode with `--no-parallelize`. It retains stdout/stderr and structured summaries
in `_build/benchmarks/argminmax/`. The local renderer requires all four backends
and writes `LOCAL-BENCHMARK.md` and `LOCAL-BENCHMARK-DATA.json` into the specified
ignored build directory, preserving their local and dirty-checkout provenance.

Core times are microseconds per invocation; nanoseconds multiply by 1000.
Calibration targets about 100 ms, with ten batch samples and 5% winsorization.
Submicrosecond cases use 100000 iterations per batch. Reports retain every
unrounded statistic, quartile, sample count, command, timestamp, CPU, toolchain,
numeric width, and dependency. CV >= 5% marks possible noise; the smallest
mean alone does not establish significance.

CI is configured for three operating systems by four backends. The collector
and report validator independently verify the exact 162-case inventory,
distribution metadata, pinned upstream, and matching source manifests. Published
snapshots require a complete single CI run and attempt; raw artifacts are retained
for 90 days. No complete CI snapshot has been selected for this initial port.
