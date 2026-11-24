///|
/// An ordered, mutable list of decoded form-urlencoded query pairs.
///
/// Duplicate names and insertion order are preserved. Parsing uses UTF-8
/// replacement for malformed bytes and decodes plus as space. Assignments share
/// mutable state; copy() creates independent state. Instances obtained from a
/// URL are detached, as in Ada; apply them with Url::set_search_params().
struct SearchParams {
  mut pairs : Array[(String, String)]
}

///|
/// Creates an empty ordered parameter list without parsing a query.
pub fn SearchParams::new() -> SearchParams {
  { pairs: [], }
}

///|
/// Parses a query or form body, accepting one optional leading question mark.
/// Empty ampersand-separated fields are skipped. Missing equals signs produce
/// empty values; invalid percent escapes remain literal. Parsing never raises.
pub fn SearchParams::parse(input : StringView) -> SearchParams {
  let body = input.strip_prefix("?").unwrap_or(input)
  let pairs : Array[(String, String)] = []
  for segment in body.split("&") {
    if segment.is_empty() {
      continue
    }
    let (name, value) = segment.split_once("=").unwrap_or((segment, ""))
    pairs.push((form_decode(name), form_decode(value)))
  }
  { pairs, }
}

///|
/// Decodes one form-urlencoded component with WHATWG UTF-8 replacement semantics.
fn form_decode(input : StringView) -> String {
  @utf8.decode_lossy(decode_bytes(@utf8.encode(input), true), ignore_bom=true)
}

///|
/// Replaces unpaired UTF-16 surrogates for a Web IDL USVString operation.
fn scalar_string(input : StringView) -> String {
  @utf8.decode_lossy(@utf8.encode(input), ignore_bom=true)
}

///|
/// Creates a parameter list from decoded pairs, preserving duplicates and order.
/// Copies the list and replaces unpaired UTF-16 surrogates in names and values.
pub fn SearchParams::from_pairs(
  pairs : ArrayView[(String, String)],
) -> SearchParams {
  { pairs: pairs.map(pair => (scalar_string(pair.0), scalar_string(pair.1))), }
}

///|
/// Copies the ordered list so later changes affect only their receiver.
/// Immutable name/value strings may be shared safely.
pub fn SearchParams::copy(self : SearchParams) -> SearchParams {
  { pairs: self.pairs.copy(), }
}

///|
/// Replaces all pairs by parsing a query with the same rules as parse().
pub fn SearchParams::reset(self : SearchParams, input : StringView) -> Unit {
  self.pairs = SearchParams::parse(input).pairs
}

///|
/// Returns the number of pairs, including repeated names and empty values.
pub fn SearchParams::size(self : SearchParams) -> Int32 {
  self.pairs.length()
}

///|
/// Appends one decoded pair at the end, preserving existing pairs.
/// Names and values use USVString replacement; encoding happens at serialization.
pub fn SearchParams::append(
  self : SearchParams,
  name : StringView,
  value : StringView,
) -> Unit {
  self.pairs.push((scalar_string(name), scalar_string(value)))
}

///|
/// Replaces the first matching name's value and removes later matching pairs.
/// If the name is absent, appends it. Other pairs retain their order.
pub fn SearchParams::set(
  self : SearchParams,
  name : StringView,
  value : StringView,
) -> Unit {
  let key = scalar_string(name)
  let item = scalar_string(value)
  let next : Array[(String, String)] = []
  let mut found = false
  for pair in self.pairs {
    if pair.0 == key {
      if !found {
        next.push((key, item))
        found = true
      }
    } else {
      next.push(pair)
    }
  }
  if !found {
    next.push((key, item))
  }
  self.pairs = next
}

///|
/// Removes every matching name, optionally restricted to an exact decoded value.
/// Retained pairs keep their order; removing an absent pair has no effect.
pub fn SearchParams::delete(
  self : SearchParams,
  name : StringView,
  value? : StringView,
) -> Unit {
  let key = scalar_string(name)
  let item = value.map(scalar_string)
  self.pairs = self.pairs.filter(pair => {
    !(pair.0 == key && (item is None || item == Some(pair.1)))
  })
}

///|
/// Returns the first matching decoded value or None, preserving Some("").
pub fn SearchParams::get(self : SearchParams, name : StringView) -> String? {
  let key = scalar_string(name)
  for pair in self.pairs {
    if pair.0 == key {
      return Some(pair.1)
    }
  }
  None
}

///|
/// Returns all matching decoded values in insertion order as an independent array.
pub fn SearchParams::get_all(
  self : SearchParams,
  name : StringView,
) -> Array[String] {
  let key = scalar_string(name)
  self.pairs.filter(pair => pair.0 == key).map(pair => pair.1)
}

///|
/// Reports whether a name is present, optionally matching an exact decoded value.
/// Empty names/values are valid and comparisons are case sensitive.
pub fn SearchParams::has(
  self : SearchParams,
  name : StringView,
  value? : StringView,
) -> Bool {
  let key = scalar_string(name)
  let item = value.map(scalar_string)
  self.pairs
  .iter()
  .any(pair => pair.0 == key && (item is None || item == Some(pair.1)))
}

///|
/// Compares parameter names by UTF-16 code units as required by WHATWG sorting.
fn compare_names(a : String, b : String) -> Int32 {
  for i in 0..<a.length().min(b.length()) {
    if a[i] != b[i] {
      return if a[i] < b[i] { -1 } else { 1 }
    }
  }
  a.length().compare(b.length())
}

///|
/// Sorts by name in ascending UTF-16 code-unit order, stably for duplicate names.
/// Values do not contribute to the ordering and remain paired with their names.
pub fn SearchParams::sort(self : SearchParams) -> Unit {
  let indexed = self.pairs.mapi((i, pair) => (i, pair))
  indexed.sort_by((a, b) => {
    let order = compare_names(a.1.0, b.1.0)
    if order == 0 {
      a.0.compare(b.0)
    } else {
      order
    }
  })
  self.pairs = indexed.map(item => item.1)
}

///|
/// Iterates an independent snapshot of decoded pairs in the current order.
/// Later changes to the parameter list do not change this iterator's snapshot.
pub fn SearchParams::entries(self : SearchParams) -> Iter[(String, String)] {
  self.pairs.copy().iter()
}

///|
/// Iterates an independent snapshot of names, including duplicates.
pub fn SearchParams::keys(self : SearchParams) -> Iter[String] {
  self.entries().map(pair => pair.0)
}

///|
/// Iterates an independent snapshot of values, including empty strings.
pub fn SearchParams::values(self : SearchParams) -> Iter[String] {
  self.entries().map(pair => pair.1)
}

///|
/// Serializes as application/x-www-form-urlencoded without a leading question mark.
/// Spaces become plus; all bytes except ASCII alphanumerics and *-._ are escaped.
/// Each pair contains an equals sign, and duplicate names retain their order.
pub fn SearchParams::to_string(self : SearchParams) -> String {
  self.pairs
  .map(pair => encode_text(pair.0, Form) + "=" + encode_text(pair.1, Form))
  .join("&")
}

///|
/// Returns a detached, independently mutable decoded copy of this URL's query.
/// Changing these parameters does not change the URL until set_search_params().
pub fn Url::search_params(self : Url) -> SearchParams {
  SearchParams::parse(self.query().unwrap_or(""))
}

///|
/// Replaces the URL query with the list's form-urlencoded serialization.
/// An empty list removes the query. The list remains independent of the URL.
pub fn Url::set_search_params(self : Url, params : SearchParams) -> Unit {
  self.set_search(params.to_string())
}
