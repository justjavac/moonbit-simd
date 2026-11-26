# MoonBit SIMD Libraries

[![CI](https://github.com/justjavac/moonbit-simd/actions/workflows/ci.yml/badge.svg)](https://github.com/justjavac/moonbit-simd/actions/workflows/ci.yml)
[![coverage](https://img.shields.io/codecov/c/github/justjavac/moonbit-simd/main?label=coverage)](https://codecov.io/gh/justjavac/moonbit-simd)
[![linux](https://img.shields.io/codecov/c/github/justjavac/moonbit-simd/main?flag=linux&label=linux)](https://codecov.io/gh/justjavac/moonbit-simd)
[![macos](https://img.shields.io/codecov/c/github/justjavac/moonbit-simd/main?flag=macos&label=macos)](https://codecov.io/gh/justjavac/moonbit-simd)
[![windows](https://img.shields.io/codecov/c/github/justjavac/moonbit-simd/main?flag=windows&label=windows)](https://codecov.io/gh/justjavac/moonbit-simd)
[![MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Independent pure [MoonBit](https://docs.moonbitlang.com) libraries for bytes,
text, and numbers, with portable SIMD and scalar fallbacks. Follow each guide
for installation, APIs, and examples; [moon.work](moon.work) links local sources.

## Libraries

| Module / guide | Purpose | Benchmarks |
| --- | --- | --- |
| [justjavac/crc32](crc32/README.md) | IEEE CRC-32, streaming, combination | [Results](crc32/BENCHMARK.md) |
| [justjavac/url](url/README.md) | WHATWG URLs and form queries | [Results](url/BENCHMARK.md) |
| [justjavac/utf8](utf8/README.md) | UTF-8 validation, decoding, streaming | [Results](utf8/BENCHMARK.md) |
| [justjavac/base64](base64/README.md) | RFC 4648 Base64 and forgiving decoding | [Results](base64/BENCHMARK.md) |
| [justjavac/atoi](atoi/README.md) | Decimal byte parsing, signed/unsigned 8–128 bits | [Results](atoi/BENCHMARK.md) |
| [justjavac/argminmax](argminmax/README.md) | Extrema indices, NaN policies, validity masks | [Results](argminmax/BENCHMARK.md) |
| [justjavac/uuid](uuid/README.md) | UUID parsing, formatting, reusable buffers | [Results](uuid/BENCHMARK.md) |
| [justjavac/ryu](ryu/README.md) | Float formatting and experimental decimal parsing | [Results](ryu/BENCHMARK.md) |
| [justjavac/memchr](memchr/README.md) | Byte and substring search, finders, iteration | [Results](memchr/BENCHMARK.md) |
| [justjavac/wc](wc/README.md) | LF, ASCII-delimited words, and byte counts with streaming | [Results](wc/BENCHMARK.md) |

## Portability

CI tests Windows, Linux, and macOS (ARM64) on `native`, `wasm`, `wasm-gc`, and
`js`. Where implemented, `V128` kernels run on native and linear-memory Wasm;
Wasm GC/JS use scalar code. Ryu is scalar on every target. Guides document
dispatch and limits.

Use [MoonBit nightly](https://www.moonbitlang.com/download), a platform C compiler
for native builds, and Node.js for JavaScript (CI uses Node.js 24).

## Build and benchmark

From the repository root:

```text
moon update
moon check --target all --deny-warn
moon test --target all
moon info
moon fmt
moon -C benchmarks test --target all
moon run scripts/benchmark.mbtx crc32
```

Replace `crc32` with any library. [Benchmark reports](benchmarks/README.md)
compare matching operations within each OS/backend and retain complete CI
snapshots in `BENCHMARK-DATA.json`. Local results stay labelled local.
See [AGENTS.md](AGENTS.md) for development and coverage instructions, and the
[benchmark workflow](.github/workflows/benchmark.yml) for the full CI matrix.

Repository contributions are licensed under [MIT](LICENSE). Each module's
`LICENSE` preserves required upstream copyrights and license notices.
