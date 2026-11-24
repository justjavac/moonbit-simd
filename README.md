# MoonBit SIMD Libraries

[![CI](https://github.com/justjavac/moonbit-simd/actions/workflows/ci.yml/badge.svg)](https://github.com/justjavac/moonbit-simd/actions/workflows/ci.yml)
[![coverage](https://img.shields.io/codecov/c/github/justjavac/moonbit-simd/main?label=coverage)](https://codecov.io/gh/justjavac/moonbit-simd)
[![linux](https://img.shields.io/codecov/c/github/justjavac/moonbit-simd/main?flag=linux&label=linux)](https://codecov.io/gh/justjavac/moonbit-simd)
[![macos](https://img.shields.io/codecov/c/github/justjavac/moonbit-simd/main?flag=macos&label=macos)](https://codecov.io/gh/justjavac/moonbit-simd)
[![windows](https://img.shields.io/codecov/c/github/justjavac/moonbit-simd/main?flag=windows&label=windows)](https://codecov.io/gh/justjavac/moonbit-simd)
[![MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A collection of independent SIMD libraries for MoonBit, organized as a
`moon.work` workspace. The collection grows through sibling modules at the
repository root, each with its own public API, version, documentation, tests,
and MIT license.

The libraries use portable vector operations and scalar implementations where
appropriate. Windows, Linux, and macOS are supported, with workspace checks
across the native, WebAssembly, WebAssembly GC, and JavaScript backends.

## Module catalog

Each module is independently usable and publishable. Its detailed guide explains
its algorithm, API, backend support, implementation choices, and benchmarks;
its short `README.mbt.md` provides executable examples.

| Module | Directory | Purpose | Guide | Tested examples | Performance |
| --- | --- | --- | --- | --- | --- |
| `justjavac/crc32` | `crc32/` | IEEE CRC-32 checksums, streaming, and checksum combination | [README](crc32/README.md) | [README.mbt.md](crc32/README.mbt.md) | [BENCHMARK.md](crc32/BENCHMARK.md) |

New modules are added to this catalog and to `moon.work` as the collection grows.

## Workspace organization

`moon.work` is the source of truth for workspace membership. For every module
`justjavac/xxx`, put its metadata and source files directly in `xxx/`. Many such
module directories can coexist at the repository root.

The layout for an individual module is:

```text
moon.work
AGENTS.md
README.md
LICENSE
.github/
  workflows/
xxx/                       # Module justjavac/xxx
  moon.mod
  moon.pkg
  LICENSE
  README.md
  README.mbt.md
  BENCHMARK.md
  *.mbt
  *_test.mbt
  *_wbtest.mbt
  pkg.generated.mbti
```

Package directories and `///|` source blocks follow the organization used by
[moonbitlang/core](https://github.com/moonbitlang/core). Each module declares its
own dependencies and imports and can be built outside the workspace.

The root README describes the collection and its shared development workflow.
Module READMEs contain algorithm details, API examples, performance measurements,
and module-specific limitations.

## Using a module

Choose a library from the module catalog and follow its guide. Modules have
independent release versions. To install a published version in a consuming
module, replace the placeholders below with the selected module and version:

```text
moon add justjavac/<module>@<version>
```

Then import the package in the consuming package's `moon.pkg`:

```text
import {
  "justjavac/<module>",
}
```

The module's guide documents its package alias and public API. Availability
on Mooncakes follows each module's publication status; local source development
uses the members declared in this repository's `moon.work`.

## Scalar and SIMD implementations

Scalar code operates on ordinary integer or floating-point values. Vector code
groups values into lanes and applies operations to multiple lanes together.
For example, a 128-bit `V128` value can hold four 32-bit integer lanes.

A vector algorithm can also contain scalar work, such as table lookups, state
management, and short-tail handling. Whether vector operations become hardware
SIMD instructions depends on the compiler backend and target. Performance
depends on the full algorithm, input size, runtime, and CPU.

Implementation selection is part of each module's API. Consult its guide for
available vector paths, scalar fallbacks, defaults, and benchmark results.

The former `moonbitlang/core/v128` package has been renamed to
`moonbitlang/core/simd`. This collection uses the maintained package and the
built-in `V128` type. Its intrinsics are experimental and hidden from the
generated core interface, so API discovery may require inspecting core sources.

## Systems and backends

Workspace CI checks modules on Windows, Linux, and macOS using these backends:

| Backend | Execution environment |
| --- | --- |
| `native` | Native programs built with a C compiler |
| `wasm` | WebAssembly with linear memory |
| `wasm-gc` | WebAssembly with garbage-collected data |
| `js` | JavaScript |

Each module documents its actual SIMD support and fallback behavior. Backend
restrictions, when necessary, belong in that module's metadata and guide.
Implementations must preserve their public behavior across supported systems.

Native builds require MSVC on Windows, GCC or Clang on Linux, and Xcode Command
Line Tools on macOS. CI prepares the Windows compiler environment. JavaScript
tests require Node.js; CI selects Node.js 24.

## Toolchain

Install MoonBit from the [official download page](https://www.moonbitlang.com/download).
Use the nightly channel providing `core/simd` and `v128le` bitstring patterns.
CI explicitly selects `MOONBIT_INSTALL_VERSION=nightly` and records its actual
toolchain versions on each run.

The current workspace was verified with these tools on November 24, 2026:

- `moon 0.1.20261120` (`aaf8010`)
- `moonc v0.10.22+7b085e9a4-nightly` (November 22, 2026)
- `moonrun 0.1.20261120`
- Node.js `v24.1.0`

Record any additional compiler requirements in the affected module's README.
When the download service offers an immutable compatible release, pin that
release in CI; the nightly channel follows newer builds over time.

## Development

Run shared checks from the repository root:

```text
moon check --target all --deny-warn
moon test --target all
moon info
moon fmt
```

For commands scoped to a member, replace `xxx` with its directory:

```text
moon -C xxx check --target all --deny-warn
moon -C xxx test --target all
moon -C xxx doc
moon -C xxx bench --target native --release
```

Documentation generation selects one workspace member at a time. Generated
`pkg.generated.mbti` files are committed public API summaries: update them with
`moon info`, review their changes, and keep manual edits in source files.

Follow [AGENTS.md](AGENTS.md) for coding and maintenance conventions. All project
prose, comments, identifiers, test names, and metadata are written in English,
with exact external identifiers and author identities preserved.

## Adding a module

1. Create `xxx/` with `moon.mod` naming the module `justjavac/xxx`, its root
   `moon.pkg`, and focused implementation files.
2. Add `xxx/` to `moon.work` and add the module to the catalog above.
3. Include a complete MIT license, a detailed `README.md`, and a concise
   `README.mbt.md` with checked examples.
4. Document public APIs in detail and private declarations in one sentence.
5. Add public API tests and independent differential checks for vector and
   scalar algorithms, including boundaries and unaligned input where relevant.
6. Add the module's filtered coverage report to each OS's CI report generation,
   saved artifacts, and Codecov upload.
7. Run supported-backend checks and tests, then regenerate interfaces and format
   the source.

## Coverage and CI

The [CI workflow](.github/workflows/ci.yml) checks source code, public interfaces,
and formatting and runs workspace tests with coverage on Linux, macOS, and
Windows. Coverage reports are filtered to individual workspace modules and saved
as workflow artifacts.

Run workspace tests with coverage:

```text
moon test --target all --enable-coverage
```

Generate a report for a member by replacing `xxx` with its module name:

```text
moon coverage analyze -p justjavac/xxx -- -f cobertura -o coverage-xxx.xml
```

Maintain the report-generation commands and upload file list as modules are
added. Upload each OS's configured module reports together under its `linux`,
`macos`, or `windows` Codecov flag. Only the named reports are uploaded, with
automatic file search disabled.

The total badge summarizes uploaded workspace coverage. The OS badges summarize
the corresponding platform's uploaded module reports. Codecov waits for all three
OS uploads before posting results. Module guides can record their own coverage
measurements and reporting limitations.

Enable the GitHub repository in Codecov to populate uploads and badges. The
workflow authenticates with GitHub OIDC through `id-token: write`. Badges update
after coverage from `main` has been uploaded and processed.

## Performance reports

The [Benchmarks workflow](.github/workflows/benchmark.yml) measures configured
modules on Linux, macOS, and Windows. It runs native, Wasm, Wasm GC, and JavaScript
sequentially within each OS job, verifies correctness first, and exports complete
JSON statistics and raw logs.

Its report job validates that all measurements belong to the same commit, run,
and attempt, then creates an uppercase `BENCHMARK.md` and its complete
`BENCHMARK-DATA.json` for each module. Reports identify the runner, CPU, compiler,
inputs, latency, throughput, sample counts, and measurement variation. CI artifacts
are retained for 90 days; committed JSON snapshots preserve the underlying data.

Choose a complete CI run and commit its generated files to the corresponding
module. Report-only updates do not trigger another benchmark run. Local measurements
can be collected with `moon run scripts/benchmark.mbtx <module>`, but the report
generator accepts CI provenance only. Add new modules to the workflow's collection
commands and extend their benchmark result inventory as the collection grows.

## License and references

The collection and each individual module are licensed under [MIT](LICENSE).
Every module includes its own complete license for independent distribution.

- [MoonBit documentation](https://docs.moonbitlang.com)
- [Core agent guide](https://github.com/moonbitlang/core/blob/main/AGENTS.md)
- [Current SIMD package](https://mooncakes.io/docs/moonbitlang/core/simd)
- [Original v128 documentation](https://mooncakes.io/docs/moonbitlang/core/v128)
