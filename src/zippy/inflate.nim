import bitstreams, common, zippyerror

const
  huffmanChunkBits  = 9
  huffmanNumChunks  = 1 shl huffmanChunkBits
  huffmanCountMask  = 15
  huffmanValueShift = 4

type
  Huffman = object
    minCodeLength, maxCodeLength: uint8
    chunks: array[huffmanNumChunks, uint32]
    links: seq[seq[uint32]]
    linkMask: uint32

when defined(release):
  {.push checks: off.}

template failUncompress*() =
  raise newException(
    ZippyError, "Invalid buffer, unable to uncompress"
  )

func initHuffman(lengths: seq[uint8], maxCodes: int): Huffman =
  var
    counts: array[maxCodeLength + 1, uint16]
    numCodes: int

  result.minCodeLength = uint8.high

  for _, n in lengths:
    if n == 0:
      continue
    inc counts[n]
    inc numCodes
    result.minCodeLength = min(n, result.minCodeLength)
    result.maxCodeLength = max(n, result.maxCodeLength)

  if result.maxCodeLength == 0 or
    result.maxCodeLength > maxCodeLength or
    numCodes > maxCodes:
    failUncompress()

  var
    code: uint16
    nextCode: array[maxCodeLength + 1, uint16]
  for i in result.minCodeLength .. result.maxCodeLength:
    code = code shl 1
    nextCode[i] = code
    code += counts[i]

  if code != (1.uint16 shl result.maxCodeLength) and
    not (code == 1 and result.maxCodeLength == 1):
    failUncompress()

  if result.maxCodeLength > huffmanChunkBits:
    let numLinks = 1.uint32 shl (result.maxCodeLength - huffmanChunkBits)
    result.linkMask = numLinks - 1

    let link = nextCode[huffmanChunkBits + 1] shr 1
    result.links.setLen(huffmanNumChunks - link)
    for i in link ..< huffmanNumChunks:
      let
        reverse = reverseUint16(i.uint16, huffmanChunkBits)
        offset = i - link
      result.chunks[reverse] = (
        (offset shl huffmanValueShift) or huffmanChunkBits + 1
      ).uint32
      result.links[offset].setLen(numLinks)

  for i, n in lengths:
    if n == 0:
      continue

    let
      code = nextCode[n]
      chunk = i.uint32 shl huffmanValueShift or n
      reverse = reverseUint16(code, n)
    inc nextCode[n]
    if n <= huffmanChunkBits:
      for offset in countup(reverse.int, result.chunks.high, 1 shl n):
        result.chunks[offset] = chunk
    else:
      let
        j = reverse and (huffmanNumChunks - 1)
        value = result.chunks[j] shr huffmanValueShift
        reverseShifted = reverse shr huffmanChunkBits
      for offset in countup(
        reverseShifted.int,
        result.links[value].high,
        1 shl (n - huffmanChunkBits)
      ):
        result.links[value][offset] = chunk

  # debugEcho result.minCodeLength, " ", result.maxCodeLength, " ", result.chunks, " ", result.links, " ", result.linkMask

func decodeSymbol(b: var BitStream, h: Huffman): uint16 {.inline.} =
  discard

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
    b.readBytes(dst, pos, len)

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
