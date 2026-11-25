///|
/// Uses the public URN parser only for the URN workload, timing required ownership.
fn bob_parse(input : StringView) -> @bob.Uuid {
  let parsed = if input.length() == 45 {
    @bob.from_urn(input.to_owned())
  } else {
    @bob.from_string(input.to_owned())
  }
  parsed.unwrap_or_else(() => abort("bobzhang rejected a valid benchmark UUID"))
}

///|
/// Observes the competitor's public rejection result including input ownership.
fn bob_rejected(input : StringView) -> Bool {
  @bob.from_string(input.to_owned()) is None
}

///|
test "bobzhang UUID adapters match independent results" {
  verify_library(
    bob_parse,
    id => Bytes::from_array(id.bytes()),
    id => id.to_string(),
    bob_rejected,
    simple=id => id.to_string_simple(),
    braced=false,
  )
}

///|
test "bench bobzhang UUID public operations" (bench : @bench.T) {
  benchmark_library(
    bench,
    "bobzhang",
    bob_parse,
    id => id.to_string(),
    bob_rejected,
    simple=id => id.to_string_simple(),
    braced=false,
  )
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
