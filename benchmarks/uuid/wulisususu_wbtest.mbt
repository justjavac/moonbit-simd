///|
/// Calls the interoperable parser so compact, braced, and URN inputs are equivalent.
fn wuli_parse(input : StringView) -> @wuli.Uuid {
  match @wuli.parse_permissive(input.to_owned()) {
    Ok(id) => id
    Err(_) => abort("wulisususu rejected a valid benchmark UUID")
  }
}

///|
/// Times the public Result-returning parser and its required String ownership.
fn wuli_rejected(input : StringView) -> Bool {
  @wuli.parse_permissive(input.to_owned()) is Err(_)
}

///|
test "wulisususu UUID adapters match independent results" {
  verify_library(
    wuli_parse,
    @wuli.to_bytes,
    @wuli.to_string,
    wuli_rejected,
    braced=true,
  )
}

///|
test "bench wulisususu UUID public operations" (bench : @bench.T) {
  // This package does not expose a compact formatter; that case is omitted.
  benchmark_library(
    bench,
    "wulisususu",
    wuli_parse,
    @wuli.to_string,
    wuli_rejected,
    braced=true,
  )
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
