import bitops, strutils, zippy/zippyerror

type
  CompressionConfig* = object
    good*, lazy*, nice*, chain*: int

const
  # DEFLATE RFC constants
  maxCodeLength* = 15               ## Maximum bits in a code
  maxLitLenCodes* = 286
  maxDistCodes* = 30
  maxFixedLitLenCodes* = 288
  maxWindowSize* = 32768
  maxUncompressedBlockSize* = 65535
  firstLengthCodeIndex* = 257
  baseMatchLen* = 3
  minMatchLen* = 4
  maxMatchLen* = 258

  # For run length encodings (lz77, snappy), the uint16 high bit is reserved
  # to signal that a offset and length are encoded in the uint16.
  maxLiteralLength* = uint16.high.int shr 1

  configurationTable* = [
    ## See https://github.com/madler/zlib/blob/master/deflate.c#L134
    CompressionConfig(), # No compression
    CompressionConfig(good: 4, lazy: 4, nice: 8, chain: 4),
    CompressionConfig(good: 4, lazy: 5, nice: 16, chain: 8),
    CompressionConfig(good: 4, lazy: 6, nice: 32, chain: 32),
    CompressionConfig(good: 4, lazy: 4, nice: 16, chain: 16),
    CompressionConfig(good: 8, lazy: 16, nice: 32, chain: 32),
    CompressionConfig(good: 8, lazy: 16, nice: 128, chain: 128), # Default
    CompressionConfig(good: 8, lazy: 32, nice: 256, chain: 256),
    CompressionConfig(good: 32, lazy: 128, nice: 258, chain: 1024),
    CompressionConfig(good: 32, lazy: 258, nice: 258, chain: 4096) # Max compression
  ]

  baseLengths* = [
    3.uint16, 4, 5, 6, 7, 8, 9, 10, # 257 - 264
    11, 13, 15, 17, # 265 - 268
    19, 23, 27, 31, # 269 - 273
    35, 43, 51, 59, # 274 - 276
    67, 83, 99, 115, # 278 - 280
    131, 163, 195, 227, # 281 - 284
    258 # 285
  ]

  baseLengthsExtraBits* = [
    0.uint16, 0, 0, 0, 0, 0, 0, 0, # 257 - 264
    1, 1, 1, 1, # 265 - 268
    2, 2, 2, 2, # 269 - 273
    3, 3, 3, 3, # 274 - 276
    4, 4, 4, 4, # 278 - 280
    5, 5, 5, 5, # 281 - 284
    0 # 285
  ]

  baseLengthIndices* = [
    0.uint16, 1, 2, 3, 4, 5, 6, 7, 8, 8,
    9, 9, 10, 10, 11, 11, 12, 12, 12, 12,
    13, 13, 13, 13, 14, 14, 14, 14, 15, 15,
    15, 15, 16, 16, 16, 16, 16, 16, 16, 16,
    17, 17, 17, 17, 17, 17, 17, 17, 18, 18,
    18, 18, 18, 18, 18, 18, 19, 19, 19, 19,
    19, 19, 19, 19, 20, 20, 20, 20, 20, 20,
    20, 20, 20, 20, 20, 20, 20, 20, 20, 20,
    21, 21, 21, 21, 21, 21, 21, 21, 21, 21,
    21, 21, 21, 21, 21, 21, 22, 22, 22, 22,
    22, 22, 22, 22, 22, 22, 22, 22, 22, 22,
    22, 22, 23, 23, 23, 23, 23, 23, 23, 23,
    23, 23, 23, 23, 23, 23, 23, 23, 24, 24,
    24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
    24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
    24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
    25, 25, 25, 25, 25, 25, 25, 25, 25, 25,
    25, 25, 25, 25, 25, 25, 25, 25, 25, 25,
    25, 25, 25, 25, 25, 25, 25, 25, 25, 25,
    25, 25, 26, 26, 26, 26, 26, 26, 26, 26,
    26, 26, 26, 26, 26, 26, 26, 26, 26, 26,
    26, 26, 26, 26, 26, 26, 26, 26, 26, 26,
    26, 26, 26, 26, 27, 27, 27, 27, 27, 27,
    27, 27, 27, 27, 27, 27, 27, 27, 27, 27,
    27, 27, 27, 27, 27, 27, 27, 27, 27, 27,
    27, 27, 27, 27, 27, 28
  ]

  baseDistances* = [
    1.uint16, 2, 3, 4, # 0-3
    5, 7, # 4-5
    9, 13, # 6-7
    17, 25, # 8-9
    33, 49, # 10-11
    65, 97, # 12-13
    129, 193, # 14-15
    257, 385, # 16-17
    513, 769, # 18-19
    1025, 1537, # 20-21
    2049, 3073, # 22-23
    4097, 6145, # 24-25
    8193, 12289, # 26-27
    16385, 24577 # 28-29
  ]

  baseDistanceExtraBits* = [
    0.uint16, 0, 0, 0, # 0-3
    1, 1, # 4-5
    2, 2, # 6-7
    3, 3, # 8-9
    4, 4, # 10-11
    5, 5, # 12-13
    6, 6, # 14-15
    7, 7, # 16-17
    8, 8, # 18-19
    9, 9, # 20-21
    10, 10, # 22-23
    11, 11, # 24-25
    12, 12, # 26-27
    13, 13 # 28-29
  ]

  clclOrder* = [
    16.uint16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
  ]

  bitReverseTable* = block:
    var result: array[256, uint16]
    for i in 0 ..< result.len:
      result[i] = reverseBits(i.uint8)
    result

when defined(release):
  {.push checks: off.}

func reverseUint16*(code: uint16, length: uint8): uint16 {.inline.} =
  (
    (bitReverseTable[(code and 255)] shl 8) or bitReverseTable[(code shr 8)]
  ) shr (16 - length.int)

func makeCodes(lengths: seq[uint8]): seq[uint16] =
  result = newSeq[uint16](lengths.len)

  var lengthCounts: array[16, uint8]
  for l in lengths:
    inc lengthCounts[l]

  lengthCounts[0] = 0

  var nextCode: array[16, uint16]
  for i in 1 .. maxCodeLength:
    nextCode[i] = (nextCode[i - 1] + lengthCounts[i - 1]) shl 1

  for i in 0 ..< result.len:
    if lengths[i] != 0:
      result[i] = reverseUint16(nextCode[lengths[i]], lengths[i])
      inc nextCode[lengths[i]]

const
  fixedCodeLengths* = block:
    var lengths = newSeq[uint8](maxFixedLitLenCodes)
    for i in 0 ..< lengths.len:
      if i <= 143:
        lengths[i] = 8
      elif i <= 255:
        lengths[i] = 9
      elif i <= 279:
        lengths[i] = 7
      else:
        lengths[i] = 8
    lengths

  fixedCodes* = block:
    makeCodes(fixedCodeLengths)

  fixedDistLengths* = block:
    var lengths = newSeq[uint8](maxDistCodes)
    for i in 0 ..< lengths.len:
      lengths[i] = 5
    lengths

  fixedDistCodes* = block:
    makeCodes(fixedDistLengths)

template failUncompress*() =
  raise newException(
    ZippyError, "Invalid buffer, unable to uncompress"
  )

template failCompress*() =
  raise newException(
    ZippyError, "Unexpected error while compressing"
  )

func read16*(s: string, pos: int): uint16 {.inline.} =
  when nimvm:
    (s[pos + 0].uint16 shl 0) or
    (s[pos + 1].uint16 shl 8)
  else:
    cast[ptr uint16](s[pos].unsafeAddr)[]

func read32*(s: seq[uint8] | string, pos: int): uint32 {.inline.} =
  when nimvm:
    (s[pos + 0].uint32 shl 0) or
    (s[pos + 1].uint32 shl 8) or
    (s[pos + 2].uint32 shl 16) or
    (s[pos + 3].uint32 shl 24)
  else:
    cast[ptr uint32](s[pos].unsafeAddr)[]

func read64*(s: seq[uint8] | string, pos: int): uint64 {.inline.} =
  when nimvm:
    (s[pos + 0].uint64 shl 0) or
    (s[pos + 1].uint64 shl 8) or
    (s[pos + 2].uint64 shl 16) or
    (s[pos + 3].uint64 shl 24) or
    (s[pos + 4].uint64 shl 32) or
    (s[pos + 5].uint64 shl 40) or
    (s[pos + 6].uint64 shl 48) or
    (s[pos + 7].uint64 shl 56)
  else:
    cast[ptr uint64](s[pos].unsafeAddr)[]

func write64*(dst: var string, pos: int, value: uint64) {.inline.} =
  when nimvm:
    dst[pos + 0] = (value shr 0 and 255).char
    dst[pos + 1] = (value shr 8 and 255).char
    dst[pos + 2] = (value shr 16 and 255).char
    dst[pos + 3] = (value shr 24 and 255).char
    dst[pos + 4] = (value shr 32 and 255).char
    dst[pos + 5] = (value shr 40 and 255).char
    dst[pos + 6] = (value shr 48 and 255).char
    dst[pos + 7] = (value shr 56 and 255).char
  else:
    cast[ptr uint64](dst[pos].addr)[] = value

func copy64*(dst: var string, src: string, op, ip: int) {.inline.} =
  when nimvm:
    for i in 0 .. 7:
      dst[op + i] = src[ip + i]
  else:
    write64(dst, op, read64(src, ip))

func distanceCodeIndex*(value: uint16): uint16 =
  const distanceCodes = [
    0.uint16, 1, 2, 3, 4, 4, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7,
    8, 8, 8, 8, 8, 8, 8, 8, 9, 9, 9, 9, 9, 9, 9, 9,
    10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10,
    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
    13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
    14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
    14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
    14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
    14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
    15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15
  ]

  if value < distanceCodes.len:
    distanceCodes[value]
  elif (value shr 7) < distanceCodes.len:
    distanceCodes[value shr 7] + 14
  else:
    distanceCodes[value shr 14] + 28

func findMatchLength*(src: string, s1, s2, limit: int): int {.inline.} =
  var
    s1 = s1
    s2 = s2
  while s2 <= limit - 8:
    let x = read64(src, s2) xor read64(src, s1 + result)
    if x != 0:
      let matchingBits = countTrailingZeroBits(x)
      result += matchingBits shr 3
      return
    s2 += 8
    result += 8
  while s2 < limit:
    if src[s2] != src[s1 + result]:
      return
    inc s2
    inc result

func adler32*(data: string): uint32 =
  ## See https://github.com/madler/zlib/blob/master/adler32.c

  const nmax = 5552

  var
    s1 = 1.uint32
    s2 = 0.uint32
    l = data.len
    pos: int

  template do1(i: int) =
    s1 += cast[uint8](data[pos + i])
    s2 += s1

  template do8(i: int) =
    do1(i + 0)
    do1(i + 1)
    do1(i + 2)
    do1(i + 3)
    do1(i + 4)
    do1(i + 5)
    do1(i + 6)
    do1(i + 7)

  template do16() =
    do8(0)
    do8(8)

  while l >= nmax:
    l -= nmax
    for i in 0 ..< nmax div 16:
      do16()
      pos += 16

    s1 = s1 mod 65521
    s2 = s2 mod 65521

  while l >= 16:
    l -= 16
    do16()
    pos += 16

  for i in 0 ..< l:
    s1 += cast[uint8](data[pos + i])
    s2 += s1

  s1 = s1 mod 65521
  s2 = s2 mod 65521

  result = (s2 shl 16) or s1

func toUnixPath*(path: string): string =
  path.replace('\\', '/')

when defined(release):
  {.pop.}
