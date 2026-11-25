# MoonBit SIMD Libraries

[![CI](https://github.com/justjavac/moonbit-simd/actions/workflows/ci.yml/badge.svg)](https://github.com/justjavac/moonbit-simd/actions/workflows/ci.yml)
[![coverage](https://img.shields.io/codecov/c/github/justjavac/moonbit-simd/main?label=coverage)](https://codecov.io/gh/justjavac/moonbit-simd)
[![linux](https://img.shields.io/codecov/c/github/justjavac/moonbit-simd/main?flag=linux&label=linux)](https://codecov.io/gh/justjavac/moonbit-simd)
[![macos](https://img.shields.io/codecov/c/github/justjavac/moonbit-simd/main?flag=macos&label=macos)](https://codecov.io/gh/justjavac/moonbit-simd)
[![windows](https://img.shields.io/codecov/c/github/justjavac/moonbit-simd/main?flag=windows&label=windows)](https://codecov.io/gh/justjavac/moonbit-simd)
[![MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Pure [MoonBit](https://docs.moonbitlang.com) libraries for byte processing, text
codecs, and numeric utilities, with portable SIMD kernels and scalar fallbacks.
Each library is an independent module with its own version, API, tests, and
documentation. The repository's [moon.work](moon.work) links their local sources
for development.

## Libraries

| Module | Capabilities | Documentation | Performance |
| --- | --- | --- | --- |
| `justjavac/crc32` | IEEE CRC-32, streaming, and checksum combination | [Guide](crc32/README.md) · [Examples](crc32/README.mbt.md) | [BENCHMARK.md](crc32/BENCHMARK.md) |
| `justjavac/url` | WHATWG URL parsing, normalization, resolution, mutation, and form queries | [Guide](url/README.md) · [Examples](url/README.mbt.md) | [BENCHMARK.md](url/BENCHMARK.md) |
| `justjavac/utf8` | Strict UTF-8 validation, precise errors, and streaming | [Guide](utf8/README.md) · [Examples](utf8/README.mbt.md) | [BENCHMARK.md](utf8/BENCHMARK.md) |
| `justjavac/base64` | RFC 4648 Base64 encoding and strict or WHATWG forgiving decoding | [Guide](base64/README.md) · [Examples](base64/README.mbt.md) | [BENCHMARK.md](base64/BENCHMARK.md) |
| `justjavac/atoi` | Full and prefix decimal byte parsing with signed/unsigned 8–128-bit ranges | [Guide](atoi/README.md) · [Examples](atoi/README.mbt.md) | [BENCHMARK.md](atoi/BENCHMARK.md) |
| `justjavac/argminmax` | Extrema indices for 14 numeric kinds, NaN policies, and validity bitmaps | [Guide](argminmax/README.md) · [Examples](argminmax/README.mbt.md) | [BENCHMARK.md](argminmax/BENCHMARK.md) |
| `justjavac/uuid` | UUID text/byte parsing, formatting, and reusable output buffers | [Guide](uuid/README.md) · [Examples](uuid/README.mbt.md) | [BENCHMARK.md](uuid/BENCHMARK.md) |
| `justjavac/ryu` | Shortest float decimals, fixed/scientific formatting, and experimental decimal parsing | [Guide](ryu/README.md) · [Examples](ryu/README.mbt.md) | [BENCHMARK.md](ryu/BENCHMARK.md) |
| `justjavac/memchr` | Byte and substring search, reusable finders, and match iteration | [Guide](memchr/README.md) · [Examples](memchr/README.mbt.md) | [BENCHMARK.md](memchr/BENCHMARK.md) |

## Use a library

Choose a module above and follow its guide for installation, imports, and release
availability. For local use, link the chosen library in your application's
`moon.work` and declare it in the consuming `moon.mod` and `moon.pkg`, as shown
in the guide.

## Portability

CI tests Windows, Linux, and macOS (ARM64) across `native`, `wasm`, `wasm-gc`, and
`js`. Where implemented, portable `V128` kernels run on native and linear-memory
Wasm; Wasm GC and JavaScript use scalar code. Ryu uses its scalar algorithm on
every target. Each guide documents dispatch, input-size thresholds, and limits.

Use the [MoonBit nightly toolchain](https://www.moonbitlang.com/download) with
[`core/simd`](https://mooncakes.io/docs/moonbitlang/core/simd). Native builds need
MSVC on Windows, GCC/Clang on Linux, or Xcode Command Line Tools on macOS.
JavaScript tests need Node.js; CI uses Node.js 24 and records actual toolchain
versions in its logs and benchmark snapshots.

## Development

Initialize the Mooncakes index after installing MoonBit, then run these commands
from the repository root:

```text
moon update
moon check --target all --deny-warn
moon test --target all
moon info
moon fmt
```

Scope checks and tests with a module directory, for example
`moon check crc32 --target all --deny-warn` and `moon test crc32 --target all`.
Generate API documentation with `moon -C crc32 doc`.

The [CI workflow](.github/workflows/ci.yml) verifies formatting, generated
interfaces, checked examples, correctness, comparison adapters, and native
coverage. Coverage uploads use Codecov's GitHub OIDC integration; the badges
show combined and per-OS results. See [AGENTS.md](AGENTS.md) for coverage
collection, project conventions, and maintenance instructions.

## Benchmarks

Each module's `BENCHMARK.md` describes measured tradeoffs and adapter costs.
The development-only [comparison harness](benchmarks/README.md) keeps pinned
comparison dependencies separate from published libraries and verifies matching
results before timing.

Measure one library locally, for example CRC32:

```text
moon -C benchmarks test --target all
moon run scripts/benchmark.mbtx crc32
```

Replace `crc32` with any module directory in the catalog. The collector measures
all four backends sequentially in release mode. The
[Benchmarks workflow](.github/workflows/benchmark.yml) can select one library or
all libraries and collects the complete three-OS/four-backend matrix.

Selected CI snapshots retain every statistic and the measured source commit,
run, and attempt in `BENCHMARK-DATA.json`. Raw logs are retained for 90 days;
local measurements remain labelled local. Report-only edits do not trigger
another performance run. See the comparison guide and module reports for
workloads, pinned dependencies, and full reproduction instructions.

Repository contributions are licensed under [MIT](LICENSE). Each module's
`LICENSE` preserves required upstream copyrights and license notices.
