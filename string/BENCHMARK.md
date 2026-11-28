# StringZilla UTF-16 performance

Attempt 1 of [CI run 45947816804](https://github.com/justjavac/moonbit-simd/actions/runs/45947816804) measured [8810ffa](https://github.com/justjavac/moonbit-simd/commit/8810ffa3348130a57adf4e3a5a6312ba90a82cd0).

Three systems, four backends, and 20 cases per backend. [Full data](BENCHMARK-DATA.json) retains all 240 measurements.

Both implementations use the same prepared StringViews. Timings include complete iterator consumption and replacement allocation where applicable. Results are nanoseconds per public operation. An asterisk marks CV ≥ 5%.

| OS / backend | Workload | Code units | Port | Core |
| --- | --- | ---: | ---: | ---: |
| linux / native | find-short | 15 | 16.033 | 19.379* |
| linux / native | find-late | 65536 | 3430.677 | 4508.865 |
| linux / native | find-periodic | 4096 | 239.172 | 11197.719 |
| linux / native | equal-long | 65536 | 2257.906 | 2257.93 |
| linux / native | replace-all-sparse | 4096 | 2710.465 | 2760.756 |
| linux / wasm | find-short | 15 | 40.763 | 36.725 |
| linux / wasm | find-late | 65536 | 4846.574 | 6811.624 |
| linux / wasm | find-periodic | 4096 | 353.023 | 11406.523 |
| linux / wasm | equal-long | 65536 | 5129.865 | 6817.973 |
| linux / wasm | replace-all-sparse | 4096 | 1059.708 | 1050.899 |
| linux / wasm-gc | find-short | 15 | 20.404 | 23.888 |
| linux / wasm-gc | find-late | 65536 | 31448.664 | 31469.153 |
| linux / wasm-gc | find-periodic | 4096 | 11574.337 | 11566.679 |
| linux / wasm-gc | equal-long | 65536 | 45392.503 | 45502.625 |
| linux / wasm-gc | replace-all-sparse | 4096 | 4904.416 | 5222.748 |
| linux / js | find-short | 15 | 18.319 | 29.794 |
| linux / js | find-late | 65536 | 1196.299 | 1210.154 |
| linux / js | find-periodic | 4096 | 2462.853 | 2446.505 |
| linux / js | equal-long | 65536 | 2332.504 | 179272.892 |
| linux / js | replace-all-sparse | 4096 | 142.31 | 177.725* |
| macos / native | find-short | 15 | 18.317* | 16.921* |
| macos / native | find-late | 65536 | 4583.362* | 6472.635* |
| macos / native | find-periodic | 4096 | 485.05* | 18654.764 |
| macos / native | equal-long | 65536 | 4190.157* | 4562.892* |
| macos / native | replace-all-sparse | 4096 | 795.628* | 881.768* |
| macos / wasm | find-short | 15 | 53.942* | 49.489* |
| macos / wasm | find-late | 65536 | 6232.576 | 10168.319* |
| macos / wasm | find-periodic | 4096 | 440.657* | 16642.045* |
| macos / wasm | equal-long | 65536 | 8303.554* | 9160.626* |
| macos / wasm | replace-all-sparse | 4096 | 1601.959* | 1453.192* |
| macos / wasm-gc | find-short | 15 | 24.66* | 21.976 |
| macos / wasm-gc | find-late | 65536 | 39864.396 | 42209.543* |
| macos / wasm-gc | find-periodic | 4096 | 18425.592 | 17901.034* |
| macos / wasm-gc | equal-long | 65536 | 78957.231* | 68770.6 |
| macos / wasm-gc | replace-all-sparse | 4096 | 6961.026 | 8394.033* |
| macos / js | find-short | 15 | 24.847* | 53.476* |
| macos / js | find-late | 65536 | 4250.822* | 5141.029* |
| macos / js | find-periodic | 4096 | 3947.902* | 4688.622* |
| macos / js | equal-long | 65536 | 5603.303* | 221174.92* |
| macos / js | replace-all-sparse | 4096 | 311.032* | 436.196* |
| windows / native | find-short | 15 | 35.515 | 35.637 |
| windows / native | find-late | 65536 | 2611.017 | 3155.437 |
| windows / native | find-periodic | 4096 | 233.969 | 14063.428 |
| windows / native | equal-long | 65536 | 2556.589 | 2560.697 |
| windows / native | replace-all-sparse | 4096 | 1862.171 | 1750.93 |
| windows / wasm | find-short | 15 | 30.216 | 29.994* |
| windows / wasm | find-late | 65536 | 3674.616 | 4476.874* |
| windows / wasm | find-periodic | 4096 | 268.419 | 7935.152 |
| windows / wasm | equal-long | 65536 | 3634.5 | 4416.109 |
| windows / wasm | replace-all-sparse | 4096 | 721.741 | 713.807 |
| windows / wasm-gc | find-short | 15 | 14.514 | 16.146 |
| windows / wasm-gc | find-late | 65536 | 17400.421 | 17646.795 |
| windows / wasm-gc | find-periodic | 4096 | 8808.454 | 8709.991 |
| windows / wasm-gc | equal-long | 65536 | 30788.26 | 30935.996 |
| windows / wasm-gc | replace-all-sparse | 4096 | 3624.145 | 3576.021 |
| windows / js | find-short | 15 | 15.889* | 23.587* |
| windows / js | find-late | 65536 | 2301.823 | 2320.912 |
| windows / js | find-periodic | 4096 | 1485.364 | 1473.518 |
| windows / js | equal-long | 65536 | 2591.042 | 93405.204 |
| windows / js | replace-all-sparse | 4096 | 162.642 | 202.5* |

## Local CPU sampling and probe filtering

On Linux x86-64 (WSL2, Intel Core i7-13650HX), `gprofng` attributed 45.9% of
sampled CPU time in the baseline mixed UTF-16 scan to `candidate_mask`.
`objdump` showed that each call loaded the two remaining probes and packed
their results even when the first two probes had no candidate start in
common. The new scan can reject the whole block at that point. A block with
hits in only one half finishes the probe checks for that half.

The release benchmark compared `015ef28` with the updated code in one
process per backend using prepared views at offset one. Each measurement
order used ten batch samples per case. The ranges divide the baseline mean
by the new mean across both orders and both search directions. An asterisk
marks at least one measurement with CV ≥ 5%.

| Workload | Native | Wasm |
| --- | ---: | ---: |
| Mixed UTF-16 miss, 65,000 units | 1.26–1.49×* | 1.44–1.60× |
| Repeated four-unit needle in alternating ASCII, 65,536 units | 1.37–2.38×* | 1.45–1.62×* |
| Near-matches in one half per block, 65,536 units | 0.91–0.98×* | 0.92–1.12×* |
| Periodic verification fallback, 8,257 units | 0.77–1.01×* | 0.93–1.01×* |
| Two-unit needle, 24-unit view | 0.51–1.03×* | 0.81–1.05×* |

The mixed miss searches for `"a中😀"` in `"a😀中b".repeat(13000)`. Every
probe's code unit occurs in the text. In the baseline-first order, the
forward mean fell from 9.26 to 6.88 μs on native and from 12.82 to 8.18 μs
on Wasm. The Wasm one-half reverse mean rose from 8.94 to 9.69 μs in the
candidate-first order. The native 24-unit reverse search took about 12 ns
for both versions in one order and about 12 versus 24 ns in the other.

These local runs used Moon `0.1.20261126` (`ccd306a`) and
`moonc v1.0.0-rc1+3c0520448`.

## CI runners

- linux · AMD EPYC 9V74 80-Core Processor (x86_64)
- macos · Apple M1 (Virtual) (arm64)
- windows · AMD EPYC 9V45 96-Core Processor                 (AMD64)

```text
moon 0.1.20261126 (cc21d04 2026-11-26)
moonc v1.0.0-rc1+546870549-nightly (2026-11-25)
moonrun 0.1.20261126 (cc21d04 2026-11-26)
```
