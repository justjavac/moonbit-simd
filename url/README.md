# justjavac/url

A portable MoonBit port of Ada's core [WHATWG URL](https://url.spec.whatwg.org/)
parser: normalization, relative resolution, component setters, origins, and
form-urlencoded query parameters. Native, Wasm, Wasm GC, and JavaScript share the
same public behavior on Windows, Linux, and macOS.

The implementation follows [Ada revision
8a4bf2e](https://github.com/ada-url/ada/tree/8a4bf2e213a6519534d04128f7c2002c0494af5c).
It adapts Ada's state transitions, host/IP and path rules, ASCII fast paths,
64-bit SWAR case folding, and compact serialized representation to MoonBit.
Unicode mapping, NFC, Punycode, Bidi, and joiner validation use the independently
maintained `moonbit-community/unicode-idna` dependency, pinned at 0.8.1.

This module implements the core URL and query APIs. Ada's C/C++ bindings, CLI,
regex-provider-dependent URLPattern, and experimental route-list API are not
part of this module.

## Installation and imports

From another MoonBit module:

```text
moon add justjavac/url
```

Add the package to `moon.pkg`:

```text
import {
  "justjavac/url",
}
```

The package name and interface are ready for independent publication; availability
in Mooncakes depends on a separately published release. Within this repository,
`moon.work` selects the local module. The runtime has no C FFI or platform-specific
dependencies. Competing URL libraries belong to the separate development-only
[benchmark module](../benchmarks/README.md).

## Parsing and resolution

```mbt check
test {
  let url = @url.parse("HTTPS://alice:p@Example.COM:443/a/../b?q=hello world#top")
  assert_eq(url.href(), "https://alice:p@example.com/b?q=hello%20world#top")
  assert_eq(url.protocol().to_owned(), "https:")
  assert_eq(url.username().to_owned(), "alice")
  assert_eq(url.hostname().to_owned(), "example.com")
  assert_eq(url.port().to_owned(), "")
  assert_eq(url.pathname().to_owned(), "/b")
  assert_eq(url.origin(), "https://example.com")
  let relative = @url.parse("../next?x=1", base=url)
  assert_eq(relative.href(), "https://alice:p@example.com/next?x=1")
  assert_true(@url.can_parse("#section", base=url))
  assert_eq(@url.try_parse("http://[broken"), None)
}
```

`parse(input, base?, simd=true)` accepts a `StringView` and raises `ParseError`
for invalid hosts, IP literals, ports, or missing/incompatible bases. `try_parse`
returns `Url?`; `can_parse` returns `Bool` and currently performs full
normalization. `Url::join` resolves against its receiver and returns an
independently mutable URL. A supplied base must already be parsed and is never
modified.

This is the WHATWG grammar, rather than generic RFC 3986 parsing. It lowercases
schemes and special hosts, removes default ports and dot segments, normalizes
unusual IPv4 number spellings, compresses IPv6, treats special-scheme backslashes
as slashes, handles Windows file-drive roots, and encodes components as required.
Recoverable validation issues are normalized; invalid URL structures fail.

Input uses MoonBit's UTF-16 string representation. UTF-8 conversion replaces
unpaired surrogates with U+FFFD as Web IDL USVString requires. Parsing removes
embedded ASCII tabs/newlines and trims leading/trailing C0 controls and spaces.
Existing path/query percent escapes are preserved without double decoding;
host escapes are decoded before domain processing. Unicode path/query/fragment
bytes use uppercase percent escapes.

## Getters and empty components

| Method | Result |
| --- | --- |
| `href`, `to_string` | Complete canonical `String`, without new serialization |
| `protocol` | Lowercase scheme followed by `:` |
| `username`, `password` | Encoded credentials without delimiters |
| `host` | Hostname plus an optional non-default port |
| `hostname` | ASCII/Punycode host, retaining IPv6 brackets |
| `port` | Decimal digits, empty when omitted/default |
| `pathname` | Normalized hierarchical or opaque path |
| `search`, `hash` | Delimited nonempty query/fragment; empty otherwise |
| `query`, `fragment` | Optional undelimited views, preserving `Some("")` |
| `origin` | Tuple origin, or `"null"` for an opaque origin |
| `is_special`, `has_opaque_path` | Scheme/path classification |

Component getters return `StringView` slices into one serialized backing string.
`https://example.com/?#` retains both empty delimiters in `href`, even though
`search` and `hash` are empty. `query` and `fragment` distinguish these from
absent components. File URLs have opaque origins; blob URLs inherit a valid inner
HTTP/HTTPS origin.

## Mutation and ownership

```mbt check
test {
  let url = @url.parse("https://example.com/a")
  let old_host = url.hostname()
  let copy = url.copy()
  assert_true(url.set_hostname("Other.Example"))
  assert_true(url.set_port("8443"))
  assert_true(url.set_pathname("/b/../c"))
  url.set_search("q=hello world")
  assert_eq(url.href(), "https://other.example:8443/c?q=hello%20world")
  assert_eq(old_host.to_owned(), "example.com")
  assert_eq(copy.href(), "https://example.com/a")
}
```

`Url` has mutable reference semantics: assignments share setter state. `copy()`
creates an independently mutable URL while safely sharing immutable strings.
Earlier getter views remain snapshots after a setter because MoonBit retains
their immutable backing string. This differs from Ada's C++ view invalidation
rules and prevents dangling references.

`set_href`, `set_protocol`, `set_username`, `set_password`, `set_host`,
`set_hostname`, `set_port`, and `set_pathname` return a success flag.
Invalid host/scheme/port input and unsupported setters preserve the previous URL.
As the WHATWG host setter requires, a valid new hostname is applied even if its
port suffix is invalid; that port is ignored and the old port is preserved.
An omitted or empty port in `set_host` also preserves the current port.
`set_hostname` rejects a port suffix. The standalone port setter accepts a digit
prefix followed by nondigits and removes a new default port.

`set_search` and `set_hash` always encode their new component. Empty input removes
the component; `"?"` or `"#"` keeps a present empty component. Path setters encode
question marks and hashes as path data. Opaque-path URLs reject path changes and
ordinary relative resolution. File URLs reject credentials and ports. Scheme
changes cannot cross the special/non-special boundary.

## Query parameters

```mbt check
test {
  let url = @url.parse("https://example.com/?a=hello+world&a=second&empty")
  let params = url.search_params()
  assert_eq(params.get_all("a"), ["hello world", "second"])
  assert_eq(params.get("empty"), Some(""))
  params.set("a", "one & two")
  params.append("z", "")
  params.sort()
  url.set_search_params(params)
  assert_eq(url.href(), "https://example.com/?a=one+%26+two&empty=&z=")
}
```

`SearchParams::new`, `parse`, and `from_pairs` create ordered decoded lists.
Parsing accepts one leading `?`, skips empty ampersand fields, decodes plus as
space, preserves invalid percent escapes, and replaces malformed UTF-8.
`append`, `set`, `delete(name, value?)`, `get`, `get_all`, and `has(name, value?)`
preserve duplicate-name semantics. `size` counts pairs; `reset` reparses a query.
`sort` is stable and compares UTF-16 code units. `entries`, `keys`, and `values`
iterate independent snapshots. `copy()` creates independent mutable state.

Serialization uses application/x-www-form-urlencoded: spaces become `+`, and
all bytes except ASCII alphanumerics and `*-._` are percent encoded. Every pair
has an equals sign, and order/duplicates are preserved. Parameters from a URL are
detached, following Ada's API; use `set_search_params` to apply changes explicitly.
Applying an empty list removes the URL query.

## Domains and DNS

`domain_to_ascii` and `domain_to_unicode` expose nontransitional UTS #46
conversion. Hyphen/DNS length checks are disabled; Bidi and joiner checks are
enabled. ASCII domains follow WHATWG's non-strict ASCII rule, even for an existing
invalid ACE label; forbidden domain characters still fail. Empty input returns
an empty string, while URL parsing separately rejects an empty special host.
The adapter preserves WHATWG empty labels, including labels emptied by ignored
Unicode characters.

`verify_dns_length` explicitly checks ASCII labels of 1..63 bytes and a domain
of at most 253 bytes, excluding one optional root dot. Ordinary URL parsing
does not impose these DNS limits. DNS conversion performs no network lookup.

## Portability, SIMD, and limits

The checked toolchain is `moon 0.1.20261120` / `moonc
v0.10.22+7b085e9a4-nightly`, with experimental `moonbitlang/core/simd` support.
CI selects the nightly channel explicitly and records its exact version.
Native builds require MSVC, GCC, or Clang; JavaScript execution requires Node.js.

Canonical special-scheme ASCII URLs can bypass UTF-8 conversion and component
construction, retaining the serialized string directly. The conservative fast
path falls back for characters, ports, IP spellings, and dot segments requiring
normalization. General parsing uses Ada-style 64-bit ASCII case folding and
checked 16-byte V128 scans for ignored characters and authority boundaries.
The canonical UTF-16 guard uses checked eight-code-unit vector loads for requests
of at least 64 code units; short guards stay scalar to avoid setup overhead.
SIMD requests on Wasm GC/JS use scalar fallback. Each load is bounded by a
matched bitstring or a checked view length, including offset subviews.

No CPU feature or architecture is assumed beyond the selected backend's V128
support. Ada's optional simdutf and architecture-specific AVX-512 IP kernels are
not used. SIMD alone is not a speed guarantee; consult
[BENCHMARK.md](BENCHMARK.md) for actual costs by backend and workload.
URLs and intermediate encoded strings must fit MoonBit's Int-indexed string and
allocation limits; percent encoding can expand UTF-8 bytes threefold. This
module does not implement Ada's process-wide configurable input-length cap.

## Tests, coverage, and performance

From the repository root:

```text
moon check --target all --deny-warn
moon test --target all
moon test --target native --enable-coverage
moon run scripts/coverage_report.mbtx local url
moon info
moon fmt
moon -C benchmarks test --target all
moon run scripts/benchmark.mbtx url
```

The suite embeds the complete pinned Ada URL/setter fixtures, its long Unicode
case, 87 WHATWG ToASCII cases, 2676 IDNA Test V2 cases, and DNS-length cases.
It checks scalar and SIMD requests against 935 upstream URL vectors and 800
independently normalized Node.js vectors, verifies ownership/mutation and query
semantics, and checks vector boundaries, tails, unaligned views, and SWAR parity.
The independent fixture was generated with Node.js v24.1.0 / embedded Ada 3.2.3.
JSON fixture loading replaces unpaired surrogate escapes as Web IDL requires;
test cases and expected outcomes are retained.

Regenerate fixtures with the checked-in MoonBit scripts:

```text
moon run scripts/url_fixtures.mbtx <checkout-of-pinned-Ada>
moon run scripts/url_oracle.mbtx
```

Native coverage runs on Windows, Linux, and macOS in CI, alongside all supported
backend tests. Filtered Cobertura reports include only this module. The benchmark
suite checks matching results before timing, uses separate binaries for each
library, and records 144 cases per backend. The report highlights key workloads;
[BENCHMARK-DATA.json](BENCHMARK-DATA.json) preserves the exhaustive CI snapshot.
Local measurements are labelled local and cannot be published as CI results.

Windows native coverage measured 721/742 executable lines (97.17%) on the
validated compiler. The coverage script uses `moon coverage report` with explicit
native trace sources: `moon coverage analyze` automatically reruns the default
Wasm target, and merging its metadata with native traces can fail on this
toolchain. Do not combine coverage metadata from different backends or source
revisions; native instrumented tests must immediately precede report generation.

## License and references

This port is MIT licensed. [LICENSE](LICENSE) retains the copyright of Ada's
authors, Yagiz Nizipli and Daniel Lemire. Dependency code retains its own license.
Embedded WPT data retains its [BSD notice](TEST-DATA-LICENSE.md); Ada's extra
fixtures retain Ada's MIT notice. The generated Node fixture is original test
data produced through Node's public URL API.

- [Ada source](https://github.com/ada-url/ada)
- [WHATWG URL Standard](https://url.spec.whatwg.org/)
- [Unicode UTS #46](https://www.unicode.org/reports/tr46/)
- [MoonBit Unicode IDNA](https://github.com/moonbit-community/tonyfettes-unicode)
- [Parsing Millions of URLs per Second](https://doi.org/10.1002/spe.3296)
