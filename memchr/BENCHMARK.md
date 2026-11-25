# Byte and substring search performance

The development-only [comparison adapters](../benchmarks/memchr) measure this
module's scalar and SIMD requests against independent per-byte search/count/
iteration references and bundled core `BytesView.find`/`rev_find`. Correctness
tests verify identical view-relative byte indices, counts, and iteration sums
before measurement. Rust memchr 2.8.3 supplies algorithm/fixture provenance and
is not timed across languages.

## Inventory and adaptation

There are **370 cases per backend**, with exact names independently validated
by the [collector](../scripts/benchmark.mbtx) and
[search report validator](../scripts/memchr_benchmark_report.mbtx).

| Group | Cases | Work measured |
| --- | ---: | --- |
| Byte scans | 220 | One/two/three-byte unions, both directions, absent/final matches, 0/15/65/4096/1048576 bytes, offsets 0/1/15. |
| Byte counting and iteration | 12 | Dense 64 KiB counts, dense/sparse 4 KiB cursor creation and complete consumption. |
| Substring search | 126 | One-off and reusable forward/reverse finders; 0/3/33/65/257-byte needles in 4–16384-byte haystacks, periodic misses, offsets 0/1/15. |
| Substring iteration | 12 | Directional non-overlap over 4 KiB input and every empty-needle byte boundary over 256 bytes. |

| Label | Timed API/adaptation |
| --- | --- |
| `own-scalar` | Public calls with `simd=false`; SWAR byte scans (per-byte on JavaScript) and scalar ranked-pair filtering. |
| `own-simd` | Public calls with `simd=true`; bounded sixteen-byte native/Wasm scans or documented scalar fallback. |
| `own-twoway` | Forward substring search with candidate filtering disabled. |
| `core` | `BytesView.find`/`rev_find` over the same byte/needle views. Available for single-byte and substring searches. |
| `reference` | Independent per-byte byte unions/counts and naive non-overlapping iteration. |

All immutable input bytes, needles, and partial views are prepared outside timed
callbacks. Partial views have matching NUL sentinel bytes outside their bounds.
Reusable finders are also prepared outside timing. One-off preprocessing, cursor
creation, lazy consumption, result/implementation adapters, callback dispatch,
and `bench.keep` barriers remain inside timing. No input encoding conversion or
view materialization is required by these APIs. Core has no explicit reusable
Finder, byte-union API, or matching iterator; its ordinary public search serves
both one-off and reuse search groups, with missing APIs compared to the independent
reference instead.

Search timings are nanoseconds per public invocation. Early matches and misses
can read different portions of the haystack; searches receive no input-throughput
estimate. Complete byte counts read all supplied bytes and report GiB/s. Iteration
is distinct from optimized counting and includes each public cursor step.

## Vector implementation and measurement

The initial pattern-based native scanner retained view/refcount bookkeeping
inside each vector iteration. Generated-loop inspection identified that cost.
The current implementation keeps the immutable backing buffer once and checks
the actual view length before each standard core V128 load. Scalar tails remain
bounded by the view. The same change applies to ranked-pair filtering and avoids
tail-result closure allocation. A local same-process comparison of original and
checked-load byte scans/counts, with both measurement orders, supported this
change; samples with CV >= 5% remain possible noise. These comparisons do not
establish a cross-system speedup or a universal SIMD cutoff.

Byte scans/counts use V128 on native/linear-memory Wasm for inputs of at least
sixteen bytes. Forward substring filtering needs sixteen complete candidate
starts, then exact Two-Way verification; its fifty-call budget preserves linear
behavior on adversarial pair collisions. Short input and Wasm GC/JavaScript use
scalar fallback. JavaScript uses per-byte scans after local measurements showed
the BigInt cost of UInt64 SWAR exceeded ordinary byte comparisons. Reverse
substring search uses Two-Way for needles longer than
one byte on every backend. Compare each library's whole scalar/SIMD public
operation before attributing a difference to vector instructions.

## Running and publication

```text
moon -C benchmarks check memchr --target all --deny-warn
moon -C benchmarks test memchr --target all
moon run scripts/benchmark.mbtx memchr
moon run scripts/benchmark_report.mbtx --self-test
```

The collector measures `native`, `wasm`, `wasm-gc`, and `js` sequentially in
release mode with `--no-parallelize`, retaining full stdout/stderr in
`_build/benchmarks/memchr/<OS>/<backend>.log`. It saves every structured summary,
UTC timestamps, CPU/architecture, runner image, actual toolchain/core version,
commands, manifests, source revision, upstream pin, needle lengths, view offsets,
and sample batch metadata. The stable `BENCHMARK_RESULTS ` marker supplies JSON;
rendered console tables are not parsed.

After collecting all four backends locally, render verified LOCAL-named artifacts:

```text
moon run scripts/benchmark_report.mbtx --local memchr _build/benchmarks/memchr/windows.json _build/memchr-report
```

For a long local run, `BENCHMARK_BACKENDS` can select one backend per invocation.
Each such memchr run saves an OS/backend JSON fragment. Merge only a verified
set of four local fragments before rendering:

```text
moon run scripts/memchr_benchmark_report.mbtx --merge-local _build/benchmarks/memchr windows
```

The merger checks identical source/manifest/dependency/runner metadata and rejects
duplicate or missing backends. A fragment cannot render as a complete report or
be published as CI data.

Core times are microseconds per invocation: nanoseconds multiply by 1000, and
GiB/s is `bytes * 1e6 / mean_us / 2^30`. The recorded runner calibrates near
100 ms, takes ten batch samples, and uses 5% winsorization. Submicrosecond cases
use 100000 iterations per batch. Raw statistics remain unrounded in JSON;
CV >= 5% marks possible noise and a bold best mean makes no significance claim.

CI is configured for three systems by four backends. A published
`BENCHMARK-DATA.json` requires **4440 measurements** from one complete CI source
commit, repository, run, attempt, manifest, and dependency set. The validator
rejects partial/mixed snapshots and changed case inventories or sampling data.
Raw CI artifacts are retained for 90 days. Local measurements remain in ignored
build artifacts; no complete CI snapshot has been selected for this initial port.
