# Base64 performance

The development harness measures scalar and explicit V128 requests against
MoonBit core, gmlewis/base64, moonbitstack/moonbase/base64, and kujirahand/base64.
It verifies identical outputs before timing 200 cases per backend.

The first complete CI snapshot is pending. Local measurements are kept under
the ignored _build/benchmarks/base64 directory and are not published as CI data.
The selected report will preserve all three systems and four backends from one
source revision, workflow run, and attempt in BENCHMARK-DATA.json.
