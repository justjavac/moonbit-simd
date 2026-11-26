# Word count benchmarks

`BENCHMARK-DATA.json` is reserved for a complete Windows, Linux, and macOS
snapshot with all four backends from one CI run and attempt. The commands
below also generate an explicitly local report from the available backends.

## Workloads

| Case | Bytes | View offset | Stream chunk bytes |
| --- | ---: | ---: | ---: |
| Short text | 13 | 0 | Whole input |
| Unaligned text | 33 | 3 | Whole input |
| Repeated ASCII text | 4096 | 0 | Whole input |
| Mixed binary | 65539 | 1 | Whole input |
| Small streamed text | 4096 | 0 | 63 |
| Large streamed text | 1048576 | 0 | 8192 |

The 18 cases per backend compare `own-scalar`, `own-simd`, and `reference`.
The independent MoonBit reference counts word ends with an explicit separator
set. All variants return the same three totals for identical inputs and chunk
schedules. The timed code calls the public API or the reference and keeps the
result observable. Streaming includes counter creation, successive updates, and
reading the final totals. Input construction, slicing, and reference checks
happen before timing. The benchmark compares in-memory scans against the
MoonBit reference. [Upstream fastlwc](https://github.com/expr-fi/fastlwc)
documents its own file-based measurements.

Short cases report nanoseconds per invocation. Larger cases report GiB/s
from the number of bytes consumed. The core runner uses microsecond timings,
ten batch samples, and 5% winsorization. The report marks CV ≥ 5% with `*`.

## Local results

The 1 MiB stream with 8 KiB chunks reached these throughputs in local release
runs on Linux x86-64, Intel Core i7-13650HX, `moon 0.1.20261120` and
`moonc v0.10.22+7b085e9a4-nightly`. Each backend measured both implementations
in one process and then repeated the measurements in reverse order.

| Backend | Order | Scalar GiB/s | SIMD GiB/s |
| --- | --- | ---: | ---: |
| native | Forward | 1.429 | 4.348 |
| native | Reversed | 1.307 | 4.084 |
| wasm | Forward | 0.827 | 9.802 |
| wasm | Reversed | 0.796 | 9.178 |

Wasm GC and JavaScript complete the four-backend local run with scalar code
for both requests.

## Reproduce

```text
moon -C benchmarks test wc --target all
moon run scripts/benchmark.mbtx wc
moon run scripts/benchmark_report.mbtx --local wc _build/benchmarks/wc/linux.json _build/wc-report
moon run scripts/benchmark_report.mbtx --self-test
```

Use the corresponding OS filename when running on macOS or Windows. Set
`WC_BENCHMARK_REVERSE=1` to record the reversed implementation order and
`BENCHMARK_BACKENDS=native,wasm` to restrict a local run to vector backends.
The collector and report validator check the exact workloads and offsets,
sample counts, timing ranges, upstream pin, and CI provenance. The workflow
runs backends sequentially within each OS and retains raw artifacts for 90 days.
