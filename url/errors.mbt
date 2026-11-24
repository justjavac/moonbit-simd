///|
/// Reports a URL that cannot be parsed according to the WHATWG URL Standard.
///
/// The message identifies the failed component. Recoverable validation issues,
/// such as omitted slashes or a percent sign without two hex digits in a path,
/// are normalized rather than raised. A failed parse does not modify its base.
#derive(Debug, Eq)
pub(all) suberror ParseError {
  InvalidUrl(String)
}

///|
/// Raises a component-specific, recoverable parse error.
fn[T] invalid(message : String) -> T raise ParseError {
  raise InvalidUrl(message)
}
