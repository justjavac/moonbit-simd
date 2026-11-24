///|
/// A parsed WHATWG URL backed by one immutable serialized string and component offsets.
///
/// Getter views avoid component-string allocation. MoonBit's garbage collector
/// keeps an earlier view alive across setters, so a view remains a snapshot of
/// the previous value. Unlike Ada's C++ string views, it never becomes dangling.
/// Assigning a Url shares mutable setter state; use `copy()` for an independent
/// URL. Parsing and failed setters do not mutate a base or partially change state.
struct Url {
  mut text : String
  mut positions : Positions
  mut scheme : String
  mut opaque_path : Bool
  mut port_number : Int32?
  mut host_present : Bool
  mut query_present : Bool
  mut fragment_present : Bool
}

///|
/// Returns the complete canonical URL without allocating another string.
/// Includes empty query and fragment delimiters when they were present.
pub fn Url::href(self : Url) -> String {
  self.text
}

///|
/// Returns the lowercase ASCII scheme with its trailing colon as a view.
pub fn Url::protocol(self : Url) -> StringView {
  self.text[:self.positions.protocol_end]
}

///|
/// Returns the percent-encoded username without the credentials delimiter.
/// An absent username is an empty view; no decoding or allocation occurs.
pub fn Url::username(self : Url) -> StringView {
  self.text[self.positions.username_start:self.positions.username_end]
}

///|
/// Returns the percent-encoded password without its leading colon or trailing at sign.
/// An absent password is an empty view; no decoding or allocation occurs.
pub fn Url::password(self : Url) -> StringView {
  self.text[self.positions.password_start:self.positions.password_end]
}

///|
/// Returns the host including a non-default port, or an empty view when absent.
/// IPv6 hosts retain brackets and domains are already in ASCII/Punycode form.
pub fn Url::host(self : Url) -> StringView {
  if self.host_present {
    self.text[self.positions.hostname_start:self.positions.path_start]
  } else {
    ""
  }
}

///|
/// Returns the canonical hostname without a port, keeping IPv6 brackets.
/// Both absent hosts and the empty host of a file URL yield an empty view.
pub fn Url::hostname(self : Url) -> StringView {
  self.text[self.positions.hostname_start:self.positions.hostname_end]
}

///|
/// Returns decimal port digits without the colon, or empty for omitted/default ports.
pub fn Url::port(self : Url) -> StringView {
  if self.port_number is Some(_) {
    self.text[self.positions.port_start:self.positions.path_start]
  } else {
    ""
  }
}

///|
/// Returns the canonical path, preserving encoded slashes and normalizing dot segments.
/// Hierarchical paths include their leading slash; opaque paths do not add one.
pub fn Url::pathname(self : Url) -> StringView {
  self.text[self.positions.path_start:self.positions.path_end]
}

///|
/// Returns the query with a leading question mark, or empty for absent/empty queries.
/// Use `query()` to distinguish an absent query from a present empty query.
pub fn Url::search(self : Url) -> StringView {
  if self.query_present && self.positions.query_end > self.positions.query_start {
    self.text[self.positions.path_end:self.positions.query_end]
  } else {
    ""
  }
}

///|
/// Returns the fragment with a leading hash, or empty for absent/empty fragments.
/// Use `fragment()` to distinguish absence from a present empty fragment.
pub fn Url::hash(self : Url) -> StringView {
  if self.fragment_present && self.text.length() > self.positions.fragment_start {
    self.text[self.positions.query_end:]
  } else {
    ""
  }
}

///|
/// Returns the query without its delimiter, preserving Some("") for an empty query.
pub fn Url::query(self : Url) -> StringView? {
  if self.query_present {
    Some(self.text[self.positions.query_start:self.positions.query_end])
  } else {
    None
  }
}

///|
/// Returns the fragment without its delimiter, preserving Some("") for an empty fragment.
pub fn Url::fragment(self : Url) -> StringView? {
  if self.fragment_present {
    Some(self.text[self.positions.fragment_start:])
  } else {
    None
  }
}

///|
/// Reports whether the URL has an opaque path, such as mailto or data URLs.
/// Opaque paths cannot resolve ordinary relative references or accept path setters.
pub fn Url::has_opaque_path(self : Url) -> Bool {
  self.opaque_path
}

///|
/// Reports whether the scheme is http, https, ws, wss, ftp, or file.
pub fn Url::is_special(self : Url) -> Bool {
  is_special_scheme(self.scheme)
}

///|
/// Returns the serialized tuple origin or "null" for an opaque origin.
/// Credentials, path, query, and fragment do not contribute. File URLs have
/// opaque origins; blob URLs inherit valid inner HTTP/HTTPS URL origins.
pub fn Url::origin(self : Url) -> String {
  if self.scheme == "blob" {
    if try_parse(self.pathname()) is Some(inner) &&
      (inner.scheme == "http" || inner.scheme == "https") {
      return inner.origin()
    }
    return "null"
  }
  if !self.is_special() || self.scheme == "file" {
    return "null"
  }
  self.scheme + "://" + self.host().to_owned()
}

///|
/// Creates an independently mutable URL with the same value.
/// Immutable backing strings may be shared safely; a later setter affects only
/// its receiver. This operation does not parse, normalize, or copy input bytes.
pub fn Url::copy(self : Url) -> Url {
  {
    text: self.text,
    positions: self.positions,
    scheme: self.scheme,
    opaque_path: self.opaque_path,
    port_number: self.port_number,
    host_present: self.host_present,
    query_present: self.query_present,
    fragment_present: self.fragment_present,
  }
}

///|
/// Resolves `input` against this URL without modifying the base.
/// Raises ParseError on invalid input or an ordinary relative reference against
/// an opaque base. The new URL has independent mutable state.
pub fn Url::join(self : Url, input : StringView) -> Url raise ParseError {
  parse(input, base=self)
}

///|
/// Returns the canonical URL as an ordinary String without extra allocation.
pub fn Url::to_string(self : Url) -> String {
  self.text
}

///|
/// Compares canonical URL values; subsequent setters may change the comparison.
pub impl Eq for Url with fn equal(self, other) {
  self.text == other.text
}

///|
/// Writes the canonical serialized URL to a logger.
pub impl Show for Url with fn output(self, logger) {
  logger.write_string(self.text)
}
