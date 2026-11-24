///|
/// Identifies literal and percent-encoded single-dot or double-dot path segments.
fn dot_kind(segment : String) -> Int32 {
  match segment.to_lower() {
    "." | "%2e" => 1
    ".." | ".%2e" | "%2e." | "%2e%2e" => 2
    _ => 0
  }
}

///|
/// Removes the final path segment while preserving a file URL's root drive.
fn shorten(path : String, file : Bool) -> String {
  let body = if path.has_prefix("/") { path[1:] } else { path[:] }
  if file && is_drive(body) {
    return path
  }
  if path.rev_find("/") is Some(at) {
    path[:at].to_owned()
  } else {
    ""
  }
}

///|
/// Extracts a file base's normalized drive segment for rooted relative references.
fn first_drive(path : String) -> String? {
  let body = if path.has_prefix("/") { path[1:] } else { path[:] }
  let first = body.split_once("/").map(pair => pair.0).unwrap_or(body)
  if is_drive(first) {
    Some(first.to_owned())
  } else {
    None
  }
}

///|
/// Parses hierarchical segments with dot normalization and file drive protection.
fn parse_path(input : BytesView, record : Record, rooted : Bool) -> Unit {
  let special = is_special_scheme(record.scheme)
  let file = record.scheme == "file"
  let segments : Array[String] = []
  if !rooted && !record.path.is_empty() {
    let base = if record.path.has_prefix("/") {
      record.path[1:]
    } else {
      record.path[:]
    }
    for part in base.split("/") {
      segments.push(part.to_owned())
    }
  }
  let mut start = if !input.is_empty() &&
    (input[0] == b'/' || (special && input[0] == b'\\')) {
    1
  } else {
    0
  }
  let mut i = start
  while i <= input.length() {
    if i < input.length() && input[i] != b'/' && !(special && input[i] == b'\\') {
      i += 1
      continue
    }
    let last = i == input.length()
    let segment = encode_bytes(input[start:i], Path)
    match dot_kind(segment) {
      1 => if last { segments.push("") }
      2 => {
        if !segments.is_empty() &&
          !(file && segments.length() == 1 && is_drive(segments[0])) {
          let _ = segments.pop()
        }
        if last {
          segments.push("")
        }
      }
      _ =>
        if file && segments.is_empty() && is_drive(segment) {
          segments.push(segment[:1].to_owned() + ":")
        } else {
          segments.push(segment)
        }
    }
    i += 1
    start = i
  }
  record.path = "/" + segments.join("/")
}

///|
/// Splits query from a hierarchical suffix and applies scheme-specific encoding.
fn parse_suffix(input : BytesView, record : Record, rooted : Bool) -> Unit {
  let query_at = input.find(b"?")
  let path = if query_at is Some(at) { input[:at] } else { input }
  parse_path(path, record, rooted)
  record.query = query_at.map(at => {
    encode_bytes(
      input[at + 1:],
      if is_special_scheme(record.scheme) {
        SpecialQuery
      } else {
        Query
      },
    )
  })
}
