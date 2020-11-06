const
  maxCodeLength* = 15 ## Maximum bits in a code
  maxLitLenCodes* = 286
  maxDistCodes* = 30
  maxFixedLitLenCodes* = 288
  maxWindowSize* = 32768
  maxUncompressedBlockSize* = 65535
  firstLengthCodeIndex* = 257

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
