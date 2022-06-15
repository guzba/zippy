import common

when defined(amd64):
  when defined(gcc) or defined(clang):
    {.localPassc: "-mssse3".}

  {.push header: "emmintrin.h".}

  type M128i {.importc: "__m128i".} = object

  template MM_SHUFFLE(z, y, x, w: int | uint): int32 =
    ((z shl 6) or (y shl 4) or (x shl 2) or w).int32

  func mm_loadu_si128(p: pointer): M128i {.importc: "_mm_loadu_si128".}
  func mm_setzero_si128(): M128i {.importc: "_mm_setzero_si128".}
  func mm_set_epi32(a, b, c, d: int32 | uint32): M128i {.importc: "_mm_set_epi32".}
  func mm_setr_epi8(a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p: int8 | uint8): M128i {.importc: "_mm_setr_epi8".}
  func mm_set1_epi16(a: int16 | uint16): M128i {.importc: "_mm_set1_epi16".}
  func mm_add_epi32(a, b: M128i): M128i {.importc: "_mm_add_epi32".}
  func mm_sad_epu8(a, b: M128i): M128i {.importc: "_mm_sad_epu8".}
  func mm_madd_epi16(a, b: M128i): M128i {.importc: "_mm_madd_epi16".}
  func mm_slli_epi32(a: M128i, imm8: int32 | uint32): M128i {.importc: "_mm_slli_epi32".}
  func mm_shuffle_epi32(a: M128i, imm8: int32 | uint32): M128i {.importc: "_mm_shuffle_epi32".}
  func mm_cvtsi128_si32(a: M128i): int32 {.importc: "_mm_cvtsi128_si32".}

  {.pop.}

  {.push header: "tmmintrin.h".}

  func mm_maddubs_epi16(a, b: M128i): M128i {.importc: "_mm_maddubs_epi16".}

  {.pop.}

  const nmax = 5552

  # This function is a Nim conversion of an original implementation
  # from the Chromium repository. That implementation is:
  #
  # Copyright 2017 The Chromium Authors. All rights reserved.
  # Use of this source code is governed by a BSD-style license that can be
  # found in the Chromium source repository LICENSE file.

  proc adler32_ssse3*(src: pointer, len: int): uint32 =
    if len == 0:
      return 1

    if len < 0:
      raise newException(ZippyError, "Adler-32 len < 0")
    if len > uint32.high.int:
      raise newException(ZippyError, "Adler-32 len > uint32.high")

    let src = cast[ptr UncheckedArray[uint8]](src)

    var
      pos: uint32
      remaining = cast[uint32](len)
      s1 = 1.uint32
      s2 = 0.uint32

    const blockSize = 32.uint32

    var blocks = remaining div blockSize

    remaining -= (blocks * blockSize)

    let
      tap1 = mm_setr_epi8(32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17)
      tap2 = mm_setr_epi8(16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1)
      zero = mm_setzero_si128()
      ones = mm_set1_epi16(1)

    while blocks > 0:
      var n = nmax div blockSize
      if n > blocks:
        n = blocks

      blocks -= n

      var
        vecPs = mm_set_epi32(0, 0, 0, s1 * n)
        vecS2 = mm_set_epi32(0, 0, 0, s2)
        vecS1 = mm_set_epi32(0, 0, 0, 0)

      while n > 0:
        let
          bytes1 = mm_loadu_si128(src[pos + 0].addr)
          bytes2 = mm_loadu_si128(src[pos + 16].addr)

        vecPs = mm_add_epi32(vecPs, vecS1)

        vecS1 = mm_add_epi32(vecS1, mm_sad_epu8(bytes1, zero))
        let mad1 = mm_maddubs_epi16(bytes1, tap1)
        vecS2 = mm_add_epi32(vecS2, mm_madd_epi16(mad1, ones))
        vecS1 = mm_add_epi32(vecS1, mm_sad_epu8(bytes2, zero))
        let mad2 = mm_maddubs_epi16(bytes2, tap2)
        vecS2 = mm_add_epi32(vecS2, mm_madd_epi16(mad2, ones))

        dec n
        pos += 32

      vecS2 = mm_add_epi32(vecS2, mm_slli_epi32(vecPs, 5))

      vecS1 = mm_add_epi32(vecS1, mm_shuffle_epi32(vecS1, MM_SHUFFLE(2, 3, 0, 1)))
      vecS1 = mm_add_epi32(vecS1, mm_shuffle_epi32(vecS1, MM_SHUFFLE(1, 0, 3, 2)))
      s1 += cast[uint32](mm_cvtsi128_si32(vecS1))
      vecS2 = mm_add_epi32(vecS2, mm_shuffle_epi32(vecS2, MM_SHUFFLE(2, 3, 0, 1)))
      vecS2 = mm_add_epi32(vecS2, mm_shuffle_epi32(vecS2, MM_SHUFFLE(1, 0, 3, 2)))
      s2 = cast[uint32](mm_cvtsi128_si32(vecS2))

      s1 = s1 mod 65521
      s2 = s2 mod 65521

    for i in 0 ..< remaining:
      s1 += src[pos + i]
      s2 += s1

    s1 = s1 mod 65521
    s2 = s2 mod 65521

    result = (s2 shl 16) or s1
