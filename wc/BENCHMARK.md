# Word count benchmarks

Attempt 1 of [CI run 45777834902](https://github.com/justjavac/moonbit-simd/actions/runs/45777834902) measured [f0312bc](https://github.com/justjavac/moonbit-simd/commit/f0312bceaee1696872249fcd5315395d4af6c263).

The one-shot and streaming APIs count LF, ASCII-delimited words, and bytes. SIMD requests fall back to scalar on short inputs, Wasm GC, and JavaScript. Streaming includes counter creation, updates on prepared chunks, and the snapshot. The independent reference uses the same bytes and chunk schedule. An asterisk marks CV ≥ 5%.

| OS / backend | Workload | Unit | Reference | Scalar | SIMD request |
| --- | --- | --- | ---: | ---: | ---: |
| linux / native | short | ns | 30.315 | 33.797 | 33.303 |
| linux / native | binary | GiB/s | 1.285 | 1.123 | 10.778 |
| linux / native | stream8k | GiB/s | 0.966 | 1.222 | 10.487 |
| linux / wasm | short | ns | 83.798 | 89.722 | 89.142 |
| linux / wasm | binary | GiB/s | 0.627 | 0.719 | 8.826 |
| linux / wasm | stream8k | GiB/s | 0.574 | 0.759 | 8.483 |
| linux / wasm-gc | short | ns | 36.72 | 28.359 | 33.134 |
| linux / wasm-gc | binary | GiB/s | 0.656 | 0.72 | 0.721 |
| linux / wasm-gc | stream8k | GiB/s | 0.624 | 0.713 | 0.709 |
| linux / js | short | ns | 52.18 | 61.833 | 62.556 |
| linux / js | binary | GiB/s | 0.484 | 0.67 | 0.666 |
| linux / js | stream8k | GiB/s | 0.523 | 0.624 | 0.626 |
| macos / native | short | ns | 35.868 | 42.071 | 38.707 |
| macos / native | binary | GiB/s | 3.959 | 3.839 | 4.006 |
| macos / native | stream8k | GiB/s | 3.168* | 3.277* | 3.478* |
| macos / wasm | short | ns | 96.587 | 115.614 | 112.616 |
| macos / wasm | binary | GiB/s | 0.544* | 0.739* | 6.388* |
| macos / wasm | stream8k | GiB/s | 0.601 | 0.721* | 6.192* |
| macos / wasm-gc | short | ns | 37.937 | 36.816* | 39.478 |
| macos / wasm-gc | binary | GiB/s | 0.597 | 0.755 | 0.717* |
| macos / wasm-gc | stream8k | GiB/s | 0.649* | 0.697 | 0.751 |
| macos / js | short | ns | 48.339 | 67.087 | 71.157* |
| macos / js | binary | GiB/s | 0.608 | 0.604 | 0.611 |
| macos / js | stream8k | GiB/s | 0.591 | 0.53 | 0.561 |
| windows / native | short | ns | 85.725* | 122.147 | 119.316 |
| windows / native | binary | GiB/s | 1.117 | 1.076 | 6.022 |
| windows / native | stream8k | GiB/s | 1.596* | 1.42 | 5.927 |
| windows / wasm | short | ns | 66.583 | 77.987 | 78.677 |
| windows / wasm | binary | GiB/s | 0.68 | 0.871 | 14.29 |
| windows / wasm | stream8k | GiB/s | 0.779 | 0.979 | 13.317 |
| windows / wasm-gc | short | ns | 22.592 | 22.451 | 24.362 |
| windows / wasm-gc | binary | GiB/s | 0.724 | 0.874 | 0.869 |
| windows / wasm-gc | stream8k | GiB/s | 1.049* | 0.87 | 0.858 |
| windows / js | short | ns | 47.045* | 58.703* | 57.391 |
| windows / js | binary | GiB/s | 0.569* | 0.843 | 0.854 |
| windows / js | stream8k | GiB/s | 0.733 | 0.81* | 0.909 |

## Runners

- linux · Intel(R) Xeon(R) 6975P-C (x86_64) · ubuntu-latest 20261122.9.1
- macos · Apple M1 (Virtual) (arm64) · macos-15 20261118.0550.1
- windows · AMD EPYC 9V45 96-Core Processor                 (AMD64) · windows-latest 20261116.315.1

```text
moon 0.1.20261126 (cc21d04 2026-11-26)
moonc v1.0.0-rc1+546870549-nightly (2026-11-25)
moonrun 0.1.20261126 (cc21d04 2026-11-26)
```
