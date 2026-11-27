# StringZilla UTF-16 performance

Attempt 1 of [CI run 45937605661](https://github.com/justjavac/moonbit-simd/actions/runs/45937605661) measured [bd9c483](https://github.com/justjavac/moonbit-simd/commit/bd9c483b659f625c21b1f259c7ed941b193b50ec).

Three systems, four backends, and 20 cases per backend. [Full data](BENCHMARK-DATA.json) retains all 240 measurements.

Both implementations use the same prepared StringViews. Timings include complete iterator consumption and replacement allocation where applicable. Results are nanoseconds per public operation. An asterisk marks CV ≥ 5%.

| OS / backend | Workload | Code units | Port | Core |
| --- | --- | ---: | ---: | ---: |
| linux / native | find-short | 15 | 20.6 | 19.667 |
| linux / native | find-late | 65536 | 3903.886 | 5155.664 |
| linux / native | find-periodic | 4096 | 281.378 | 12621.191 |
| linux / native | equal-long | 65536 | 2682.272 | 2690.276 |
| linux / native | replace-all-sparse | 4096 | 3171.01 | 3145.663 |
| linux / wasm | find-short | 15 | 51.909 | 51.95 |
| linux / wasm | find-late | 65536 | 5927.361 | 7762.177 |
| linux / wasm | find-periodic | 4096 | 451.707 | 13129.664 |
| linux / wasm | equal-long | 65536 | 5931.444 | 7791.621 |
| linux / wasm | replace-all-sparse | 4096 | 1464.918 | 1343.004 |
| linux / wasm-gc | find-short | 15 | 25.736 | 25.615 |
| linux / wasm-gc | find-late | 65536 | 35872.902 | 35804.002 |
| linux / wasm-gc | find-periodic | 4096 | 12899.831 | 12836.367 |
| linux / wasm-gc | equal-long | 65536 | 50908.406 | 50713.421 |
| linux / wasm-gc | replace-all-sparse | 4096 | 5862.572 | 6003.27 |
| linux / js | find-short | 15 | 23.353 | 36.234 |
| linux / js | find-late | 65536 | 1350.019 | 1384.891 |
| linux / js | find-periodic | 4096 | 3265.796 | 3293.207 |
| linux / js | equal-long | 65536 | 199480.383* | 184063.042 |
| linux / js | replace-all-sparse | 4096 | 182.672 | 211.836 |
| macos / native | find-short | 15 | 17.239* | 17.797* |
| macos / native | find-late | 65536 | 4910.615* | 5752.19* |
| macos / native | find-periodic | 4096 | 277.641 | 15167.674* |
| macos / native | equal-long | 65536 | 4056.213* | 4284.769 |
| macos / native | replace-all-sparse | 4096 | 743.08* | 718.685 |
| macos / wasm | find-short | 15 | 45.324 | 31.279 |
| macos / wasm | find-late | 65536 | 6382.821* | 7104.97 |
| macos / wasm | find-periodic | 4096 | 398.868 | 13587.341 |
| macos / wasm | equal-long | 65536 | 6542.325* | 8432.527* |
| macos / wasm | replace-all-sparse | 4096 | 1383.429* | 1423.073* |
| macos / wasm-gc | find-short | 15 | 22.063* | 17.646 |
| macos / wasm-gc | find-late | 65536 | 40445.296* | 37928.073 |
| macos / wasm-gc | find-periodic | 4096 | 17516.106* | 16270.974 |
| macos / wasm-gc | equal-long | 65536 | 62476.442* | 66920.893* |
| macos / wasm-gc | replace-all-sparse | 4096 | 8103.302* | 6132.804* |
| macos / js | find-short | 15 | 15.18 | 27.565 |
| macos / js | find-late | 65536 | 3241.107* | 3261.403 |
| macos / js | find-periodic | 4096 | 3100.989* | 3184.379 |
| macos / js | equal-long | 65536 | 181951.659* | 135428.236 |
| macos / js | replace-all-sparse | 4096 | 226.693* | 270.77 |
| windows / native | find-short | 15 | 32.3 | 34.263 |
| windows / native | find-late | 65536 | 2492.504 | 2992.483 |
| windows / native | find-periodic | 4096 | 230.805* | 13422.994 |
| windows / native | equal-long | 65536 | 2381.794 | 2422.034 |
| windows / native | replace-all-sparse | 4096 | 1850.904* | 1738.492 |
| windows / wasm | find-short | 15 | 28.131 | 25.072 |
| windows / wasm | find-late | 65536 | 3477.481 | 4307.361 |
| windows / wasm | find-periodic | 4096 | 260.239* | 7881.519* |
| windows / wasm | equal-long | 65536 | 3447.583 | 4142.368 |
| windows / wasm | replace-all-sparse | 4096 | 740.362 | 677.891 |
| windows / wasm-gc | find-short | 15 | 14.441 | 14.624 |
| windows / wasm-gc | find-late | 65536 | 17021.508 | 16490.308 |
| windows / wasm-gc | find-periodic | 4096 | 8493.853 | 8291.667 |
| windows / wasm-gc | equal-long | 65536 | 30383.988 | 29584.617 |
| windows / wasm-gc | replace-all-sparse | 4096 | 3140.252 | 3333.526 |
| windows / js | find-short | 15 | 14.407 | 22.673 |
| windows / js | find-late | 65536 | 2186.254 | 2177.867 |
| windows / js | find-periodic | 4096 | 1437.795 | 1414.03 |
| windows / js | equal-long | 65536 | 92053.996* | 87916.057 |
| windows / js | replace-all-sparse | 4096 | 154.165 | 168.833 |

## Runners

- linux · AMD EPYC 7763 64-Core Processor (x86_64)
- macos · Apple M1 (Virtual) (arm64)
- windows · AMD EPYC 9V45 96-Core Processor                 (AMD64)

```text
moon 0.1.20261126 (cc21d04 2026-11-26)
moonc v1.0.0-rc1+546870549-nightly (2026-11-25)
moonrun 0.1.20261126 (cc21d04 2026-11-26)
```
