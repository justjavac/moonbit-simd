# StringZilla UTF-16 performance

The comparison measures matching `StringView` APIs from this module and
bundled `moonbitlang/core`. StringZilla v5.3.2 provides the source algorithms.
The upstream byte-oriented C library uses a different representation.

## Workloads

There are 20 cases per backend, two implementations for each of the following
public operations.

| Workload | UTF-16 code units | Contents |
| --- | ---: | --- |
| Short forward search | 15 | Two-unit needle near the end. |
| Forward and reverse long search | 65,536 | A four-unit needle with a supplementary character, found at the last candidate in the selected direction. |
| Forward and reverse periodic miss | 4,096 | A 65-unit needle with a rare unit near its start. |
| Forward code-unit hit and reverse miss | 4,096 | A non-ASCII hit at the end and an excluded backing-string sentinel. |
| Equality | 65,536 | Identical mixed text in different backing strings. |
| Split and replacement | 4,096 | Three ASCII fields and two separators. |

Both implementations receive the same prepared views with offsets 0, 1, or
3 code units. JSON distinguishes view length in code units, UTF-16 storage
bytes, and UTF-8 encoded bytes. Timed callbacks include public calls, complete
split iterator consumption, replacement result construction, and keep
barriers. Searches are reported as latency per invocation.

## Local Linux measurements

Release runs on Linux x86-64 used an Intel Core i7-13650HX, Moon `0.1.20261126`,
and `moonc v1.0.0-rc1+546870549-nightly`. A focused comparison measured the
previous 16-candidate search, the current search, and core on the same
prepared views, with forward and reversed measurement orders in one process.
Each case took ten batch samples. Ratios divide each baseline mean by the
current mean. `*` marks CV ≥5% in at least one measurement for the ratio.

| Forward workload | Native vs previous | Native vs core | Wasm vs previous | Wasm vs core |
| --- | ---: | ---: | ---: | ---: |
| Late hit, 65,536 units | 1.29–1.31× | 1.27–1.29× | 1.79–1.87×* | 1.54–1.55×* |
| Periodic miss, 4,096 units | 1.16–1.19× | 34.61–34.73× | 1.48–1.54× | 30.16–31.75× |
| Mixed UTF-16 miss, 65,000 units | 1.27–1.30× | 0.54× | 1.71–1.77× | 0.38× |
| Two-unit needle, 24-unit view | 1.59–1.84× | 0.79–0.88× | 2.07–2.22×* | 0.82–0.93×* |

The periodic miss has a rare unit near the beginning of the needle, which
the third probe detects. Core leads on the mixed UTF-16 miss and the short
workload. The search that exhausts the verification budget ran within 4%
of the earlier implementation on both backends.

## Reproduction

```text
moon -C benchmarks test string --target all
moon run scripts/benchmark.mbtx string
moon run scripts/benchmark_report.mbtx --local string _build/benchmarks/string/linux.json _build/string-report
```

Set `STRING_BENCHMARK_REVERSE=1` to measure core first. The collector preserves
independent logs and reports for each order. The benchmark runner uses release
mode, 10 batch samples, and sequential backends. A CV of 5% or higher
indicates possible noise. Publication requires one complete CI snapshot for
the three operating systems and four backends.
