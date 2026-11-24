///|
/// Identifies the six public-API implementation choices measured by the harness.
priv enum Library {
  OwnScalar
  OwnSimd
  Gaato
  Gmlewis
  Kujirahand
  Mooncrypt
}

///|
/// Lists comparison implementations in a stable reporting order.
let libraries : FixedArray[Library] = [
  OwnScalar,
  OwnSimd,
  Gaato,
  Gmlewis,
  Kujirahand,
  Mooncrypt,
]

///|
/// Supplies stable case labels independently of display names and versions.
fn Library::label(self : Library) -> String {
  match self {
    OwnScalar => "own-scalar"
    OwnSimd => "own-simd"
    Gaato => "gaato"
    Gmlewis => "gmlewis"
    Kujirahand => "kujirahand"
    Mooncrypt => "mooncrypt"
  }
}

///|
/// Adapts gmlewis's byte-at-a-time public digest API to one input view.
fn gmlewis_checksum(data : BytesView) -> UInt32 {
  let state = @gmlewis.Digest::new()
  for byte in data {
    state.write(byte)
  }
  state.digest()
}

///|
/// Hashes a prepared owned byte buffer without charging input materialization.
fn Library::checksum_owned(self : Library, data : Bytes) -> UInt32 {
  match self {
    OwnScalar => @ours.hash(data)
    OwnSimd => @ours.hash(data, simd=true)
    Gaato => @gaato.crc32_update(0, data)
    Gmlewis => gmlewis_checksum(data)
    Kujirahand => @kujirahand.checksum(data)
    Mooncrypt => @mooncrypt.crc32(data, kind=@mooncrypt.Ieee)
  }
}

///|
/// Hashes a view and includes the owned-input conversion required by kujirahand.
fn Library::checksum_view(self : Library, data : BytesView) -> UInt32 {
  match self {
    OwnScalar => @ours.hash(data)
    OwnSimd => @ours.hash(data, simd=true)
    Gaato => @gaato.crc32_update(0, data)
    Gmlewis => gmlewis_checksum(data)
    Kujirahand => @kujirahand.checksum(data.to_owned())
    Mooncrypt => @mooncrypt.crc32(data, kind=@mooncrypt.Ieee)
  }
}

///|
/// Measures each library's complete public incremental state lifecycle.
fn Library::checksum_chunks(self : Library, chunks : Array[Bytes]) -> UInt32 {
  match self {
    OwnScalar | OwnSimd => {
      let state = @ours.Hasher::new(simd=self is OwnSimd)
      for chunk in chunks {
        state.update(chunk)
      }
      state.finalize()
    }
    Gaato => {
      let state = @gaato.crc32.digest()
      for chunk in chunks {
        state.write(chunk)
      }
      state.value().to_uint()
    }
    Gmlewis => {
      let state = @gmlewis.Digest::new()
      for chunk in chunks {
        for byte in chunk {
          state.write(byte)
        }
      }
      state.digest()
    }
    Kujirahand => {
      let state = @kujirahand.CRC32Stream::new()
      for chunk in chunks {
        ignore(state.update(chunk))
      }
      state.finalize()
    }
    Mooncrypt => {
      let state = @mooncrypt.Crc32::new(kind=@mooncrypt.Ieee)
      for chunk in chunks {
        state.update(chunk)
      }
      state.value()
    }
  }
}

///|
/// Generates identical deterministic binary payloads for every implementation.
fn payload(length : Int32) -> Bytes {
  Bytes::makei(length, index => ((index * 73 + index / 7 + 19) & 255).to_byte())
}

///|
/// Materializes streaming chunks before timing their consumption.
fn prepared_chunks(data : Bytes, chunk_size : Int32) -> Array[Bytes] {
  let chunks = []
  for offset = 0; offset < data.length(); offset = offset + chunk_size {
    chunks.push(
      data[offset:(offset + chunk_size).min(data.length())].to_owned(),
    )
  }
  chunks
}

///|
/// Reverses a word for an independent forward-polynomial CRC oracle.
fn reverse_word(value : UInt32) -> UInt32 {
  for bit in 0..<32; reversed = 0U {
    continue (reversed << 1) | ((value >> bit) & 1)
  } nobreak {
    reversed
  }
}

///|
/// Computes IEEE CRC-32 using forward polynomial bits without library tables.
fn reference_crc(data : BytesView) -> UInt32 {
  let mut state = 0xFFFFFFFFU
  for byte in data {
    for bit in 0..<8 {
      let feedback = ((state >> 31) ^ (byte.to_uint() >> bit)) & 1
      state = state << 1
      if feedback != 0 {
        state = state ^ 0x04C11DB7
      }
    }
  }
  reverse_word(state) ^ 0xFFFFFFFF
}

///|
test "all public APIs implement the same IEEE CRC-32 reference vectors" {
  for
    (data, expected) in [
      (b"", 0U),
      (b"123456789", 0xCBF43926U),
      (b"hello world", 0x0D4A1185U),
      (Bytes::makei(32, _ => 0), 0x190A55ADU),
      (Bytes::makei(32, index => index.to_byte()), 0x91267E8AU),
    ] {
    for implementation in libraries {
      assert_eq(implementation.checksum_owned(data), expected)
      assert_eq(implementation.checksum_view(data), expected)
    }
  }
}

///|
test "comparison adapters agree with the independent oracle at boundaries" {
  let source = payload(65568)
  for
    length in [
      0, 1, 7, 8, 15, 16, 17, 63, 64, 65, 255, 256, 1023, 1024, 4096, 65536,
    ] {
    for offset in [0, 1, 7, 15, 31] {
      let view = source[offset:offset + length]
      let expected = reference_crc(view)
      let owned = view.to_owned()
      for implementation in libraries {
        assert_eq(implementation.checksum_owned(owned), expected)
        assert_eq(implementation.checksum_view(view), expected)
      }
    }
  }
}

///|
test "every incremental adapter preserves chunk boundary semantics" {
  let data = payload(65536)
  let expected = reference_crc(data)
  for chunk_size in [1, 16, 256, 4096, 65536] {
    let chunks = prepared_chunks(data, chunk_size)
    for implementation in libraries {
      assert_eq(implementation.checksum_chunks(chunks), expected)
      assert_eq(implementation.checksum_chunks([]), 0U)
    }
  }
}
