# URL performance comparison

The first complete CI snapshot is pending. No local timings are presented as CI
results. The Benchmarks workflow measures native, Wasm, Wasm GC, and JavaScript
on Windows, Linux, and macOS and generates this report after all jobs succeed.

The suite compares `justjavac/url` scalar and SIMD requests with
`tonyfettes/url 0.3.5`, `moonbitstack/moonurl 0.3.1` in WHATWG mode, and
`connect0459/urllib 0.6.0`. It measures parse-only and parse-plus-serialization
on short/long ASCII, normalization, Unicode, IPs, files, credentials, offset
views, and relative references, plus decoded form-query roundtrips.

Run `moon -C benchmarks test --target all` before
`moon run scripts/benchmark.mbtx url`. Complete raw logs and statistics are CI
artifacts; the selected generated report and its `BENCHMARK-DATA.json` will be
committed together.
