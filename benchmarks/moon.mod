name = "justjavac/benchmarks"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/justjavac/moonbit-simd"

license = "MIT"

description = "Development-only cross-library CRC32 and WHATWG URL benchmarks"

preferred_target = "native"

warnings = "+missing_doc+test_unqualified_package"

import {
  "justjavac/crc32@0.1.0",
  "gaato/crc@0.1.1",
  "gmlewis/crc32@0.9.3",
  "kujirahand/crc32@0.1.1",
  "moonbitstack/mooncrypt@0.5.2",
  "justjavac/url@0.1.0",
  "tonyfettes/url@0.3.5",
  "moonbitstack/moonurl@0.3.1",
  "connect0459/urllib@0.6.0",
}
