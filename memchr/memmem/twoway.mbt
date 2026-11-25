///|
/// Searches forward using the critical factorization and bounded pair filtering.
fn search_forward(
  needle : BytesView,
  data : BytesView,
  searcher : Searcher,
  simd~ : Bool,
  prefilter~ : Bool,
) -> Int32? {
  let length = needle.length()
  guard length <= data.length() else { return None }
  if length == 0 {
    return Some(0)
  }
  if length == 1 {
    return @bytesearch.memchr(needle[0], data, simd~)
  }
  let mut position = 0
  let mut memory = 0
  let mut attempts = 0
  // At most fifty filtered candidates can reset periodic memory. Afterwards
  // pure Two-Way preserves O(n + m), even for adversarial pair collisions.
  while position <= data.length() - length {
    if prefilter && memory == 0 && attempts < 50 {
      match find_pair(needle, data[position:], searcher, simd~) {
        None => return None
        Some(skip) => position = position + skip
      }
      attempts = attempts + 1
    }
    if !searcher.contains(data[position + length - 1]) {
      position = position + length
      memory = 0
      continue
    }
    let mut index = searcher.critical.max(memory)
    while index < length && needle[index] == data[position + index] {
      index = index + 1
    }
    if index < length {
      position = position + index - searcher.critical + 1
      memory = 0
    } else {
      let mut index = searcher.critical
      while index > memory && needle[index - 1] == data[position + index - 1] {
        index = index - 1
      }
      if index <= memory {
        return Some(position)
      }
      position = position + searcher.shift
      memory = if searcher.periodic { length - searcher.shift } else { 0 }
    }
  }
  None
}

///|
/// Searches backward with upstream's distinct periodic boundary and shift rules.
fn search_reverse(
  needle : BytesView,
  data : BytesView,
  searcher : Searcher,
  simd~ : Bool,
) -> Int32? {
  let length = needle.length()
  guard length <= data.length() else { return None }
  if length == 0 {
    return Some(data.length())
  }
  if length == 1 {
    return @bytesearch.memrchr(needle[0], data, simd~)
  }
  let mut end = data.length()
  let mut memory = length
  while end >= length {
    let position = end - length
    if !searcher.contains(data[position]) {
      end = end - length
      memory = length
      continue
    }
    let mut index = searcher.critical.min(memory)
    while index > 0 && needle[index - 1] == data[position + index - 1] {
      index = index - 1
    }
    if index > 0 || needle[0] != data[position] {
      end = end - (searcher.critical - index + 1)
      memory = length
    } else {
      let mut index = searcher.critical
      while index < memory && needle[index] == data[position + index] {
        index = index + 1
      }
      // >= is essential when remembered periodic suffixes extend past the split.
      if index >= memory {
        return Some(position)
      }
      end = end - searcher.shift
      memory = if searcher.periodic { searcher.shift } else { length }
    }
  }
  None
}
