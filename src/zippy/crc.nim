import internal

const crcTables = block:
  var
    tables: array[8, array[256, uint32]]
    c: uint32
  for i in 0.uint32 ..< 256:
    c = i
    for j in 0 ..< 8:
      c = (c shr 1) xor ((c and 1) * 0xedb88320.uint32)
    tables[0][i] = c
  for i in 0 ..< 256:
    tables[1][i] = (tables[0][i] shr 8) xor tables[0][tables[0][i] and 255]
    tables[2][i] = (tables[1][i] shr 8) xor tables[0][tables[1][i] and 255]
    tables[3][i] = (tables[2][i] shr 8) xor tables[0][tables[2][i] and 255]
    tables[4][i] = (tables[3][i] shr 8) xor tables[0][tables[3][i] and 255]
    tables[5][i] = (tables[4][i] shr 8) xor tables[0][tables[4][i] and 255]
    tables[6][i] = (tables[5][i] shr 8) xor tables[0][tables[5][i] and 255]
    tables[7][i] = (tables[6][i] shr 8) xor tables[0][tables[6][i] and 255]
  tables

when defined(release):
  {.push checks: off.}

when allowSimd and defined(amd64):
  when defined(gcc) or defined(clang):
    {.localPassc: "-msse4.1 -mpclmul".}

  {.push header: "emmintrin.h".}

  type M128i* {.importc: "__m128i".} = object

  func mm_load_si128(p: pointer): M128i {.importc: "_mm_load_si128".}
  func mm_loadu_si128(p: pointer): M128i {.importc: "_mm_loadu_si128".}
  func mm_loadl_epi64(p: pointer): M128i {.importc: "_mm_loadl_epi64".}
  func mm_setr_epi32(a, b, c, d: int32 | uint32): M128i {.importc: "_mm_setr_epi32".}
  func mm_srli_si128(a: M128i, imm8: int32 | uint32): M128i {.importc: "_mm_srli_si128".}
  func mm_xor_si128(a, b: M128i): M128i {.importc: "_mm_xor_si128".}
  func mm_and_si128(a, b: M128i): M128i {.importc: "_mm_and_si128".}
  func mm_cvtsi32_si128(a: int32 | uint32): M128i {.importc: "_mm_cvtsi32_si128".}

  {.pop.}

  {.push header: "smmintrin.h".}

  func mm_extract_epi32(a: M128i, imm8: int32 | uint32): int32 {.importc: "_mm_extract_epi32".}

  {.pop.}

  {.push header: "wmmintrin.h".}

  func mm_clmulepi64_si128(a, b: M128i, imm8: int32 | uint32): M128i {.importc: "_mm_clmulepi64_si128".}

  {.pop.}

  # Computes the crc32 of the buffer, where the buffer
  # length must be at least 64, and a multiple of 16. Based on
  #
  # "Fast CRC Computation for Generic Polynomials Using PCLMULQDQ Instruction"
  #  V. Gopal, E. Ozturk, et al., 2009, http://intel.ly/2ySEwL0
  #
  # This function is a Nim conversion of an original implementation
  # from the Chromium repository. That implementation is:
  #
  # Copyright 2017 The Chromium Authors. All rights reserved.
  # Use of this source code is governed by a BSD-style license that can be
  # found in the Chromium source repository LICENSE file.
  proc crc32_sse41_pcmul(src: pointer, len: int, crc32: uint32): uint32 =
    let
      k1k2 = [0x0154442bd4.uint64, 0x01c6e41596.uint64]
      k3k4 = [0x01751997d0.uint64, 0x00ccaa009e.uint64]
      k5k0 = [0x0163cd6124.uint64, 0x0000000000.uint64]
      poly = [0x01db710641.uint64, 0x01f7011641.uint64]

    let src = cast[ptr UncheckedArray[uint8]](src)

    var
      pos = 0
      len = len
      x0, x1, x2, x3, x4, x5, x6, x7, x8, y5, y6, y7, y8: M128i

    x1 = mm_loadu_si128((src[pos + 0x00].addr))
    x2 = mm_loadu_si128((src[pos + 0x10].addr))
    x3 = mm_loadu_si128((src[pos + 0x20].addr))
    x4 = mm_loadu_si128((src[pos + 0x30].addr))

    x1 = mm_xor_si128(x1, mm_cvtsi32_si128(crc32))

    x0 = mm_load_si128(k1k2.unsafeAddr)

    pos += 64
    len -= 64

    while (len >= 64):
      x5 = mm_clmulepi64_si128(x1, x0, 0x00)
      x6 = mm_clmulepi64_si128(x2, x0, 0x00)
      x7 = mm_clmulepi64_si128(x3, x0, 0x00)
      x8 = mm_clmulepi64_si128(x4, x0, 0x00)

      x1 = mm_clmulepi64_si128(x1, x0, 0x11)
      x2 = mm_clmulepi64_si128(x2, x0, 0x11)
      x3 = mm_clmulepi64_si128(x3, x0, 0x11)
      x4 = mm_clmulepi64_si128(x4, x0, 0x11)

      y5 = mm_loadu_si128(src[pos + 0x00].addr)
      y6 = mm_loadu_si128(src[pos + 0x10].addr)
      y7 = mm_loadu_si128(src[pos + 0x20].addr)
      y8 = mm_loadu_si128(src[pos + 0x30].addr)

      x1 = mm_xor_si128(x1, x5)
      x2 = mm_xor_si128(x2, x6)
      x3 = mm_xor_si128(x3, x7)
      x4 = mm_xor_si128(x4, x8)

      x1 = mm_xor_si128(x1, y5)
      x2 = mm_xor_si128(x2, y6)
      x3 = mm_xor_si128(x3, y7)
      x4 = mm_xor_si128(x4, y8)

      pos += 64
      len -= 64

    x0 = mm_load_si128(k3k4.unsafeAddr)

    x5 = mm_clmulepi64_si128(x1, x0, 0x00)
    x1 = mm_clmulepi64_si128(x1, x0, 0x11)
    x1 = mm_xor_si128(x1, x2)
    x1 = mm_xor_si128(x1, x5)

    x5 = mm_clmulepi64_si128(x1, x0, 0x00)
    x1 = mm_clmulepi64_si128(x1, x0, 0x11)
    x1 = mm_xor_si128(x1, x3)
    x1 = mm_xor_si128(x1, x5)

    x5 = mm_clmulepi64_si128(x1, x0, 0x00)
    x1 = mm_clmulepi64_si128(x1, x0, 0x11)
    x1 = mm_xor_si128(x1, x4)
    x1 = mm_xor_si128(x1, x5)

    while (len >= 16):
      x2 = mm_loadu_si128(src[pos].addr)

      x5 = mm_clmulepi64_si128(x1, x0, 0x00)
      x1 = mm_clmulepi64_si128(x1, x0, 0x11)
      x1 = mm_xor_si128(x1, x2)
      x1 = mm_xor_si128(x1, x5)

      pos += 16
      len -= 16

    x2 = mm_clmulepi64_si128(x1, x0, 0x10)
    x3 = mm_setr_epi32(not 0, 0, not 0, 0)
    x1 = mm_srli_si128(x1, 8)
    x1 = mm_xor_si128(x1, x2)

    x0 = mm_loadl_epi64(k5k0.unsafeAddr)

    x2 = mm_srli_si128(x1, 4)
    x1 = mm_and_si128(x1, x3)
    x1 = mm_clmulepi64_si128(x1, x0, 0x00)
    x1 = mm_xor_si128(x1, x2)

    x0 = mm_load_si128(poly.unsafeAddr)

    x2 = mm_and_si128(x1, x3)
    x2 = mm_clmulepi64_si128(x2, x0, 0x10)
    x2 = mm_and_si128(x2, x3)
    x2 = mm_clmulepi64_si128(x2, x0, 0x00)
    x1 = mm_xor_si128(x1, x2)

    cast[uint32](mm_extract_epi32(x1, 1))

## See https://create.stephan-brumme.com/crc32/
proc crc32(src: pointer, len: int, crc32: uint32): uint32 {.inline.} =
  let src = cast[ptr UncheckedArray[uint8]](src)

  result = crc32

  var i: int
  for _ in 0 ..< len div 8:
    let
      one = read32(src, i) xor result
      two = read32(src, i + 4)
    result =
      crcTables[7][one and 255] xor
      crcTables[6][(one shr 8) and 255] xor
      crcTables[5][(one shr 16) and 255] xor
      crcTables[4][one shr 24] xor
      crcTables[3][two and 255] xor
      crcTables[2][(two shr 8) and 255] xor
      crcTables[1][(two shr 16) and 255] xor
      crcTables[0][two shr 24]
    i += 8

  for j in i ..< len:
    result = crcTables[0][(result xor src[j]) and 255] xor (result shr 8)

proc crc32*(src: pointer, len: int): uint32 =
  let src = cast[ptr UncheckedArray[uint8]](src)

  var pos: int

  when allowSimd and defined(amd64):
    # Runtime check if SSE 4.1 and PCLMULQDQ are available

    proc cpuid(eaxi, ecxi: int32): tuple[eax, ebx, ecx, edx: int32] =
      when defined(vcc):
        proc cpuid(cpuInfo: ptr int32, functionID, subFunctionId: int32)
          {.cdecl, importc: "__cpuidex", header: "intrin.h".}
        cpuid(result.eax.addr, eaxi, ecxi)
      else:
        var (eaxr, ebxr, ecxr, edxr) = (0'i32, 0'i32, 0'i32, 0'i32)
        asm """
          cpuid
          :"=a"(`eaxr`), "=b"(`ebxr`), "=c"(`ecxr`), "=d"(`edxr`)
          :"a"(`eaxi`), "c"(`ecxi`)"""
        (eaxr, ebxr, ecxr, edxr)

    let
      leaf1 = cpuid(1, 0)
      sse41 = (leaf1[2] and (1 shl 19)) != 0
      pclmulqdq = (leaf1[2] and (1 shl 1)) != 0

    if sse41 and pclmulqdq and len >= 64:
      let simdLen = (len div 16) * 16 # Multiple of 16
      result = not crc32_sse41_pcmul(src[0].addr, simdLen, not result)
      pos += simdLen

  if pos < len:
    result = crc32(src[pos].addr, len - pos, not result)
    result = not result

proc crc32*(src: string): uint32 {.inline.} =
  crc32(src.cstring, src.len)

when defined(release):
  {.pop.}
