# Byte and UTF-8 code point count benchmarks

The 30-case suite measures all bytes in six prepared views per backend, from
7 bytes to 1 MiB. It compares `count` and `num_chars` against their public
per-byte counterparts. The byte-match comparison also includes
`justjavac/memchr` 0.1.0, with cursor construction inside the timer.
The inputs repeat UTF-8 text and include offset-3 and offset-1 views.

```text
moon -C benchmarks test bytecount --target all
moon run scripts/benchmark.mbtx bytecount
moon run scripts/benchmark_report.mbtx --local bytecount _build/benchmarks/bytecount/linux.json _build/bytecount-report
```

Set `BYTECOUNT_BENCHMARK_REVERSE=1` to reverse measurement order.
The collector uses release mode and measures each backend sequentially.
The report marks a coefficient of variation of at least 5% with `*`.

## Local Linux results

The table shows speedup ranges from forward and reversed measurements of the
same 1 MiB view at offset 1. Each ratio is the comparison mean divided by the
dispatched mean. An asterisk marks CV >= 5% in at least one paired measure.

| Backend | `count` vs. `naive_count` | `num_chars` vs. `naive_num_chars` | `count` vs. memchr |
| --- | ---: | ---: | ---: |
| Native | 8.93–9.60×* | 14.76–15.10×* | 5.35–5.46×* |
| Wasm | 18.28–19.87×* | 16.67–18.88×* | 1.71–1.76×* |
| Wasm GC | 1.16–1.30×* | 1.46–1.81×* | 1.08–1.21×* |
| JavaScript | 1.16–1.17× | Same byte loop | 1.87–2.10× |

Measured on Linux x86-64 with an Intel Core i7-13650HX, Moon
`0.1.20261126`, moonc `v1.0.0-rc1+546870549-nightly`, and Node.js
`24.18.0`. The collector keeps both sets of local JSON and raw logs in
`_build/benchmarks/bytecount/`.
