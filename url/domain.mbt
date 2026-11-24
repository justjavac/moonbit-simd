///|
/// Converts a domain to ASCII using the WHATWG nontransitional UTS #46 rules.
/// Percent escapes are decoded before UTF-8/IDNA processing. Hyphen and DNS
/// length restrictions are disabled; Bidi and joiner checks are enabled.
/// Empty input returns an empty string; disallowed/malformed domains raise ParseError.
/// The URL parser separately rejects an empty special host. This operation
/// does not interpret numeric domains as IPv4 or accept bracketed IPv6 hosts.
pub fn domain_to_ascii(input : StringView) -> String raise ParseError {
  if input.is_empty() {
    return ""
  }
  ascii_domain(decode_bytes(@utf8.encode(input), false))
}

///|
/// Converts a valid ASCII/Punycode or Unicode domain to its Unicode form.
/// Uses the same UTS #46 flags as domain_to_ascii and raises ParseError on
/// invalid labels. The result is for display; a parsed URL keeps its ASCII host.
pub fn domain_to_unicode(input : StringView) -> String raise ParseError {
  if input.is_empty() {
    return ""
  }
  let ascii = domain_to_ascii(input)
  @idna.to_unicode(
    ascii,
    use_std3_ascii_rules=false,
    check_hyphens=false,
    check_bidi=true,
    check_joiners=true,
  ) catch {
    _ => invalid("IDNA domain-to-Unicode failure")
  }
}

///|
/// Checks an ASCII domain against DNS label and total-length limits.
/// Requires nonempty labels of at most 63 bytes and at most 253 bytes overall,
/// excluding one optional trailing root dot. This is an explicit extra check:
/// ordinary WHATWG URL parsing intentionally does not impose DNS length limits.
/// Non-ASCII domains and empty labels return false; convert with domain_to_ascii first.
pub fn verify_dns_length(domain : StringView) -> Bool {
  let body = domain.strip_suffix(".").unwrap_or(domain)
  if body.is_empty() ||
    body.length() > 253 ||
    body.code_units().iter().any(c => c > 127) {
    return false
  }
  body.split(".").all(label => !label.is_empty() && label.length() <= 63)
}
