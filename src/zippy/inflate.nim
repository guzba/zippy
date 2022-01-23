import bitops, bitstreams, internal, common

const
  fastBits = 9
  fastMask = (1 shl 9) - 1

type Huffman = object
  firstCode, firstSymbol: array[16, uint16]
  maxCodes: array[17, uint32]
  lengths: array[288, uint8]
  values: array[288, uint16]
  fast: array[1 shl fastBits, uint16]

when defined(release):
  {.push checks: off.}

proc init(huffman: var Huffman, codeLengths: openArray[uint8]) =
  ## See https://raw.githubusercontent.com/madler/zlib/master/doc/algorithm.txt

  var histogram: array[17, uint16]
  for i in 0 ..< codeLengths.len:
    inc histogram[codeLengths[i]]
  histogram[0] = 0

  for i in 1 ..< 16:
    if histogram[i] > (1.uint16 shl i):
      failUncompress()

  var
    code: uint32
    k: uint16
    nextCode: array[16, uint32]
  for i in 1 ..< 16:
    nextCode[i] = code
    huffman.firstCode[i] = code.uint16
    huffman.firstSymbol[i] = k
    code = code + histogram[i]
    if histogram[i] > 0 and code - 1 >= (1.uint32 shl i):
      failUncompress()
    huffman.maxCodes[i] = (code shl (16 - i))
    code = code shl 1
    k += histogram[i]

  huffman.maxCodes[16] = 1 shl 16

  for i, len in codeLengths:
    if len > 0.uint8:
      let symbolId =
        nextCode[len] - huffman.firstCode[len] + huffman.firstSymbol[len]
      huffman.lengths[symbolId] = len
      huffman.values[symbolId] = i.uint16
      if len <= fastBits:
        let fast = (len.uint16 shl 9) or i.uint16
        var k = reverseBits(nextCode[len].uint16) shr (16.uint16 - len)
        while k < (1 shl fastBits):
          huffman.fast[k] = fast
          k += (1.uint16 shl len)
      inc nextCode[len]

proc decodeSymbol(b: var BitStream, h: var Huffman): uint16 {.inline.} =
  ## See https://raw.githubusercontent.com/madler/zlib/master/doc/algorithm.txt
  ## This function is the most important for inflate performance.

  if b.bitCount < 16:
    b.fillBitBuf()

  let
    maxCodesLen = h.maxCodes.len.uint
    fast = h.fast[b.bitBuf and fastMask]
  var len: uint16
  if fast > 0.uint16:
    len = (fast shr 9)
    result = fast and 511
  else: # Slow path
    let k = reverseBits(cast[uint16](b.bitBuf)).uint
    len = 1
    while len < maxCodesLen.uint16:
      if k < h.maxCodes[len]:
        break
      inc len

    if len >= 16.uint16:
      failUncompress()

    let symbolId = (k shr (16.uint16 - len)) - h.firstCode[len] + h.firstSymbol[len]
    result = h.values[symbolId]

  if len.int > b.bitCount:
    failEndOfBuffer()

  b.bitBuf = b.bitBuf shr len
  b.bitCount -= len.int

proc inflateBlock(
  b: var BitStream, dst: var string, op: var int, fixedCodes: bool
) =
  var literalsHuffman, distancesHuffman: Huffman
  if fixedCodes:
    literalsHuffman.init(fixedLitLenCodeLengths)
    distancesHuffman.init(fixedDistanceCodeLengths)
  else:
    let
      hlit = b.readBits(5).int + 257
      hdist = b.readBits(5).int + 1
      hclen = b.readBits(4).int + 4

    if hlit > maxLitLenCodes:
      failUncompress()

    if hdist > maxDistanceCodes:
      failUncompress()

    var clcls: array[19, uint8]
    for i in 0 ..< hclen:
      clcls[clclOrder[i]] = b.readBits(3).uint8

    var clclsHuffman: Huffman
    clclsHuffman.init(clcls)

    # From RFC 1951, all code lengths form a single sequence of HLIT + HDIST
    # This means the max unpacked length is 31 + 31 + 257 + 1 = 320

    var
      unpacked: array[320, uint8]
      i: int
    while i != hlit + hdist:
      let symbol = decodeSymbol(b, clclsHuffman)
      if symbol <= 15:
        unpacked[i] = symbol.uint8
        inc i
      elif symbol == 16:
        if i == 0:
          failUncompress()
        let
          prev = unpacked[i - 1]
          repeatCount = b.readBits(2).int + 3
        if i + repeatCount > hlit + hdist:
          failUncompress()
        for _ in 0 ..< repeatCount:
          unpacked[i] = prev
          inc i
      elif symbol == 17:
        let repeatZeroCount = b.readBits(3).int + 3
        i += repeatZeroCount
      elif symbol == 18:
        let repeatZeroCount = b.readBits(7).int + 11
        i += repeatZeroCount
      else:
        raise newException(ZippyError, "Invalid symbol")

    literalsHuffman.init(unpacked.toOpenArray(0, hlit - 1))
    distancesHuffman.init(unpacked.toOpenArray(hlit, hlit + hdist - 1))

  while true:
    let symbol = decodeSymbol(b, literalsHuffman)
    if symbol <= 255:
      if op >= dst.len:
        dst.setLen((op + 1) * 2)
      dst[op] = symbol.char
      inc op
    elif symbol == 256:
      break
    else:
      let lengthIndex = symbol - firstLengthCodeIndex
      if lengthIndex >= baseLengths.len.uint16:
        failUncompress()

      let totalLength = (
        baseLengths[lengthIndex] +
        b.readBits(baseLengthsExtraBits[lengthIndex])
      ).int

      let distanceIdx = decodeSymbol(b, distancesHuffman)
      if distanceIdx >= baseDistances.len.uint16:
        failUncompress()

      let totalDist = (
        baseDistances[distanceIdx] +
        b.readBits(baseDistanceExtraBits[distanceIdx])
      ).int
      if totalDist > op:
        failUncompress()

      # Min match is 3 so leave room to overwrite by 13
      if op + totalLength + 13 > dst.len:
        dst.setLen((op + totalLength) * 2 + 10) # At least 16

      if totalLength <= 16 and totalDist >= 8:
        copy64(dst, dst, op, op - totalDist)
        copy64(dst, dst, op + 8, op - totalDist + 8)
        op += totalLength
      else:
        var
          src = op - totalDist
          pos = op
          remaining = totalLength
        while pos - src < 8:
          copy64(dst, dst, pos, src)
          remaining -= pos - src
          pos += pos - src
        while remaining > 0:
          copy64(dst, dst, pos, src)
          src += 8
          pos += 8
          remaining -= 8
        op += totalLength

proc inflateNoCompression(b: var BitStream, dst: var string, op: var int) =
  b.skipRemainingBitsInCurrentByte()
  let
    len = b.readBits(16).int
    nlen = b.readBits(16).int
  if len + nlen != 65535:
    failUncompress()
  if len > 0:
    dst.setLen(op + len) # Make room for the bytes to be copied to
    b.readBytes(dst, op, len)
  op += len

proc inflate*(dst: var string, src: string, pos: int) =
  var
    b = initBitStream(src, pos)
    op: int
    finalBlock: bool
  while not finalBlock:
    let
      bfinal = b.readBits(1)
      btype = b.readBits(2)
    if bfinal > 0.uint16:
      finalBlock = true

    case btype:
    of 0: # No compression
      inflateNoCompression(b, dst, op)
    of 1: # Compressed with fixed Huffman codes
      inflateBlock(b, dst, op, true)
    of 2: # Compressed with dynamic Huffman codes
      inflateBlock(b, dst, op, false)
    else:
      raise newException(ZippyError, "Invalid block header")

  dst.setLen(op)

when defined(release):
  {.pop.}
