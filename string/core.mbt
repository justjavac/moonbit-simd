///|
/// Re-exports core parsing, conversion, and regular expression APIs with their
/// original types, keyword arguments, and error behavior.
pub using @core_string {
  from_str,
  parse_bigint,
  parse_bool,
  parse_double,
  parse_int,
  parse_int64,
  parse_uint,
  parse_uint64,
  type MatchResult,
  type Regex,
  trait FromStr,
  trait ToStringView,
}
