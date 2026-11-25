# tonyfettes/utf8 benchmark dependency

This is a development-only compatibility copy of the Mooncakes distribution
`tonyfettes/utf8@0.2.4`, fetched with `moon fetch tonyfettes/utf8@0.2.4`.
The published package uses `moon.mod.json` and `moon.pkg.json`, which the
2026-11-20 MoonBit toolchain rejects. The text manifests above and syntax updates
make that exact production source buildable without changing its validation
or decoding algorithms. Its Apache-2.0 license is preserved in [LICENSE](LICENSE).

Only `utf8.mbt` and the license are incorporated; upstream tests, generated
interfaces, and unrelated distributed files are not used. Run `moon info` to
regenerate the public interface. This module belongs only to the comparison
workspace, and is never a dependency of `justjavac/utf8`.

See [the upstream repository](https://github.com/moonbit-community/tonyfettes-utf8).

The original `utf8.mbt` SHA-256 is
`b1e652c7b968cb86ac38b9f9960b11b4b2736803a4f91082ae4d6287e3604690`.
Compatibility edits replace the removed suberror syntax, functional `loop`
syntax, `BytesView.to_bytes`, `StringBuilder::new`, and `@string.View` aliases,
and use the prelude `Buffer()` constructor. No range predicates or decoding
formulas are changed. Upstream's error-view behavior is preserved; comparisons check
acceptance and decoded text rather than matching its error offsets.
