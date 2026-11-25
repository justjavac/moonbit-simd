///|
/// Searches one view in numeric order, preserving first ties and NaN policies.
fn[T : Element] scalar_find(
  data : ArrayView[T],
  minimum~ : Bool,
  maximum~ : Bool,
  propagate_nan~ : Bool,
) -> (Int32, Int32)? {
  guard !data.is_empty() else { return None }
  let mut first = 0
  while first < data.length() && data[first].is_nan() {
    if propagate_nan {
      return Some((first, first))
    }
    first += 1
  }
  guard first < data.length() else { return Some((0, 0)) }
  let mut low = first
  let mut high = first
  let mut low_value = data[first]
  let mut high_value = low_value
  for i in (first + 1)..<data.length() {
    let value = data[i]
    if value.is_nan() {
      if propagate_nan {
        return Some((i, i))
      }
    } else if minimum && value < low_value {
      low = i
      low_value = value
    } else if maximum && value > high_value {
      high = i
      high_value = value
    }
  }
  Some((low, high))
}
