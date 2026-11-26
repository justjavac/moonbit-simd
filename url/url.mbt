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
/// The returned immutable string stays valid across later setters.
pub fn Url::href(self : Url) -> String {
  self.text
}

///|
/// Returns a view of the lowercase ASCII scheme and trailing colon.
/// For example, an HTTPS URL returns `"https:"`. The view is a snapshot
/// of the current serialization.
pub fn Url::protocol(self : Url) -> StringView {
  self.text[:self.positions.protocol_end]
}

///|
/// Returns the percent-encoded username without the credentials delimiter.
/// An absent username is an empty view. Percent escapes are returned as
/// stored, and the view stays valid across later setters.
pub fn Url::username(self : Url) -> StringView {
  self.text[self.positions.username_start:self.positions.username_end]
}

///|
/// Returns a snapshot of the percent-encoded password, excluding the
/// delimiters used to serialize credentials. An absent password yields an
/// empty view.
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
/// Returns a view of the decimal port digits, excluding the colon.
/// Omitted ports and ports normalized to the scheme's default yield an
/// empty view.
pub fn Url::port(self : Url) -> StringView {
  if self.port_number is Some(_) {
    self.text[self.positions.port_start:self.positions.path_start]
  } else {
    ""
  }
}

///|
/// Returns the path after URL normalization. Hierarchical paths retain their
/// leading slash and resolved dot segments. Opaque paths return their stored
/// data. Percent-encoded slashes stay escaped.
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
/// Returns the raw serialized query as a view, excluding the question mark.
/// `None` means the delimiter was absent. `Some("")` means it was present
/// with no query bytes. Use `search_params` to decode form-style pairs.
///
/// ```mbt check
/// test {
///   let address = @url.parse("https://example.com/?")
///   let snapshot = address.query()
///   assert_true(snapshot is Some(""))
///   address.set_search("")
///   assert_true(address.query() is None)
///   assert_true(snapshot is Some(""))
/// }
/// ```
pub fn Url::query(self : Url) -> StringView? {
  if self.query_present {
    Some(self.text[self.positions.query_start:self.positions.query_end])
  } else {
    None
  }
}

///|
/// Returns the serialized fragment as a view, excluding the hash delimiter.
/// `None` means the delimiter was absent. `Some("")` means it was present
/// with an empty fragment. Percent escapes are returned as stored.
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
/// Reports whether the scheme belongs to the WHATWG special-scheme set
/// (`http`, `https`, `ws`, `wss`, `ftp`, and `file`). This classification
/// selects the relevant host, port, and path normalization rules.
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
/// Returns the same immutable full serialization as `href()`, including any
/// credentials and delimiter-only query or fragment. The string can be saved
/// as a snapshot before editing this URL.
pub fn Url::to_string(self : Url) -> String {
  self.text
}

///|
/// Tests equality of the current complete canonical serializations, including
/// query and fragment delimiters. Setters can change a later comparison.
pub impl Eq for Url with fn equal(self, other) {
  self.text == other.text
}

///|
/// Writes the full canonical serialization to the supplied logger. It includes
/// username and password components when present.
pub impl Show for Url with fn output(self, logger) {
  logger.write_string(self.text)
}
