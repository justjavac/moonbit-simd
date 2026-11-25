///|
/// Describes the four RFC 4648 variants measured through public APIs.
enum Variant {
  Standard
  StandardNoPad
  UrlSafe
  UrlSafeNoPad
}

///|
/// Names a variant consistently in benchmark case labels.
fn Variant::label(self : Variant) -> String {
  match self {
    Standard => "standard"
    StandardNoPad => "standard-no-pad"
    UrlSafe => "url-safe"
    UrlSafeNoPad => "url-safe-no-pad"
  }
}

///|
/// Selects the standard or URL-safe alphabet.
fn Variant::url_safe(self : Variant) -> Bool {
  self is (UrlSafe | UrlSafeNoPad)
}

///|
/// Selects required padding or explicitly unpadded output.
fn Variant::padding(self : Variant) -> Bool {
  self is (Standard | UrlSafe)
}

///|
/// Returns a shared immutable configuration for the local implementation.
fn Variant::config(self : Variant) -> @ours.Base64 {
  match self {
    Standard => @ours.standard
    StandardNoPad => @ours.standard_no_pad
    UrlSafe => @ours.url_safe
    UrlSafeNoPad => @ours.url_safe_no_pad
  }
}

///|
/// Identifies portable implementations whose public APIs produce strings and bytes.
enum Library {
  OwnScalar
  OwnSimd
  Core
  Gmlewis
  Kujirahand
  Moonbase
}

///|
/// Returns a stable implementation label for JSON collection.
fn Library::label(self : Library) -> String {
  match self {
    OwnScalar => "own-scalar"
    OwnSimd => "own-simd"
    Core => "core"
    Gmlewis => "gmlewis"
    Kujirahand => "kujirahand"
    Moonbase => "moonbase"
  }
}

///|
/// Restricts variants to each package's equivalent public binary API.
fn Library::supports(self : Library, variant : Variant) -> Bool {
  match self {
    Kujirahand => variant is Standard
    _ => true
  }
}

///|
/// Caps the quadratic concatenation encoder while retaining large linear decoding.
fn Library::encodes(self : Library, length : Int32) -> Bool {
  !(self is Kujirahand) || length <= 4096
}

///|
/// Measures public byte-to-string encoding, including required input materialization.
fn Library::encode(
  self : Library,
  input : BytesView,
  variant : Variant,
) -> String {
  let url_safe = variant.url_safe()
  let padding = variant.padding()
  match self {
    OwnScalar => variant.config().encode_to_string(input, simd=false)
    OwnSimd => variant.config().encode_to_string(input, simd=true)
    Core => @core.encode(input, url_safe~, padding~)
    Gmlewis => {
      let owned = input.to_fixedarray()
      if url_safe {
        @gmlewis.url_encode2str(owned, no_padding=!padding)
      } else {
        @gmlewis.std_encode2str(owned, no_padding=!padding)
      }
    }
    Kujirahand => @kujirahand.encode_bytes(input.to_owned())
    Moonbase =>
      @moonbase.encode(input, kind=if url_safe { Url } else { Std }, padding~)
  }
}

///|
/// Measures public ASCII-to-byte decoding with input conversion inside the timer.
fn Library::decode(
  self : Library,
  input : StringView,
  variant : Variant,
) -> Bytes {
  let url_safe = variant.url_safe()
  let padding = variant.padding()
  match self {
    OwnScalar => try! variant.config().decode_string(input, simd=false)
    OwnSimd => try! variant.config().decode_string(input, simd=true)
    Core => try! @core.decode(input, url_safe~)
    Gmlewis =>
      if url_safe {
        try! @gmlewis.url_decode2bytes(input.to_owned(), no_padding=!padding)
      } else {
        try! @gmlewis.std_decode2bytes(input.to_owned(), no_padding=!padding)
      }
    Kujirahand => @kujirahand.decode_bytes(input.to_owned())
    Moonbase =>
      try! @moonbase.decode(
        input,
        kind=if url_safe { Url } else { Std },
        padding~,
        strict=true,
      )
  }
}

///|
/// Keeps one comparison ordering for every supported workload.
let libraries : Array[Library] = [
  OwnScalar,
  OwnSimd,
  Core,
  Gmlewis,
  Kujirahand,
  Moonbase,
]

///|
/// Keeps one variant ordering for the corpus and benchmark inventory.
let variants : Array[Variant] = [Standard, StandardNoPad, UrlSafe, UrlSafeNoPad]

///|
/// Chooses short, vector-sized, medium, and large binary payloads per variant.
fn Variant::sizes(self : Variant) -> Array[Int32] {
  if self is Standard {
    [0, 1, 2, 3, 16, 64, 4096, 1048576]
  } else {
    [2, 4096]
  }
}

///|
/// Builds deterministic binary data independently of every Base64 implementation.
fn payload(length : Int32) -> Bytes {
  let mut state : UInt32 = 0x91e10da5
  Bytes::makei(length, _ => {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    state.to_byte()
  })
}

///|
/// Produces independent RFC 4648 expectations with a per-bit oracle.
fn expected_encoding(input : BytesView, variant : Variant) -> String {
  let alphabet = if variant.url_safe() {
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  } else {
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  }
  let builder = StringBuilder()
  let mut sextet = 0
  let mut bits = 0
  for byte in input {
    for shift = 7; shift >= 0; shift = shift - 1 {
      sextet = sextet * 2 + ((byte.to_int() >> shift) & 1)
      bits += 1
      if bits == 6 {
        builder.write_char(alphabet[sextet].to_char().unwrap())
        sextet = 0
        bits = 0
      }
    }
  }
  if bits != 0 {
    builder.write_char(alphabet[sextet << (6 - bits)].to_char().unwrap())
  }
  if variant.padding() && input.length() % 3 != 0 {
    builder.write_string(if input.length() % 3 == 1 { "==" } else { "=" })
  }
  builder.to_string()
}

///|
/// Converts the oracle's ASCII into bytes for byte-input and buffer workloads.
fn ascii(input : StringView) -> Bytes {
  Bytes::from_array(input.code_units().map(code => code.to_byte()))
}

///|
test "Base64 public adapters agree with independent expectations for every measured variant" {
  for variant in variants {
    let sizes = variant.sizes()
    for length in 0..<68 {
      if !sizes.contains(length) {
        sizes.push(length)
      }
    }
    for length in sizes {
      let input = payload(length)
      let expected = expected_encoding(input, variant)
      for implementation in libraries {
        if implementation.supports(variant) {
          if implementation.encodes(length) {
            assert_eq(implementation.encode(input, variant), expected)
            let backing = b"!" + input + b"!"
            assert_eq(
              implementation.encode(backing[1:1 + length], variant),
              expected,
            )
          }
          assert_eq(implementation.decode(expected, variant), input)
          let backing = "!" + expected + "!"
          assert_eq(
            implementation.decode(backing[1:1 + expected.length()], variant),
            input,
          )
        }
      }
    }
  }
}

///|
test "Base64 byte-input adapters agree with the independent corpus" {
  for variant in variants {
    for length in [0, 1, 2, 3, 16, 64, 4096] {
      let input = payload(length)
      let encoded = ascii(expected_encoding(input, variant))
      assert_eq(variant.config().decode(encoded, simd=false), input)
      assert_eq(variant.config().decode(encoded, simd=true), input)
      assert_eq(
        @moonbase.decode_bytes(
          encoded,
          kind=if variant.url_safe() { Url } else { Std },
          padding=variant.padding(),
          strict=true,
        ),
        input,
      )
    }
  }
}
