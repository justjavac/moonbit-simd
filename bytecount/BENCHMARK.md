# Byte and UTF-8 code point count benchmarks

[CI run 45841111781](https://github.com/justjavac/moonbit-simd/actions/runs/45841111781), attempt 1, source `64702ee59b914f0098055896d6c7224e747d85f3`. [Complete data](BENCHMARK-DATA.json) covers three systems, four backends, and 30 cases each.

The adapters use the same prepared byte views and check every count against a direct byte predicate. The memchr comparison includes cursor construction. `*` marks CV >= 5%.

## count, 16 bytes (ns)

| OS / backend | dispatch | naive | memchr | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: |
| linux / native | **8.773*** | 13.1 | 32.536 | 3.709x* |
| linux / wasm | **18.704** | 21.522 | 143.874 | 7.692x |
| linux / wasm-gc | 15.692 | **11.749** | 30.577 | 2.603x |
| linux / js | 17.298 | **17.052** | 24.958 | 1.464x |
| macos / native | **11.046** | 15.054* | 51.298* | 4.644x* |
| macos / wasm | **29.944*** | 56.173* | 264.861* | 8.845x* |
| macos / wasm-gc | 26.388* | **17.321** | 39.678* | 2.291x* |
| macos / js | 36.095* | **29.694*** | 37.605 | 1.266x* |
| windows / native | 39.829 | **35.634** | 175.467 | 4.924x |
| windows / wasm | **27.662** | 32.1 | 201.755* | 7.294x* |
| windows / wasm-gc | 22.696 | **18.853** | 51.601 | 2.737x |
| windows / js | **25.124** | 25.233 | 35.342 | 1.407x |

## count, 1 MiB view at offset 1 (GiB/s)

| OS / backend | dispatch | naive | memchr | Best ours vs ref |
| --- | ---: | ---: | ---: | ---: |
| linux / native | **60.072** | 28.14 | 30.849* | 1.947x* |
| linux / wasm | **31.007** | 3.037* | 27.209 | 1.14x |
| linux / wasm-gc | 2.148 | **2.798** | 1.868 | 1.498x |
| linux / js | 2.15 | **2.255*** | 1.398 | 1.613x* |
| macos / native | **34.693*** | 8.048* | 11.275* | 3.077x* |
| macos / wasm | **20.27*** | 1.443* | 7.84* | 2.585x* |
| macos / wasm-gc | 1.132* | **1.388*** | 1.35* | 1.028x* |
| macos / js | 1.165* | **1.504** | 0.812 | 1.853x |
| windows / native | **48.608** | 10.6 | 8.826 | 5.507x |
| windows / wasm | **29.786** | 1.714 | 16.606 | 1.794x |
| windows / wasm-gc | 1.625 | **1.755** | 1.256 | 1.397x |
| windows / js | 1.449* | **1.613** | 0.957 | 1.686x |

## num-chars, 16 bytes (ns)

| OS / backend | dispatch | naive |
| --- | ---: | ---: |
| linux / native | **7.392** | 14.604 |
| linux / wasm | **19.839** | 25.241 |
| linux / wasm-gc | 17.116 | **13.902** |
| linux / js | **18.841** | 19.004 |
| macos / native | **15.663*** | 16.683* |
| macos / wasm | **35.547*** | 47.54* |
| macos / wasm-gc | **19.488** | 28.571* |
| macos / js | 32.532* | **31.709*** |
| windows / native | **38.46** | 45.329 |
| windows / wasm | **28.541** | 36.638 |
| windows / wasm-gc | 22.217 | **20.319** |
| windows / js | 26.203 | **25.976** |

## num-chars, 1 MiB view at offset 1 (GiB/s)

| OS / backend | dispatch | naive |
| --- | ---: | ---: |
| linux / native | **59.553** | 15.372 |
| linux / wasm | **31.991** | 2.521 |
| linux / wasm-gc | 2.284 | **2.466** |
| linux / js | **2.325** | 2.31 |
| macos / native | **37.072*** | 7.879* |
| macos / wasm | **19.978*** | 0.96* |
| macos / wasm-gc | **1.743** | 1.113* |
| macos / js | **1.229*** | 1.212* |
| windows / native | **48.376** | 1.094 |
| windows / wasm | **30.362** | 1.578 |
| windows / wasm-gc | **1.753** | 1.674 |
| windows / js | 1.46 | **1.466** |

## Runners

- linux, x86_64, AMD EPYC 9V45 96-Core Processor, Node v24.22.3
- macos, arm64, Apple M1 (Virtual), Node v24.22.3
- windows, AMD64, AMD EPYC 9V74 80-Core Processor                , Node v24.22.3
