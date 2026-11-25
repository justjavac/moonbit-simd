///|
/// Describes the union of one, two, or three byte values without allocating a set.
priv enum Needles {
  One(Byte)
  Two(Byte, Byte)
  Three(Byte, Byte, Byte)
}

///|
/// Pads unused values and exposes arity for scalar and vector mask construction.
fn Needles::values(self : Needles) -> (Byte, Byte, Byte, Int32) {
  match self {
    One(a) => (a, a, a, 1)
    Two(a, b) => (a, b, b, 2)
    Three(a, b, c) => (a, b, c, 3)
  }
}

///|
/// Checks membership once per tail byte, including duplicate needle values.
#cfg(not(target="js"))
#inline
fn Needles::contains(self : Needles, byte : Byte) -> Bool {
  match self {
    One(a) => byte == a
    Two(a, b) => byte == a || byte == b
    Three(a, b, c) => byte == a || byte == b || byte == c
  }
}

///|
/// Selects the requested direction and a bounded vector or SWAR implementation.
fn search_bytes(
  needles : Needles,
  data : BytesView,
  reverse~ : Bool,
  simd~ : Bool,
) -> Int32? {
  if simd && data.length() >= 16 {
    if reverse {
      vector_rfind(needles, data)
    } else {
      vector_find(needles, data)
    }
  } else if reverse {
    scalar_rfind(needles, data)
  } else {
    scalar_find(needles, data)
  }
}

///|
/// Counts matches using one bit per byte and the requested backend implementation.
fn count_bytes(needles : Needles, data : BytesView, simd~ : Bool) -> Int32 {
  if simd && data.length() >= 16 {
    vector_count(needles, data)
  } else {
    scalar_count(needles, data)
  }
}
