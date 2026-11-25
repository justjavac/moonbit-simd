# UTF-8 performance comparison

The development-only [comparison package](../benchmarks/utf8) measures strict
UTF-8 validation and validation plus UTF-16 decoding against
`tonyfettes/utf8@0.2.4` and the bundled `moonbitlang/core/encoding/utf8`.

## Scope and adaptation

There are **158 cases per backend**: 90 validation/acceptance cases, 56 decoding
cases, and 12 streaming cases. Valid input covers empty and short ASCII, 64-byte
dispatch, 4 KiB ASCII/Latin/CJK/emoji/mixed text, and 1 MiB ASCII/CJK/emoji text.
Errors cover invalid first and last bytes, an overlong middle sequence, and an
incomplete final sequence. Selected 4 KiB cases additionally use offset-one
partial views, with rejected sentinel bytes outside the view. Stream chunks
are 1, 64, and 4096 bytes, prepared as owned input before timing.

| Label | API and timed adaptation |
| --- | --- |
| `own-basic-scalar` | `is_valid(simd=false)`, no decoding. |
| `own-basic-simd` | `is_valid(simd=true)`, vector basic or documented fallback. |
| `own-compat` | `validate(simd=true)`, including precise error recovery. |
| `tonyfettes` validation | `Utf8.of_bytesview`, including wrapper creation and partial-view materialization. |
| `core` validation | Strict `decode(ignore_bom=false)`, including necessary UTF-16 allocation. |
| `own-scalar` / `own-simd` decoding | `from_utf8`, including validation and UTF-16 decoding. |
| `tonyfettes` / `core` decoding | Strict `decode`; core retains BOM to match other APIs. |

The tonyfettes release needs compatibility edits for removed MoonBit syntax and
JSON manifests. The pinned development copy, original source hash, license,
and exact changes are documented in
[UPSTREAM.md](../benchmarks/vendor/tonyfettes-utf8/UPSTREAM.md). Its validation
predicates and decoding formulas are preserved. Comparison adapters verify
identical acceptance and decoded text before measurement. Core exposes a
decoder rather than a standalone validator, so its acceptance baseline
includes additional work; the separate decoding tables compare the same final
UTF-16 output. Neither baseline is treated as a Rust borrowed-string API.

Native uses vector range checks with sign-flipped comparisons and `UInt64`
predecessor assembly; linear-memory Wasm retains lookup3. Both avoid view
overreads and use scalar tails. This backend choice follows measurements of
the whole validation operation: the initial native lookup translation incurred
large per-lane emulation costs in the validated x86 toolchain. The measured
native kernel avoids those shuffles, swizzles, and unsigned comparisons.

## Running and publishing

```text
moon -C benchmarks test utf8 --target all
moon run scripts/benchmark.mbtx utf8
moon run scripts/benchmark_report.mbtx --self-test
```

After collecting a local Windows run, render its verified comparison tables and
complete JSON with:

```text
moon run scripts/benchmark_report.mbtx --local utf8 _build/benchmarks/utf8/windows.json _build/utf8-report
```

This writes `_build/utf8-report/LOCAL-BENCHMARK.md` and
`LOCAL-BENCHMARK-DATA.json`, with local provenance and high-variation samples
explicitly identified. The published-report path continues to require a full
CI snapshot.

The collector runs `native`, `wasm`, `wasm-gc`, and `js` sequentially in release
mode with `--no-parallelize`, retaining full stdout/stderr and structured JSON
in `_build/benchmarks/utf8/`. Input construction is outside timing; public calls,
required conversions, state creation/finalization, callback dispatch, and
`bench.keep` barriers are inside. All adapters run in the same package on the
same runner. Streaming comparisons cover this module's scalar/SIMD requests;
the other libraries lack an equivalent arbitrary-chunk validator API.

The core runner records ten batch samples after roughly 100 ms calibration and
uses 5% winsorization. Submicrosecond operations use 100000 iterations per
batch. Times are microseconds per invocation; nanoseconds multiply by 1000,
and GiB/s is `bytes * 1e6 / mean_us / 2^30`. Invalid-input throughput is omitted
because early-failure adapters read different portions of the supplied input.
CV >= 5% marks possible noise; a smaller mean alone does not prove significance.

CI is configured for three systems by four backends. A published
`BENCHMARK-DATA.json` must be generated from one complete CI run with the same
source revision, attempt, dependency versions, and all 158 cases per backend.
Local measurements remain explicitly local in ignored build artifacts. No
complete CI snapshot has been selected for this initial source migration.
