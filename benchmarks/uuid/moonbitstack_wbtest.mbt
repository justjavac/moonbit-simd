///|
/// Observes the public MoonUUID parser's recoverable rejection.
fn stack_rejected(input : StringView) -> Bool {
  try @stack.parse(input) catch {
    _ => true
  } noraise {
    _ => false
  }
}

///|
test "moonbitstack UUID adapters match independent results" {
  verify_library(
    input => try! @stack.parse(input),
    id => id.bytes(),
    id => id.to_string(),
    stack_rejected,
    simple=id => id.hex(),
    braced=true,
  )
}

///|
test "bench moonbitstack UUID public operations" (bench : @bench.T) {
  benchmark_library(
    bench,
    "moonbitstack",
    input => try! @stack.parse(input),
    id => id.to_string(),
    stack_rejected,
    simple=id => id.hex(),
    braced=true,
  )
  println("BENCHMARK_RESULTS " + bench.dump_summaries())
}
