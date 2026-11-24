name = "justjavac/benchmarks"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/justjavac/moonbit-simd"

license = "MIT"

description = "Development-only cross-library CRC32 benchmark adapters"

preferred_target = "native"

warnings = "+missing_doc+test_unqualified_package"

import {
  "justjavac/crc32@0.1.0",
  "gaato/crc@0.1.1",
  "gmlewis/crc32@0.9.3",
  "kujirahand/crc32@0.1.1",
  "moonbitstack/mooncrypt@0.5.2",
}
