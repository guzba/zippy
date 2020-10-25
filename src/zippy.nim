import zippy/buffer, zippy/zippyerror

export zippyerror

const
  maxCodeLength = 15                ## Maximum bits in a code
  maxLitLenCodes = 286
  maxDistCodes = 30
  maxFixedLitLenCodes = 288

  codeLengthOrder = [
    16.int8, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
  ]

  baseLengths = [
    3.uint16, 4, 5, 6, 7, 8, 9, 10, # 257 - 264
    11, 13, 15, 17,                 # 265 - 268
    19, 23, 27, 31,                 # 269 - 273
    35, 43, 51, 59,                 # 274 - 276
    67, 83, 99, 115,                # 278 - 280
    131, 163, 195, 227,             # 281 - 284
    258                             # 285
  ]

  baseLengthsExtraBits = [
    0.int8, 0, 0, 0, 0, 0, 0, 0,    # 257 - 264
    1, 1, 1, 1,                     # 265 - 268
    2, 2, 2, 2,                     # 269 - 273
    3, 3, 3, 3,                     # 274 - 276
    4, 4, 4, 4,                     # 278 - 280
    5, 5, 5, 5,                     # 281 - 284
    0                               # 285
  ]

  baseDistance = [
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

  baseDistanceExtraBits = [
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

  fixedCodeLengths = block:
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

  fixedDistanceLengths = block:
    var lengths = newSeq[uint8](maxDistCodes)
    for i in 0 ..< lengths.len:
      lengths[i] = 5
    lengths

template failUncompress() =
  raise newException(
    ZippyError, "Invalid buffer, unable to uncompress"
  )

type Huffman = object
  counts: seq[uint16]
  symbols: seq[uint16]

{.push checks: off.}

func initHuffman(lengths: seq[uint8], maxCodes: int): Huffman =
  ## See https://github.com/madler/zlib/blob/master/contrib/puff/puff.c

  result = Huffman()
  result.counts.setLen(maxCodeLength + 1)
  result.symbols.setLen(maxCodes)

  for symbol in 0 ..< lengths.len:
    inc result.counts[lengths[symbol]]

  var left = 1.uint16
  for l in 1 .. maxCodeLength:
    left = left shl 1
    left = left - result.counts[l]
    if left < 0:
      failUncompress()

  var offsets = newSeq[uint16](maxCodeLength + 1)
  for l in 1 ..< maxCodeLength:
    offsets[l + 1] = offsets[l] + result.counts[l]

  for symbol in 0 ..< lengths.len:
    if lengths[symbol] != 0:
      result.symbols[offsets[lengths[symbol]]] = symbol.uint16
      inc offsets[lengths[symbol]]

func decodeSymbol(b: var Buffer, h: Huffman): uint16 {.inline.} =
  var
    code, first, count, index: int
    len = 1
    bits = b.data[b.bytePos] shr b.bitPos
    left = 8 - b.bitPos

  template fastSkip(count: int) =
    inc(b.bitPos, count)
    inc(b.bytePos, (b.bitPos shr 3) and 1)
    b.bitPos = b.bitPos and 7

  while true:
    for i in 1 .. left:
      code = code or (bits and 1).int
      bits = bits shr 1
      count = h.counts[len].int
      if code - count < first:
        fastSkip(i)
        return h.symbols[index + (code - first)]
      index = index + count
      first = first + count
      first = first shl 1
      code = code shl 1
      inc len

    fastSkip(left)
    left = (maxCodeLength + 1) - len
    if left == 0:
      break
    b.checkBytePos()
    bits = b.data[b.bytePos]
    left = min(left, 8)

  failUncompress()

func inflateNoCompression(b: var Buffer, dst: var seq[uint8]) =
  b.skipRemainingBitsInCurrentByte()
  let len = b.readBits(16).int
  b.skipBits(16) # nlen
  let pos = dst.len
  dst.setLen(pos + len) # Make room for the bytes to be copied to
  b.readBytes(dst[pos].addr, len)

func inflateBlock(b: var Buffer, dst: var seq[uint8], fixedCodes: bool) =
  var literalHuffman, distanceHuffman: Huffman

  if fixedCodes:
    literalHuffman = initHuffman(fixedCodeLengths, maxFixedLitLenCodes)
    distanceHuffman = initHuffman(fixedDistanceLengths, maxDistCodes)
  else:
    let
      hlit = b.readBits(5).int + 257
      hdist = b.readBits(5).int + 1
      hclen = b.readBits(4).int + 4

    var codeLengths = newSeq[uint8](19)
    for i in 0 ..< hclen.int:
      codeLengths[codeLengthOrder[i]] = b.readBits(3).uint8

    let h = initHuffman(codeLengths, maxLitLenCodes)

    var unpacked: seq[uint8]
    while unpacked.len < hlit + hdist:
      let symbol = decodeSymbol(b, h)
      if symbol <= 15:
        unpacked.add(symbol.uint8)
      elif symbol == 16:
        let prev = unpacked[unpacked.len - 1]
        for i in 0 ..< b.readBits(2).int + 3:
          unpacked.add(prev)
      elif symbol == 17:
        unpacked.setLen(unpacked.len + b.readBits(3).int + 3)
      elif symbol == 18:
        unpacked.setLen(unpacked.len + b.readBits(7).int + 11)
      else:
        raise newException(ZippyError, "Invalid symbol")

    literalHuffman = initHuffman(unpacked[0 ..< hlit], maxLitLenCodes)
    distanceHuffman = initHuffman(unpacked[hlit ..< unpacked.len], maxDistCodes)

  var pos = dst.len
  while true:
    let symbol = decodeSymbol(b, literalHuffman)
    if symbol <= 255:
      if pos >= dst.len:
        dst.setLen((pos + 1) * 2)
      dst[pos] = symbol.uint8
      inc pos
    elif symbol == 256:
      break
    else:
      let
        lengthIndex = symbol - 257
        totalLength = (
          baseLengths[lengthIndex] +
          b.readBits(baseLengthsExtraBits[lengthIndex])
        ).int
        distCode = decodeSymbol(b, distanceHuffman)

      if distCode >= 30:
        failUncompress()

      let
        totalDist = (
          baseDistance[distCode] +
          b.readBits(baseDistanceExtraBits[distCode])
        ).int

      if totalDist > pos:
        failUncompress()

      var copyPos = pos - totalDist
      if pos + totalLength > dst.len:
        dst.setLen((pos + totalLength) * 2)
      for i in 0 ..< totalLength:
        dst[pos + i] = dst[copyPos + i]
      inc(pos, totalLength)

  dst.setLen(pos)

func inflate(b: var Buffer, dst: var seq[uint8]) =
  var finalBlock: bool
  while not finalBlock:
    let
      bfinal = b.readBits(1)
      btype = b.readBits(2)
    if bfinal > 0:
      finalBlock = true

    case btype:
    of 0: # No compression
      inflateNoCompression(b, dst)
    of 1: # Compressed with fixed Huffman codes
      inflateBlock(b, dst, true)
    of 2: # Compressed with dynamic Huffman codes
      inflateBlock(b, dst, false)
    else:
      raise newException(ZippyError, "Invalid block header")

func adler32(data: seq[uint8]): uint32 =
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

func uncompress*(src: seq[uint8], dst: var seq[uint8]) =
  ## Uncompresses src into dst. This resizes dst as needed and starts writing
  ## at dst index 0.

  if src.len < 6:
    failUncompress()

  let checksum = (
    src[src.len - 4].uint32 shl 24 or
    src[src.len - 3].uint32 shl 16 or
    src[src.len - 2].uint32 shl 8 or
    src[src.len - 1].uint32
  )

  var b = initBuffer(src[0 ..< src.len - 4])
  let
    cmf = b.readBits(8)
    flg = b.readBits(8)
    cm = cmf and 0b00001111
    cinfo = cmf shr 4

  if cm != 8: # DEFLATE
    raise newException(ZippyError, "Unsupported compression method")
  if cinfo > 7:
    raise newException(ZippyError, "Invalid compression info")
  if ((cmf.uint16 * 256) + flg.uint16) mod 31 != 0:
    raise newException(ZippyError, "Invalid header")
  if (flg and 0b00100000) != 0: # FDICT
    raise newException(ZippyError, "Preset dictionary is not yet supported")

  inflate(b, dst)

  if checksum != adler32(dst):
    raise newException(ZippyError, "Checksum verification failed")

func uncompress*(src: seq[uint8]): seq[uint8] {.inline.} =
  ## Uncompresses src and returns the uncompressed data seq.
  result = newSeqOfCap[uint8](src.len * 3)
  uncompress(src, result)

template uncompress*(src: string): string =
  ## Helper for when preferring to work with strings.
  cast[string](uncompress(cast[seq[uint8]](src)))

{.pop.}
