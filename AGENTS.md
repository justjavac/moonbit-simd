# Agent Guide

This repository is a `moon.work` workspace of independent MoonBit SIMD libraries.
Use this guide for implementation, documentation, tests, automation, and
maintenance. Module READMEs define their algorithms and public contracts.

## Repository structure

- Implement production libraries in pure MoonBit using MoonBit packages and
  standard SIMD intrinsics. Do not add C/C++, Rust, assembly, FFI bindings,
  native stubs, or native-library dependencies as implementation shortcuts.
  MoonBit's generated native C and standard runtime remain toolchain artifacts;
  do not commit or maintain generated backend sources.
- The root is a workspace, not a publishable umbrella module. Module
  `justjavac/xxx` belongs directly in `xxx/`, with its `moon.mod`, root
  `moon.pkg`, and source files; do not add an unnecessary `src/` directory.
- Each library must build, test, and publish independently. Declare its
  dependencies in its own `moon.mod` and imports in the relevant `moon.pkg`;
  production code must not depend on files outside its module.
- Use the text formats `moon.work`, `moon.mod`, and `moon.pkg`. Keep workspace
  membership explicit. Packages are directories; source filenames do not
  introduce namespaces. Add subpackages only for a useful maintenance boundary.
- Keep comparison dependencies in the development-only `benchmarks/` module.
  Its nested `moon.work` links local libraries explicitly without adding
  third-party benchmark dependencies to published modules.
- Every library includes `LICENSE`, `README.md`, `README.mbt.md`, uppercase
  `BENCHMARK.md`, and a generated `pkg.generated.mbti` for each public package.

```text
moon.work
AGENTS.md
README.md
LICENSE
xxx/                         # Module justjavac/xxx
  moon.mod
  moon.pkg
  LICENSE
  README.md
  README.mbt.md
  BENCHMARK.md
  BENCHMARK-DATA.json         # Selected complete CI snapshot
  *.mbt
  *_test.mbt
  *_wbtest.mbt
  pkg.generated.mbti
benchmarks/
  moon.work                  # Development-only comparison workspace
scripts/
  *.mbtx                     # Shared automation
```

## Documentation and public APIs

- Write project prose, comments, test names, identifiers, and metadata in
  English. Preserve exact external identifiers and author identities.
- License each library under MIT: set `license = "MIT"` and include the full
  license in its `LICENSE`. Preserve required attribution for incorporated
  upstream code. Dependency licenses remain their own.
- Keep the root README concise: collection overview, module catalog, systems
  and backends, essential commands, coverage badges, and links to detailed guides.
- Keep module READMEs detailed: algorithm variant, installation, imports, API,
  examples, state and ownership semantics, portability, limits, tests, and references.
  Set `moon.mod`'s `readme` to `README.md`; keep repository and description accurate.
- Keep `README.mbt.md` short, with one or two small `mbt check` assertion examples.
  Both README files are ordinary files; avoid symlinks so Windows checkouts work.
- Public declarations need detailed doc comments covering parameters, results,
  mutation, edge cases, failures, and backend limits, with checked examples when useful.
  Non-public declarations need one sentence describing their responsibility.
- Prefer small cohesive files, descriptive names, straightforward control flow,
  labeled parameters, methods for type behavior, and a minimal public API.
  Separate algorithm selection from public state and operations.
- Keep representation private. MoonBit structs have reference semantics;
  document aliasing and provide an explicit independent copy for mutable state.
  Do not copy consuming API semantics from another language without documenting them.
- Separate top-level declarations with `///|`; explain invariants rather than
  narrating statements. Keep retained deprecated declarations in `deprecated.mbt`.
  Generate interfaces with `moon info`; never edit `.mbti` files manually.

## SIMD implementation and portability

- Support Windows, Linux, and macOS across `native`, `wasm`, `wasm-gc`, and `js`.
  Any unavoidable restriction must appear in the module metadata and README.
  Keep paths and commands portable; native builds need a platform C compiler,
  and JavaScript tests need Node.js. CI prepares MSVC on Windows and uses Node.js 24.
- Discover exact APIs with `moon ide doc`, then inspect installed core sources
  when necessary. Locate the toolchain with `moon version --all`; do not assume
  core is installed under the user's home directory.
- The former `moonbitlang/core/v128` package is now `moonbitlang/core/simd`,
  using the built-in `V128` type. Experimental exports can be absent from
  generated core interfaces, so an empty IDE lookup alone does not prove an
  intrinsic is unavailable.
- Enable experimental imports explicitly in the importing `moon.pkg`:

```text
import {
  "moonbitlang/core/simd",
}

options(
  "allow-experimental-packages": [ "moonbitlang/core/simd" ],
)
```

- Isolate vector declarations with backend conditions such as
  `#cfg(any(target="native", target="wasm"))`. Provide scalar behavior on
  other backends. Document whether a SIMD request uses vectors, a short-input
  scalar path, or a backend fallback; the request alone does not prove vector execution.
- A vector load must stay inside the view. Use checked lengths or matching
  patterns such as `[v128le(block), .. tail]`, and process the remainder scalarly.
  Test unaligned views; do not assume alignment or host endianness.
- Keep byte offsets distinct from UTF-16 code-unit offsets. Text scanning must
  preserve encoding boundaries and the parser's normalization and error semantics.
- Use fixed-width unsigned arithmetic for checksums and state their polynomial,
  reflection, initial/final XOR, byte order, and continuation convention.
  For CRC32, public initial states are finalized checksums, not raw registers;
  preserve full `UInt64` lengths and validate overflow before mutating state.
- Derive or explain lookup tables and allocate reusable tables outside hot loops.
  Vectorize independent work while keeping state transitions and tails explicit.
  Avoid speculative abstractions and dependencies that replace a few simple lines.
- Use unchecked table reads only when fixed table sizes and masked indices prove
  every access is in range; explain that invariant beside the hot loop and test
  byte/index extremes independently. Keep input loads bounded by the actual view.
- Minimize vector-to-scalar round trips when portable SIMD lacks table gather.
  Inspect generated loops before rewriting them: scalar bitstring patterns can
  already lower to offsets, while vector patterns may retain view bookkeeping.
- Portable vector operations are not hardware CRC or carry-less multiplication.
  Do not assume x86, ARM, or optional CPU instructions; architecture-specific
  acceleration needs feature checks and a safe fallback.
- Inspect generated native lowering before assuming a vector primitive maps
  efficiently to hardware. On the recorded x86 toolchain, generic byte
  shuffle/swizzle uses a scalar fallback unless SSSE3 is enabled. Prefer portable
  lane operations or fixed-width packing when measurements justify it, and keep
  native and Wasm dispatch decisions separate.
- Measure the whole public operation before selecting a default, including table
  lookups and lane extraction. Compare old and new implementations in the same
  process with reversed measurement order, then use the complete
  [CRC32 CI snapshot](crc32/BENCHMARK.md) to assess other systems and public API
  adapters. Dispatch must follow measured backend/workload results.

On 2026-11-24, the validated tools were `moon 0.1.20261120` and
`moonc v0.10.22+7b085e9a4-nightly` (2026-11-22). CI selects the nightly channel
and records actual versions. Pin an immutable compatible release when available;
revalidate APIs, fallbacks, and benchmark assumptions after toolchain changes.

## Correctness tests

- Prefer black-box `*_test.mbt` tests through public package aliases. Reserve
  `*_wbtest.mbt` for private algorithms, implementation parity, and benchmark adapters.
- Use `assert_eq` and `assert_true` for exact results. For structured snapshots,
  derive `Debug` and use `debug_inspect`; update snapshots only intentionally.
- Check both scalar and vector paths against independent reference results.
  Comparing implementations that share tables or logic can preserve the same bug.
- Cover empty and short inputs, every tail length, vector/block boundaries,
  unaligned subviews, nonzero initial states, and varied streaming chunk sizes.
  Check continuation, reset, independent copying, combination laws, and overflow
  where the API exposes them.
- For parsers and encoders, include malformed input, Unicode, normalization,
  round trips, and specification-specific cases; matching only happy-path output
  is insufficient to establish equivalent behavior.
- Add meaningful regression tests for behavior changes. Documentation-only
  edits need content and diff review rather than another full benchmark run.

## Benchmark design

- Verify equivalent algorithm/specification variants before timing competitors.
  Use IEEE CRC32 explicitly where selectable, and WHATWG mode for URL comparisons.
  Validate identical checksums or canonical results with public-API adapters.
- Pin comparison versions in `benchmarks/moon.mod` and record them in the data.
  Keep one shared input inventory. If dependencies duplicate large Unicode
  tables, use separate adapter packages/binaries and run them on the same runner.
- Prepare deterministic inputs and owned streaming chunks outside timed callbacks.
  Include state creation, public calls, finalization, byte-wise adapter loops,
  and required input conversion inside the timer; document exactly what is measured.
- Distinguish prepared owned input from partial-view workloads. A full
  `BytesView.to_owned()` can reuse its original buffer; a partial view measures
  materialization. Include the owned-input conversion required by kujirahand
  and the byte-at-a-time loop required by gmlewis in their respective cases.
- Include meaningful short and large inputs, view offsets, and streaming sizes.
  Use separate cases for parsing, serialization, and other allocation-sensitive
  operations. Record bytes and code units accurately for text workloads.
- Benchmark test parameters use `@bench.T`, as in
  `test "bench ..." (bench : @bench.T)`. The generated benchmark driver can fail
  with `@bench.Bench` even when normal checks pass; run a release benchmark locally
  after adding or changing a harness.
- Keep results observable with `bench.keep(...)`. Collect structured JSON from
  `bench.dump_summaries()` using the stable `BENCHMARK_RESULTS ` marker;
  preserve stdout and stderr logs rather than parsing rendered console tables.
- Use release mode and `--no-parallelize`; measure backends sequentially within
  each OS job. Compare implementations within the same runner and backend.

## Benchmark statistics and publication

- Core benchmark times are microseconds per invocation. Convert to nanoseconds
  by multiplying by 1000, and compute GiB/s as `bytes * 1e6 / mean_us / 2^30`.
  Logical checksum-combination lengths are not bytes read; report their throughput
  as `n/a` and preserve full-width length labels as strings, avoiding signed
  integer overflow and floating-point loss above `2^53`.
- The validated core runner calibrates around 100 ms, takes 10 batch samples,
  and applies 5% winsorization. Submicrosecond cases use 100000 iterations per
  batch; 10 samples does not mean 10 calls. Record `runs` and `batch_size`, and
  inspect core again if its version changes.
- Maintain each module's expected case inventory in the collector and report
  validator. Check unique names, exact workloads/variants/offsets, finite timings,
  valid ranges, and sample metadata; a correct count can still hide substituted cases.
  Do not reuse CRC32's case count or report layout for a new module.
- Publish only one complete CI snapshot: same source commit, repository, run,
  attempt, dependencies, and the full declared OS/backend matrix (currently
  three systems by four backends).
  Reject partial uploads and mixtures from different runs or rerun attempts.
  Keep local measurements explicitly labeled as local.
- Keep `BENCHMARK.md` concise: key findings, representative comparison tables,
  API/adaptation costs, and runner context. Mark CV >= 5% as possible noise;
  a bold best mean does not establish statistical significance.
- Preserve every case and unrounded statistic in `BENCHMARK-DATA.json`, including
  source revision, run URL/attempt, CPU, architecture, runner image, toolchain,
  commands, timestamps, input lengths, offsets, and sampling metadata.
  Retain raw CI artifacts for 90 days and commit a selected verified snapshot.
- Regenerate a downloaded report from its CI JSON and compare outputs before
  committing. A later report commit naturally differs from the measured source
  commit; retain that source revision instead of relabeling data as current HEAD.
  Report-only edits should not trigger another performance run.

## CI and coverage

- Initialize Mooncakes with `moon update` after installation and on fresh CI
  runners. Cached local resolution hid this requirement: CI reported known
  comparison modules as missing until the registry index was initialized.
- Run supported-backend correctness tests on each OS, then run native tests
  with `--enable-coverage`. Use `scripts/coverage_report.mbtx` to export filtered
  native Cobertura reports, matching the current CI workflow.
- For the JavaScript string kernel, CI also runs instrumented tests in
  `_build/string-js-coverage` and exports a separate report with
  `moon run scripts/coverage_report.mbtx <OS flag> --string-js`. This mode
  selects runtime logs from the isolated build directory.
- The coverage exporter passes native `.trace.source` files explicitly.
  Automatic metadata discovery can mix built backends or search for unrelated
  files. Coverage reporter options such as `-p` belong after `moon coverage report --`.
  Extend the exporter when adding modules or changing the instrumented package layout.
- When sources or targets change, stale `_build/moonbit_coverage_*.txt` runtime
  logs can disagree with current counter layouts. Use `moon coverage clean`
  before fresh collection, or select only current native logs with reporter
  `-t <runtime-log>`; preserve other tasks' logs in a shared workspace.
- Upload only the configured module reports, together under the OS's `linux`,
  `macos`, or `windows` Codecov flag, with `disable_search: true` and GitHub OIDC.
  Keep total and three per-OS badges aligned with the repository/default branch;
  aggregate all three OS uploads before publishing status.
- Honor the coverage targets in `codecov.yml` (currently 80% for project and patch).
  Address meaningful gaps; do not skip executable code to inflate coverage or
  impose a 100% gate without an explicit requirement. Explain counter/backend
  limitations when reporting results.
- Ignore build directories, fetched dependencies, coverage files, and local
  benchmark artifacts. Committed benchmark snapshots are intentional exceptions.

## Automation and toolchain pitfalls

- Use `.mbtx` for loops, parsing, transformations, and process orchestration.
  Keep CI commands direct and reuse shared scripts instead of duplicating shell logic.
- Current scripts place imports between `----` delimiters. `moon.pkg`
  `options(...)` are not valid script frontmatter; acknowledge experimental
  packages in actual package metadata where supported. Keep warning suppressions
  limited to documented experimental or backend-dependent unused imports.
- Use `@shell.Cmd` with executable and argument arrays, not interpolated shell
  commands. Check exit codes and preserve logs before parsing results.
  Async MoonBit has no `await`; use `async fn main` when calling async APIs.
- Format `.mbtx` explicitly: normal workspace formatting does not cover them.
  CI lists shared scripts in `moon fmt --check`; extend that list for new scripts.
- Discover language APIs rather than borrowing names from another language.
  On the validated toolchain, `Array::search_by` returns an optional index,
  `String::replace` requires `old=`/`new=` and replaces the first occurrence,
  and `String::replace_all` handles repeated substitutions.
  Use `to_owned()` for views and `Number(value, ..)` for JSON numeric patterns.
  Avoid reserved identifiers such as `module`, `member`, and `package`.
- Use native Windows path operations and ordinary files. Avoid Unix-only shell
  assumptions, fragile quoting, and repurposing system variables such as `HOME`.
- A tool returning a running session is not a failed command; wait for its final
  exit status. A disconnected `gh run watch` stream or queued macOS runner does
  not determine the workflow's conclusion; reconnect and inspect actual job status.

## Development workflow

1. Read the workspace and affected module/package manifests. Inspect Git changes
   before editing, preserve other work, and use a focused diff. Initialize the
   registry when needed and record the toolchain for implementation/benchmark work.
2. Discover APIs with `moon ide doc`; navigate with `outline`, `peek-def`, and
   `find-references`. Implement the scalar contract before adding vector acceleration.
3. Add public tests, checked documentation examples, and independent differential
   checks for algorithm changes. Run the relevant supported-backend validation.
4. Finish source changes with `moon info` and `moon fmt`; review generated
   interfaces as API changes. Format modified scripts explicitly.
5. For benchmark changes, verify comparison adapters and a local release run
   before pushing; after CI completes, validate and commit its generated snapshot.
6. Review exact paths before committing or pushing. Shared workspace changes
   must not be swept into a commit with `git add .`; preserve other edits and staging.
   Verify the intended revision if HEAD can move during another task.
7. Report behavior changes, checks actually run, measured coverage/performance,
   and any remaining platform validation. Do not claim success from a queued job.

Run these shared checks from the repository root for source changes:

```text
moon check --target all --deny-warn
moon test --target all
moon info
moon fmt
moon test --target native --enable-coverage
moon run scripts/coverage_report.mbtx local crc32 url utf8 base64 atoi argminmax uuid ryu memchr wc bytecount string
```

For comparison changes, also run `moon -C benchmarks check --target all --deny-warn`,
`moon -C benchmarks test --target all`, and `moon run scripts/benchmark.mbtx xxx`.
Run `moon run scripts/benchmark_report.mbtx --self-test` when changing report logic.

When adding a library, update both workspace member lists, the root catalog,
comparison packages, benchmark collection and inventory, native coverage export,
CI report artifacts/upload files, and the explicit script formatting list.

## Git and GitHub identity routing

Before an authenticated GitHub operation, run `git rev-parse --show-toplevel`.
Compare the root case-insensitively, accepting both slash styles:

- Under `D:\jianchang56` (including that directory itself), select
  `jianchang56` with
  `gh auth switch --hostname github.com --user jianchang56`; verify
  `gh api user --jq .login` returns `jianchang56`. The expected commit author is
  `舰伥 <jianchang_56@qq.com>`.
- In every other repository, select `justjavac` with
  `gh auth switch --hostname github.com --user justjavac`; verify
  `gh api user --jq .login` returns `justjavac`. The expected commit author is
  `迷渡 <justjavac@gmail.com>`.

Apply this routing to `git fetch`, `pull`, and `push`, creating or changing
remotes, and all `gh` account, repository, PR, issue, release, comment, and
workflow operations. Stop remote operations if switching or verification fails.
Git commit identity remains controlled by the existing `includeIf` configuration
and global hooks; do not change identity settings or print authentication tokens.

## References

- [MoonBit core agent guide](https://github.com/moonbitlang/core/blob/main/AGENTS.md)
- [Current SIMD API](https://mooncakes.io/docs/moonbitlang/core/simd)
- [Historical v128 API](https://mooncakes.io/docs/moonbitlang/core/v128)
- [crc32fast](https://crates.io/crates/crc32fast): CRC32 API and algorithm reference.
- [CRC32 guide](crc32/README.md), [URL guide](url/README.md),
  [UTF-8 guide](utf8/README.md), [Base64 guide](base64/README.md),
  [integer guide](atoi/README.md), [UUID guide](uuid/README.md), and
  [word count guide](wc/README.md): module-specific contracts.
- [Comparison harness](benchmarks/README.md), [collector](scripts/benchmark.mbtx),
  [report generator](scripts/benchmark_report.mbtx), and
  [native coverage exporter](scripts/coverage_report.mbtx): shared automation.
