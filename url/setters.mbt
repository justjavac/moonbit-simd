///|
/// Determines whether a URL can hold credentials or a port.
fn Url::allows_credentials(self : Url) -> Bool {
  !self.opaque_path &&
  self.host_present &&
  !self.hostname().is_empty() &&
  self.scheme != "file"
}

///|
/// Replaces the complete URL atomically, returning false when input cannot parse.
/// Input is parsed as an absolute URL without a base. All earlier getter views
/// remain safe snapshots, and a failure leaves every component unchanged.
pub fn Url::set_href(self : Url, input : StringView) -> Bool {
  if try_parse(input) is Some(next) {
    self.assign(next)
    true
  } else {
    false
  }
}

///|
/// Changes the scheme, lowercasing ASCII and accepting an optional colon suffix.
/// Returns false for invalid schemes, special/non-special transitions, or file
/// transitions prohibited by credentials, a port, or an empty file host.
/// A port equal to the new scheme's default is removed. Failure is atomic.
pub fn Url::set_protocol(self : Url, input : StringView) -> Bool {
  let data = prepare_setter(input)
  let candidate = if data.find(b":") is Some(at) { data[:at] } else { data }
  let with_colon = @utf8.decode_lossy(candidate, ignore_bom=true) + ":"
  if scheme_end(@utf8.encode(with_colon)) is None {
    return false
  }
  let scheme = lower_ascii(candidate)
  if is_special_scheme(scheme) != self.is_special() ||
    (
      scheme == "file" &&
      (
        !self.username().is_empty() ||
        !self.password().is_empty() ||
        self.port_number is Some(_)
      )
    ) ||
    (self.scheme == "file" && self.hostname().is_empty() && scheme != "file") {
    return false
  }
  let record = self.record()
  record.scheme = scheme
  if record.port == default_port(scheme) {
    record.port = None
  }
  self.assign(freeze(record))
  true
}

///|
/// Replaces the username with WHATWG userinfo percent encoding.
/// Returns false for file URLs, opaque paths, or absent/empty hosts. The input
/// is not percent-decoded: existing percent signs remain literal escapes.
pub fn Url::set_username(self : Url, input : StringView) -> Bool {
  if !self.allows_credentials() {
    return false
  }
  let record = self.record()
  record.username = encode_text(input, Userinfo)
  self.assign(freeze(record))
  true
}

///|
/// Replaces the password with WHATWG userinfo percent encoding.
/// Returns false for file URLs, opaque paths, or absent/empty hosts. Empty
/// input removes the password and its colon without changing the username.
pub fn Url::set_password(self : Url, input : StringView) -> Bool {
  if !self.allows_credentials() {
    return false
  }
  let record = self.record()
  record.password = encode_text(input, Userinfo)
  self.assign(freeze(record))
  true
}

///|
/// Applies a host or hostname setter after independently validating its new components.
fn Url::set_host_impl(
  self : Url,
  input : StringView,
  hostname_only : Bool,
) -> Bool {
  if self.opaque_path {
    return false
  }
  let data = prepare_setter(input)
  let end = authority_end(data, self.is_special(), true).min(
    data.find(b"#").unwrap_or(data.length()),
  )
  let data = data[:end]
  let colon = if data.has_prefix(b"[") {
    match data.find(b"]") {
      Some(at) => if at + 1 < data.length() { Some(at + 1) } else { None }
      None => return false
    }
  } else {
    data.find(b":")
  }
  if hostname_only && colon is Some(_) {
    return false
  }
  if self.scheme == "file" && colon is Some(_) {
    return false
  }
  if colon is Some(at) && data[at] != b':' {
    return false
  }
  let host = if colon is Some(at) { data[:at] } else { data }
  if host.is_empty() &&
    (
      colon is Some(_) ||
      (self.is_special() && self.scheme != "file") ||
      !self.username().is_empty() ||
      !self.password().is_empty() ||
      self.port_number is Some(_)
    ) {
    return false
  }
  let record = self.record()
  let hostname = if host.is_empty() {
    ""
  } else {
    parse_host(host, self.is_special()) catch {
      _ => return false
    }
  }
  record.host = Some(
    if self.scheme == "file" && hostname == "localhost" {
      ""
    } else {
      hostname
    },
  )
  if colon is Some(at) && at + 1 < data.length() {
    record.port = parse_port(data[at + 1:], self.scheme, true) catch {
      _ => self.port_number
    }
  }
  self.assign(freeze(record))
  true
}

///|
/// Changes the hostname and an optional port using WHATWG host parsing.
/// Stops at path/query/fragment delimiters, ignores tabs/newlines, and normalizes
/// domains/IP literals. An omitted or empty port preserves the existing port.
/// Invalid port suffixes preserve the old port after a valid hostname change.
/// Returns false without changing the URL for invalid hosts or opaque paths.
pub fn Url::set_host(self : Url, input : StringView) -> Bool {
  self.set_host_impl(input, false)
}

///|
/// Changes only the hostname and preserves the existing port.
/// Uses the same normalization as `set_host` but rejects a port suffix. File
/// localhost becomes an empty host; an invalid input leaves the URL unchanged.
pub fn Url::set_hostname(self : Url, input : StringView) -> Bool {
  self.set_host_impl(input, true)
}

///|
/// Changes a decimal port or clears it with empty input.
/// A trailing nondigit terminates a digit prefix as in the WHATWG setter.
/// Out-of-range values, missing initial digits, and URLs that cannot hold a
/// port return false atomically. Default ports are normalized to absence.
pub fn Url::set_port(self : Url, input : StringView) -> Bool {
  if !self.allows_credentials() {
    return false
  }
  let data = prepare_setter(input)
  if !input.is_empty() && data.is_empty() {
    return false
  }
  let next = parse_port(data, self.scheme, true) catch { _ => return false }
  let record = self.record()
  record.port = next
  self.assign(freeze(record))
  true
}

///|
/// Changes a hierarchical path with dot-segment normalization and percent encoding.
/// Question marks and hashes are path data, not query/fragment delimiters.
/// Special schemes treat backslashes as slashes; file drive roots are protected.
/// Returns false for opaque paths without changing the URL.
pub fn Url::set_pathname(self : Url, input : StringView) -> Bool {
  if self.opaque_path {
    return false
  }
  let record = self.record()
  record.path = ""
  let data = prepare_setter(input)
  if data.is_empty() && !self.is_special() && self.host_present {
    record.path = ""
  } else {
    parse_path(data, record, true)
  }
  self.assign(freeze(record))
  true
}

///|
/// Replaces the query, accepting an optional leading question mark.
/// Empty input removes the query; "?" preserves a present empty query. Uses the
/// special-query encode set for special schemes and does not modify the fragment.
pub fn Url::set_search(self : Url, input : StringView) -> Unit {
  let record = self.record()
  if input.is_empty() {
    record.query = None
  } else {
    let data = prepare_setter(input)
    let value = if data.has_prefix(b"?") { data[1:] } else { data }
    record.query = Some(
      encode_bytes(value, if self.is_special() { SpecialQuery } else { Query }),
    )
  }
  self.assign(freeze(record))
}

///|
/// Replaces the fragment, accepting an optional leading hash.
/// Empty input removes the fragment; "#" preserves a present empty fragment.
/// Uses the fragment encode set and does not modify the query.
pub fn Url::set_hash(self : Url, input : StringView) -> Unit {
  let record = self.record()
  if input.is_empty() {
    record.fragment = None
  } else {
    let data = prepare_setter(input)
    let value = if data.has_prefix(b"#") { data[1:] } else { data }
    record.fragment = Some(encode_bytes(value, Fragment))
  }
  self.assign(freeze(record))
}
