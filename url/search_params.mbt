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
/// Creates an independent parameter list with size zero and empty
/// serialization. Use `append` to add already decoded names and values.
pub fn SearchParams::new() -> SearchParams {
  { pairs: [], }
}

///|
/// Parses a query or form body, accepting one optional leading question mark.
/// Empty ampersand-separated fields are skipped. Missing equals signs produce
/// empty values. Plus decodes to space and percent escapes are decoded as
/// UTF-8 with replacement for malformed sequences. Invalid percent escapes
/// remain literal. The returned mutable list owns its decoded pairs.
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
/// Literal plus and percent signs are stored as data, ready for serialization.
pub fn SearchParams::from_pairs(
  pairs : ArrayView[(String, String)],
) -> SearchParams {
  { pairs: pairs.map(pair => (scalar_string(pair.0), scalar_string(pair.1))), }
}

///|
/// Copies the ordered list into an independent mutable object. Each receiver
/// can be appended to, reordered, or reset independently. Immutable names
/// and values may share their string storage.
pub fn SearchParams::copy(self : SearchParams) -> SearchParams {
  { pairs: self.pairs.copy(), }
}

///|
/// Replaces all existing pairs with the result of `parse(input)`.
/// Empty input clears the list. References that alias `self` observe the
/// replacement, while copies and existing iterators retain their snapshots.
pub fn SearchParams::reset(self : SearchParams, input : StringView) -> Unit {
  self.pairs = SearchParams::parse(input).pairs
}

///|
/// Returns the number of name-value pairs as an `Int32`. Every occurrence
/// of a repeated name counts separately, including pairs with an empty value.
pub fn SearchParams::size(self : SearchParams) -> Int32 {
  self.pairs.length()
}

///|
/// Appends one decoded pair at the end, preserving existing pairs.
/// Empty names and values are valid. Unpaired surrogates become U+FFFD and
/// form encoding happens at serialization. Aliases observe the append.
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
/// Matching uses case-sensitive decoded names after surrogate replacement.
/// Aliases observe the replacement and removal.
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
/// Omitting `value` removes every occurrence of `name`. Supplying `value=""`
/// restricts deletion to pairs with an empty value. Retained pairs keep their
/// order and aliases observe changes.
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
/// Returns the first case-sensitive match for the decoded name.
/// `None` means the name is absent, and `Some("")` represents an empty
/// value. The returned string can be retained independently of later edits.
///
/// ```mbt check
/// test {
///   let params = @url.SearchParams::parse("?x=&x=more+y")
///   assert_eq(params.get("x"), Some(""))
///   assert_eq(params.get_all("x"), ["", "more y"])
///   assert_eq(params.get("missing"), None)
/// }
/// ```
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
/// Returns an independent array of all values matching `name` in their
/// current order. A name that is absent yields an empty array. Repeated
/// values and empty strings are preserved.
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
/// Omitting `value` matches any value for the name. An explicit empty value
/// matches only pairs whose value is empty.
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
/// Values stay paired with their names. Shared references observe the new
/// order and existing snapshot iterators continue in their original order.
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
/// Iterates decoded names in their current order, including duplicates and
/// empty names. The iterator snapshots the list at construction and stays
/// usable across later edits.
pub fn SearchParams::keys(self : SearchParams) -> Iter[String] {
  self.entries().map(pair => pair.0)
}

///|
/// Iterates decoded values in their current order, including duplicates and
/// empty strings. The iterator owns a snapshot of the pairs at construction.
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
/// Both absent and empty queries produce an empty list. Apply edits back
/// to the URL using `set_search_params`.
pub fn Url::search_params(self : Url) -> SearchParams {
  SearchParams::parse(self.query().unwrap_or(""))
}

///|
/// Replaces the URL query with the list's form-urlencoded serialization.
/// An empty list removes the query. The URL retains only the serialized
/// snapshot, so subsequent mutations of `params` are independent.
pub fn Url::set_search_params(self : Url, params : SearchParams) -> Unit {
  self.set_search(params.to_string())
}
