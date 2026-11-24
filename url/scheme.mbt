///|
/// Checks whether a byte is an ASCII letter without locale-dependent behavior.
#inline
fn is_alpha(byte : Byte) -> Bool {
  (byte >= b'A' && byte <= b'Z') || (byte >= b'a' && byte <= b'z')
}

///|
/// Identifies the six WHATWG special schemes.
fn is_special_scheme(scheme : String) -> Bool {
  match scheme {
    "http" | "https" | "ws" | "wss" | "ftp" | "file" => true
    _ => false
  }
}

///|
/// Returns a special scheme's default port, with file having no port.
fn default_port(scheme : String) -> Int32? {
  match scheme {
    "http" | "ws" => Some(80)
    "https" | "wss" => Some(443)
    "ftp" => Some(21)
    _ => None
  }
}

///|
/// Locates the colon of a valid ASCII scheme, leaving relative references untouched.
fn scheme_end(input : BytesView) -> Int32? {
  if input.is_empty() || !is_alpha(input[0]) {
    return None
  }
  for i = 1; i < input.length(); i = i + 1 {
    let c = input[i]
    if c == b':' {
      return Some(i)
    }
    if !(is_alpha(c) ||
      (c >= b'0' && c <= b'9') ||
      c == b'+' ||
      c == b'-' ||
      c == b'.') {
      return None
    }
  }
  None
}

///|
/// Recognizes a Windows drive-letter segment with colon or vertical bar.
fn is_drive(segment : StringView) -> Bool {
  segment.length() == 2 &&
  (
    (segment[0] >= 65 && segment[0] <= 90) ||
    (segment[0] >= 97 && segment[0] <= 122)
  ) &&
  (segment[1] == 58 || segment[1] == 124)
}

///|
/// Checks the drive-letter prefix rules used while resolving file URLs.
fn starts_drive(input : BytesView) -> Bool {
  input.length() >= 2 &&
  is_alpha(input[0]) &&
  (input[1] == b':' || input[1] == b'|') &&
  (
    input.length() == 2 ||
    input[2] == b'/' ||
    input[2] == b'\\' ||
    input[2] == b'?'
  )
}
