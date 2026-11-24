///|
/// Holds mutable components only while parsing or applying a setter.
priv struct Record {
  mut scheme : String
  mut username : String
  mut password : String
  mut host : String?
  mut port : Int32?
  mut path : String
  mut query : String?
  mut fragment : String?
  mut opaque_path : Bool
}

///|
/// Initializes an empty component record with the selected scheme.
fn Record::new(scheme : String) -> Record {
  {
    scheme,
    username: "",
    password: "",
    host: None,
    port: None,
    path: "",
    query: None,
    fragment: None,
    opaque_path: false,
  }
}

///|
/// Stores UTF-16 offsets into the one serialized URL string.
priv struct Positions {
  protocol_end : Int32
  username_start : Int32
  username_end : Int32
  password_start : Int32
  password_end : Int32
  hostname_start : Int32
  hostname_end : Int32
  port_start : Int32
  path_start : Int32
  path_end : Int32
  query_start : Int32
  query_end : Int32
  fragment_start : Int32
}

///|
/// Serializes components once and records getter slices without retaining component strings.
fn freeze(record : Record) -> Url {
  let output = StringBuilder(
    capacity=record.scheme.length() + record.path.length() + 32,
  )
  output.write_string(record.scheme)
  output.write_string(":")
  let protocol_end = record.scheme.length() + 1
  let mut position = protocol_end
  if record.host is Some(_) {
    output.write_string("//")
    position += 2
  }
  let username_start = position
  output.write_string(record.username)
  position += record.username.length()
  let username_end = position
  if !record.password.is_empty() {
    output.write_string(":")
    position += 1
  }
  let password_start = position
  output.write_string(record.password)
  position += record.password.length()
  let password_end = position
  if !record.username.is_empty() || !record.password.is_empty() {
    output.write_string("@")
    position += 1
  }
  let hostname_start = position
  if record.host is Some(host) {
    output.write_string(host)
    position += host.length()
  }
  let hostname_end = position
  if record.port is Some(_) {
    output.write_string(":")
    position += 1
  }
  let port_start = position
  if record.port is Some(port) {
    let digits = port.to_string()
    output.write_string(digits)
    position += digits.length()
  }
  if record.host is None && !record.opaque_path && record.path.has_prefix("//") {
    // WHATWG prevents a hostless hierarchical path from looking like authority.
    output.write_string("/.")
    position += 2
  }
  let path_start = position
  output.write_string(record.path)
  position += record.path.length()
  let path_end = position
  if record.query is Some(_) {
    output.write_string("?")
    position += 1
  }
  let query_start = position
  if record.query is Some(query) {
    output.write_string(query)
    position += query.length()
  }
  let query_end = position
  if record.fragment is Some(_) {
    output.write_string("#")
    position += 1
  }
  let fragment_start = position
  if record.fragment is Some(fragment) {
    output.write_string(fragment)
  }
  {
    text: output.to_string(),
    positions: {
      protocol_end,
      username_start,
      username_end,
      password_start,
      password_end,
      hostname_start,
      hostname_end,
      port_start,
      path_start,
      path_end,
      query_start,
      query_end,
      fragment_start,
    },
    scheme: record.scheme,
    opaque_path: record.opaque_path,
    port_number: record.port,
    host_present: record.host is Some(_),
    query_present: record.query is Some(_),
    fragment_present: record.fragment is Some(_),
  }
}

///|
/// Materializes editable components from immutable getter views.
fn Url::record(self : Url) -> Record {
  {
    scheme: self.scheme,
    username: self.username().to_owned(),
    password: self.password().to_owned(),
    host: if self.host_present {
      Some(self.hostname().to_owned())
    } else {
      None
    },
    port: self.port_number,
    path: self.pathname().to_owned(),
    query: self.query().map(view => view.to_owned()),
    fragment: self.fragment().map(view => view.to_owned()),
    opaque_path: self.opaque_path,
  }
}

///|
/// Replaces all URL state after a successful, independent parse or setter.
fn Url::assign(self : Url, other : Url) -> Unit {
  self.text = other.text
  self.positions = other.positions
  self.scheme = other.scheme
  self.opaque_path = other.opaque_path
  self.port_number = other.port_number
  self.host_present = other.host_present
  self.query_present = other.query_present
  self.fragment_present = other.fragment_present
}
