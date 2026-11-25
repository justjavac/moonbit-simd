///|
/// Routes URNs to the fork's public API and times the required String conversion.
fn fork_parse(input : StringView) -> @fork.Uuid {
  let parsed = if input.length() == 45 {
    @fork.from_urn(input.to_owned())
  } else {
    @fork.from_string(input.to_owned())
  }
  parsed.unwrap_or_else(() => abort("f4ah6o rejected a valid benchmark UUID"))
}

///|
/// Observes the fork's public rejection result without correcting its grammar.
fn fork_rejected(input : StringView) -> Bool {
  @fork.from_string(input.to_owned()) is None
}

///|
test "f4ah6o UUID adapters match independent results" {
  verify_library(
    fork_parse,
    id => Bytes::from_array(id.bytes()),
    id => id.to_string(),
    fork_rejected,
    simple=id => id.to_string_simple(),
    braced=false,
  )
}

///|
test "bench f4ah6o UUID public operations" (bench : @bench.T) {
  benchmark_library(
    bench,
    "f4ah6o",
    fork_parse,
    id => id.to_string(),
    fork_rejected,
    simple=id => id.to_string_simple(),
    braced=false,
  )
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
