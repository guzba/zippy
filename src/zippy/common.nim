import bitops, zippy/zippyerror

type
  CompressionConfig* = object
    good, lazy, nice, chain: int

const
  # DEFLATE RFC constants
  maxCodeLength* = 15               ## Maximum bits in a code
  maxLitLenCodes* = 286
  maxDistCodes* = 30
  maxFixedLitLenCodes* = 288
  maxWindowSize* = 32768
  maxUncompressedBlockSize* = 65535
  firstLengthCodeIndex* = 257
  minMatchLen* = 3
  maxMatchLen* = 258

  # For run length encodings (lz77, snappy), he uint16 high bit is reserved
  # to signal that a offset and length are encoded in the uint16.
  maxLiteralLength* = uint16.high.int shr 1

  baseLengths* = [
    3.uint16, 4, 5, 6, 7, 8, 9, 10, # 257 - 264
    11, 13, 15, 17,                 # 265 - 268
    19, 23, 27, 31,                 # 269 - 273
    35, 43, 51, 59,                 # 274 - 276
    67, 83, 99, 115,                # 278 - 280
    131, 163, 195, 227,             # 281 - 284
    258                             # 285
  ]

  baseLengthsExtraBits* = [
    0.int8, 0, 0, 0, 0, 0, 0, 0,    # 257 - 264
    1, 1, 1, 1,                     # 265 - 268
    2, 2, 2, 2,                     # 269 - 273
    3, 3, 3, 3,                     # 274 - 276
    4, 4, 4, 4,                     # 278 - 280
    5, 5, 5, 5,                     # 281 - 284
    0                               # 285
  ]

  baseDistance* = [
    1.uint16, 2, 3, 4,              # 0-3
    5, 7,                           # 4-5
    9, 13,                          # 6-7
    17, 25,                         # 8-9
    33, 49,                         # 10-11
    65, 97,                         # 12-13
    129, 193,                       # 14-15
    257, 385,                       # 16-17
    513, 769,                       # 18-19
    1025, 1537,                     # 20-21
    2049, 3073,                     # 22-23
    4097, 6145,                     # 24-25
    8193, 12289,                    # 26-27
    16385, 24577                    # 28-29
  ]

  baseDistanceExtraBits* = [
    0.int8, 0, 0, 0,                # 0-3
    1, 1,                           # 4-5
    2, 2,                           # 6-7
    3, 3,                           # 8-9
    4, 4,                           # 10-11
    5, 5,                           # 12-13
    6, 6,                           # 14-15
    7, 7,                           # 16-17
    8, 8,                           # 18-19
    9, 9,                           # 20-21
    10, 10,                         # 22-23
    11, 11,                         # 24-25
    12, 12,                         # 26-27
    13, 13                          # 28-29
  ]

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

  fixedDistanceLengths* = block:
    var lengths = newSeq[uint8](maxDistCodes)
    for i in 0 ..< lengths.len:
      lengths[i] = 5
    lengths

  clclOrder* = [
    16.int8, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
  ]

  bitReverseTable* = block:
    var result: array[256, uint8]
    for i in 0 ..< result.len:
      result[i] = reverseBits(i.uint8)
    result

  crcTable = block:
    var
      table: array[256, uint32]
      c: uint32
    for i in 0.uint32 ..< table.len.uint32:
      c = i
      for j in 0 ..< 8:
        if (c and 1) > 0:
          c = 0xedb88320.uint32 xor (c shr 1)
        else:
          c = (c shr 1)
      table[i] = c
    table

  configurationTable* = [
    ## See https://github.com/madler/zlib/blob/master/deflate.c#L134
    CompressionConfig(), # No compression
    CompressionConfig(), # Custom algorithm based on Snappy
    CompressionConfig(good: 4, lazy: 0, nice: 16, chain: 8),
    CompressionConfig(good: 4, lazy: 0, nice: 32, chain: 32),
    CompressionConfig(good: 4, lazy: 4, nice: 16, chain: 16),
    CompressionConfig(good: 8, lazy: 16, nice: 32, chain: 32),
    CompressionConfig(good: 8, lazy: 16, nice: 128, chain: 128), # Default
    CompressionConfig(good: 8, lazy: 32, nice: 256, chain: 256),
    CompressionConfig(good: 32, lazy: 128, nice: 258, chain: 1024),
    CompressionConfig(good: 32, lazy: 258, nice: 258, chain: 4096) # Max compression
  ]

template failUncompress*() =
  raise newException(
    ZippyError, "Invalid buffer, unable to uncompress"
  )

template failCompress*() =
  raise newException(
    ZippyError, "Unexpected error while compressing"
  )

when defined(release):
  {.push checks: off.}

template read32*(s: seq[uint8], pos: int): uint32 =
  when nimvm:
    (s[pos + 0].uint32 shl 0) or
    (s[pos + 1].uint32 shl 8) or
    (s[pos + 2].uint32 shl 16) or
    (s[pos + 3].uint32 shl 24)
  else:
    cast[ptr uint32](s[pos].unsafeAddr)[]

template read64*(s: seq[uint8], pos: int): uint64 =
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

template reverseUint16*(code: uint16, length: uint8): uint16 =
  (
    (bitReverseTable[(code and 255).uint8].uint16 shl 8) or
    (bitReverseTable[(code shr 8).uint8].uint16)
  ) shr (16 - length)

func findCodeIndex*(a: openarray[uint16], value: uint16): uint16 =
  let mid = (1 + a.len) div 2
  var l, r: int
  if value < a[mid]:
    l = 1
    r = mid
  else:
    l = mid
    r = a.high

  for i in l .. r:
    if value < a[i]:
      return i.uint16 - 1
  a.high.uint16

func findMatchLength*(src: seq[uint8], s1, s2, limit: int): int {.inline.} =
  var
    s1 = s1
    s2 = s2
  while s2 <= limit - 8:
    let x = read64(src, s2) xor read64(src, s1 + result)
    if x == 0:
      inc(s2, 8)
      inc(result, 8)
    else:
      let matchingBits = countTrailingZeroBits(x)
      inc(result, matchingBits shr 3)
      return
  while s2 < limit:
    if src[s2] == src[s1 + result]:
      inc s2
      inc result
    else:
      return

func adler32*(data: seq[uint8]): uint32 =
  ## See https://github.com/madler/zlib/blob/master/adler32.c

  const nmax = 5552

  var
    s1 = 1.uint32
    s2 = 0.uint32
    l = data.len
    pos: int

  template do1(i: int) =
    s1 += data[pos + i]
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
    dec(l, nmax)
    for i in 0 ..< nmax div 16:
      do16()
      inc(pos, 16)

    s1 = s1 mod 65521
    s2 = s2 mod 65521

  while l >= 16:
    dec(l, 16)
    do16()
    inc(pos, 16)

  for i in 0 ..< l:
    s1 += data[pos + i]
    s2 += s1

  s1 = s1 mod 65521
  s2 = s2 mod 65521

  result = (s2 shl 16) or s1

func crc32*(v: uint32, data: seq[uint8]): uint32 =
  result = v
  for value in data:
    result = crcTable[(result xor value.uint32) and 0xff] xor (result shr 8)

func crc32*(data: seq[uint8]): uint32 =
  crc32(0xffffffff.uint32, data) xor 0xffffffff.uint32

when defined(release):
  {.pop.}
