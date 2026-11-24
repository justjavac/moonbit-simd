name = "justjavac/url"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/justjavac/moonbit-simd"

license = "MIT"

keywords = [ "url", "whatwg", "simd", "ada" ]

description = "Portable WHATWG URL parsing and normalization ported from Ada"

preferred_target = "wasm"

warnings = "+missing_doc+test_unqualified_package"

import {
  "moonbit-community/unicode-idna@0.8.1",
}
