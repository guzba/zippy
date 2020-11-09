import bitstreams, common, zippyerror

type
  Huffman = object
    counts: seq[uint16]
    symbols: seq[uint16]

when defined(release):
  {.push checks: off.}

template failUncompress*() =
  raise newException(
    ZippyError, "Invalid buffer, unable to uncompress"
  )

func initHuffman(lengths: seq[uint8], maxCodes: int): Huffman =
  ## See https://github.com/madler/zlib/blob/master/contrib/puff/puff.c

  if lengths.len > maxCodes:
    failUncompress()

  result = Huffman()
  result.counts.setLen(maxCodeLength + 1)
  result.symbols.setLen(maxCodes)

  for symbol in 0 ..< lengths.len:
    inc result.counts[lengths[symbol]]

  if result.counts[0] >= maxCodes.uint16:
    failUncompress()

  var left = 1
  for l in 1 .. maxCodeLength:
    left = left shl 1
    left = left - result.counts[l].int
    if left < 0:
      failUncompress()

  var offsets = newSeq[uint16](maxCodeLength + 1)
  for l in 1 ..< maxCodeLength:
    offsets[l + 1] = offsets[l] + result.counts[l]

  for symbol in 0 ..< lengths.len:
    if lengths[symbol] != 0:
      let offset = offsets[lengths[symbol]]
      if offset.int >= result.symbols.len:
        failUncompress()
      result.symbols[offset] = symbol.uint16
      inc offsets[lengths[symbol]]

func decodeSymbol(b: var BitStream, h: Huffman): uint16 {.inline.} =
  ## See https://github.com/madler/zlib/blob/master/contrib/puff/puff.c

  b.checkBytePos()

  var
    code, first, count, index: int
    len = 1
    bits = b.data[b.bytePos] shr b.bitPos
    left = 8 - b.bitPos

  template fastSkip(count: int) =
    inc(b.bitPos, count)
    inc(b.bytePos, b.bitPos shr 3)
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

func inflateNoCompression(b: var BitStream, dst: var seq[uint8]) =
  b.skipRemainingBitsInCurrentByte()
  let
    len = b.readBits(16).int
    nlen = b.readBits(16).int
  if len + nlen != 65535:
    failUncompress()
  if len > 0:
    let pos = dst.len
    dst.setLen(pos + len) # Make room for the bytes to be copied to
    b.readBytes(dst[pos].addr, len)

func inflateBlock(b: var BitStream, dst: var seq[uint8], fixedCodes: bool) =
  var literalHuffman, distanceHuffman: Huffman

  if fixedCodes:
    literalHuffman = initHuffman(fixedCodeLengths, maxFixedLitLenCodes)
    distanceHuffman = initHuffman(fixedDistanceLengths, maxDistCodes)
  else:
    let
      hlit = b.readBits(5).int + firstLengthCodeIndex
      hdist = b.readBits(5).int + 1
      hclen = b.readBits(4).int + 4

    var clCodeLengths = newSeq[uint8](19)
    for i in 0 ..< hclen.int:
      clCodeLengths[clclOrder[i]] = b.readBits(3).uint8

    let h = initHuffman(clCodeLengths, 19)

    var unpacked: seq[uint8]
    while unpacked.len < hlit + hdist:
      let symbol = decodeSymbol(b, h)
      if symbol <= 15:
        unpacked.add(symbol.uint8)
      elif symbol == 16:
        if unpacked.len == 0:
          failUncompress()
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
      let lengthIndex = symbol - firstLengthCodeIndex

      if lengthIndex >= baseLengths.len:
        failUncompress()

      let
        totalLength = (
          baseLengths[lengthIndex] +
          b.readBits(baseLengthsExtraBits[lengthIndex])
        ).int
        distIndex = decodeSymbol(b, distanceHuffman)

      if distIndex >= baseDistance.len:
        failUncompress()

      let
        totalDist = (
          baseDistance[distIndex] +
          b.readBits(baseDistanceExtraBits[distIndex])
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

func inflate*(src: seq[uint8], dst: var seq[uint8]) =
  var
    b = initBitStream(src)
    finalBlock: bool
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

func inflate*(src: seq[uint8]): seq[uint8] =
  result = newSeqOfCap[uint8](src.len)
  inflate(src, result)

when defined(release):
  {.pop.}
