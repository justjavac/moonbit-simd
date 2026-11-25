///|
/// Avoids JavaScript BigInt word operations by scanning ordinary byte values.
#cfg(target="js")
fn scalar_find(needles : Needles, data : BytesView) -> Int32? {
  let (a, b, c, arity) = needles.values()
  for index in 0..<data.length() {
    let byte = data[index]
    if byte == a || (arity >= 2 && byte == b) || (arity == 3 && byte == c) {
      return Some(index)
    }
  }
  None
}

///|
/// Searches backward with byte comparisons and bounds relative to the view.
#cfg(target="js")
fn scalar_rfind(needles : Needles, data : BytesView) -> Int32? {
  let (a, b, c, arity) = needles.values()
  for end = data.length(); end > 0; end = end - 1 {
    let byte = data[end - 1]
    if byte == a || (arity >= 2 && byte == b) || (arity == 3 && byte == c) {
      return Some(end - 1)
    }
  }
  None
}

///|
/// Counts each matching byte once without constructing BigInts or result arrays.
#cfg(target="js")
fn scalar_count(needles : Needles, data : BytesView) -> Int32 {
  let (a, b, c, arity) = needles.values()
  let mut count = 0
  for index in 0..<data.length() {
    let byte = data[index]
    if byte == a || (arity >= 2 && byte == b) || (arity == 3 && byte == c) {
      count = count + 1
    }
  }
  count
}
