const
  maxCodeLength* = 15 ## Maximum bits in a code
  maxLitLenCodes* = 286
  maxDistCodes* = 30
  maxFixedLitLenCodes* = 288
  # maxUncompressedBlockSize = 65535
  # maxWindowSize = 32768

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
