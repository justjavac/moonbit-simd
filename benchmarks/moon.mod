name = "justjavac/benchmarks"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/justjavac/moonbit-simd"

license = "MIT"

description = "Development-only cross-library CRC32, WHATWG URL, UTF-8, Base64, decimal integer, UUID, and Ryu benchmarks"

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
  "justjavac/utf8@0.1.0",
  "tonyfettes/utf8@0.2.4",
  "justjavac/base64@0.1.0",
  "justjavac/atoi@0.1.0",
  "gmlewis/base64@0.16.15",
  "kujirahand/base64@0.1.1",
  "moonbitstack/moonbase@0.5.1",
  "justjavac/uuid@0.1.0",
  "justjavac/ryu@0.1.0",
  "bobzhang/uuidm@0.2.0",
  "f4ah6o/uuidm@0.2.1",
  "moonbitstack/moonuuid@0.2.1",
  "wulisususu/moonuuid@0.1.0",
}
