# MoonBit SIMD Libraries

[![CI](https://github.com/justjavac/moonbit-simd/actions/workflows/ci.yml/badge.svg)](https://github.com/justjavac/moonbit-simd/actions/workflows/ci.yml)
[![coverage](https://img.shields.io/codecov/c/github/justjavac/moonbit-simd/main?label=coverage)](https://codecov.io/gh/justjavac/moonbit-simd)
[![linux](https://img.shields.io/codecov/c/github/justjavac/moonbit-simd/main?flag=linux&label=linux)](https://codecov.io/gh/justjavac/moonbit-simd)
[![macos](https://img.shields.io/codecov/c/github/justjavac/moonbit-simd/main?flag=macos&label=macos)](https://codecov.io/gh/justjavac/moonbit-simd)
[![windows](https://img.shields.io/codecov/c/github/justjavac/moonbit-simd/main?flag=windows&label=windows)](https://codecov.io/gh/justjavac/moonbit-simd)
[![MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Independent [MoonBit](https://docs.moonbitlang.com) SIMD libraries with portable
scalar fallbacks. Each `justjavac/xxx` module lives in `xxx/` and owns its version,
API, tests, documentation, and MIT license. [moon.work](moon.work) lists the
library modules.

## Libraries

| Module | Purpose | Documentation | Performance |
| --- | --- | --- | --- |
| `justjavac/crc32` | IEEE CRC-32, streaming, and checksum combination | [Guide](crc32/README.md) · [Examples](crc32/README.mbt.md) | [BENCHMARK.md](crc32/BENCHMARK.md) |
| `justjavac/url` | WHATWG URL parsing, normalization, resolution, and form queries, ported from Ada | [Guide](url/README.md) · [Examples](url/README.mbt.md) | [BENCHMARK.md](url/BENCHMARK.md) |
| `justjavac/utf8` | Strict UTF-8 validation, precise errors, and streaming, ported from simdutf8 | [Guide](utf8/README.md) · [Examples](utf8/README.mbt.md) | [BENCHMARK.md](utf8/BENCHMARK.md) |
| `justjavac/base64` | RFC 4648 Base64 and WHATWG forgiving decoding, ported from base64-simd | [Guide](base64/README.md) · [Examples](base64/README.mbt.md) | [BENCHMARK.md](base64/BENCHMARK.md) |
| `justjavac/atoi` | Decimal byte-to-integer parsing, exact prefixes, and 8–128-bit ranges, ported from atoi_simd | [Guide](atoi/README.md) · [Examples](atoi/README.mbt.md) | [BENCHMARK.md](atoi/BENCHMARK.md) |

Follow each guide for installation, API usage, and release availability. New
libraries are added as sibling modules at the repository root.

## Portability

Windows, Linux, and macOS are tested across `native`, `wasm`, `wasm-gc`, and `js`.
Scalar code operates on ordinary values; SIMD operates on multiple vector lanes.
Each module documents its vector support, fallback behavior, and measured tradeoffs.

Use the [MoonBit nightly toolchain](https://www.moonbitlang.com/download) providing
[`core/simd`](https://mooncakes.io/docs/moonbitlang/core/simd) and `V128`. Native
builds require MSVC on Windows, GCC/Clang on Linux, or Xcode Command Line Tools on
macOS; JavaScript tests require Node.js. CI uses Node.js 24 and records compiler
versions in its logs and benchmark data.
Run `moon update` once after installing the toolchain to initialize Mooncakes.

## Development

Run from the workspace root:

```text
moon check --target all --deny-warn
moon test --target all
moon info
moon fmt
```

Scope checks with `moon check xxx` and tests with `moon test xxx`; generate a module's API docs with
`moon -C xxx doc`. See [AGENTS.md](AGENTS.md) for layout, documentation, testing,
and maintenance conventions. All project content is written in English.

[CI](.github/workflows/ci.yml) checks all backends and uploads filtered coverage
for Linux, macOS, and Windows. The badges show combined and per-OS coverage.
Coverage uploads use Codecov's GitHub OIDC integration.

```text
moon test --target all
moon test --target native --enable-coverage
moon run scripts/coverage_report.mbtx local crc32 url utf8 base64 atoi
```

## Benchmarks

[Benchmarks CI](.github/workflows/benchmark.yml) measures all three systems and
four backends. Each module's `BENCHMARK.md` documents key comparisons. Selected
complete CI snapshots preserve statistics and provenance in `BENCHMARK-DATA.json`.

The development-only [comparison harness](benchmarks/README.md) tests CRC32
against `gaato/crc`, `gmlewis/crc32`, `kujirahand/crc32`, and
`moonbitstack/mooncrypt/sum/crc32`, with pinned dependencies isolated from the
published library. Its separate URL adapter packages compare `tonyfettes/url`,
`moonbitstack/moonurl` in WHATWG mode, and `connect0459/urllib` against
`justjavac/url`. UTF-8 comparisons measure strict validation and UTF-16 decoding
against a pinned compatibility copy of `tonyfettes/utf8@0.2.4` and the bundled
core decoder, with required adaptation costs documented in the module report.

Base64 adapters compare core, `gmlewis/base64`,
`moonbitstack/moonbase/base64`, and `kujirahand/base64` with
`justjavac/base64`. Their cases distinguish string/byte decoding, output
allocation, buffer reuse, partial views, and matching RFC 4648 policies.

Integer adapters compare scalar/SIMD decimal parsing with bundled core string
parsers and bounded BigInt. Required UTF-8 conversion, prefix scans, and range
checks remain inside the timer.

Reproduce locally from the repository root:

```text
moon -C benchmarks test --target all
moon run scripts/benchmark.mbtx crc32
moon run scripts/benchmark.mbtx url
moon run scripts/benchmark.mbtx utf8
moon run scripts/benchmark.mbtx base64
moon run scripts/benchmark.mbtx atoi
```

Commit reports generated from a complete CI run. Raw logs remain available as
workflow artifacts; report-only updates do not trigger another benchmark run.

The workspace and every library are licensed under [MIT](LICENSE).
