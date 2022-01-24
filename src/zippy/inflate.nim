import bitstreams, common, internal, std/bitops

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
    if histogram[i] > 0.uint16 and code - 1 >= (1.uint32 shl i):
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

proc decodeSymbol(
  b: var BitStreamReader,
  h: var Huffman,
  fillsBitBuffer: static[bool] = true
): uint16 {.inline.} =
  ## This function is the most important for inflate performance.
  when fillsBitBuffer:
    if b.bitsBuffered < 16:
      b.fillBitBuffer()

  let fast = h.fast[b.bitBuffer and fastMask]
  var codeLength: uint16
  if fast > 0.uint16:
    codeLength = (fast shr 9)
    result = fast and 511
  else: # Slow path
    let k = reverseBits(cast[uint16](b.bitBuffer))
    codeLength = 1
    let maxCodeLength = h.maxCodes.len.uint16
    while codeLength < maxCodeLength:
      if k.uint32 < h.maxCodes[codeLength]:
        break
      inc codeLength

    if codeLength >= 16.uint16:
      failUncompress()

    let symbolId =
      (k shr (16.uint16 - codeLength)) -
      h.firstCode[codeLength] +
      h.firstSymbol[codeLength]
    result = h.values[symbolId]

  if codeLength.int > b.bitsBuffered:
    failEndOfBuffer()

  b.bitBuffer = b.bitBuffer shr codeLength
  b.bitsBuffered -= codeLength.int

proc inflateBlock(
  dst: var string,
  b: var BitStreamReader,
  op: var int,
  fixedCodes: bool
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
        if i + repeatCount > unpacked.len:
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

      if i > hlit + hdist:
        failUncompress()

    literalsHuffman.init(unpacked.toOpenArray(0, hlit - 1))
    distancesHuffman.init(unpacked.toOpenArray(hlit, hlit + hdist - 1))

  while true:
    let symbol = decodeSymbol(b, literalsHuffman)
    if symbol <= 255:
      if op >= dst.len:
        dst.setLen(max(op * 2, 2))
      dst[op] = symbol.char
      inc op
    elif symbol == 256:
      break
    else:
      b.fillBitBuffer()

      let lengthIdx = (symbol - 257).int
      if lengthIdx >= baseLengths.len:
        failUncompress()

      let copyLength = (
        baseLengths[lengthIdx] +
        b.readBits(baseLengthsExtraBits[lengthIdx].int, false)
      ).int

      let distanceIdx = decodeSymbol(b, distancesHuffman, false)
      if distanceIdx >= baseDistances.len.uint16:
        failUncompress()

      let distance = (
        baseDistances[distanceIdx] +
        b.readBits(baseDistanceExtraBits[distanceIdx].int, false)
      ).int

      if distance > op:
        failUncompress()

      # Min match is 3 so leave room to overwrite by 13
      if op + copyLength + 13 > dst.len:
        dst.setLen((op + copyLength) * 2 + 10) # At least 16

      let dst = cast[ptr UncheckedArray[uint8]](dst[0].addr)

      if copyLength <= 16 and distance >= 8:
        copy64(dst, dst, op, op - distance)
        copy64(dst, dst, op + 8, op - distance + 8)
      else:
        var
          copyFrom = op - distance
          copyTo = op
          remaining = copyLength
        while copyTo - copyFrom < 8:
          copy64(dst, dst, copyTo, copyFrom)
          remaining -= copyTo - copyFrom
          copyTo += copyTo - copyFrom
        while remaining > 0:
          copy64(dst, dst, copyTo, copyFrom)
          copyFrom += 8
          copyTo += 8
          remaining -= 8
      op += copyLength

proc inflateNoCompression(
  dst: var string,
  b: var BitStreamReader,
  op: var int
) =
  b.skipRemainingBitsInCurrentByte()
  let
    len = b.readBits(16).int
    nlen = b.readBits(16).int
  if len + nlen != 65535:
    failUncompress()
  if len > 0:
    dst.setLen(op + len) # Make room for the bytes to be copied to
    b.readBytes(dst[op].addr, len)
  op += len

proc inflate*(dst: var string, src: ptr UncheckedArray[uint8], len, pos: int) =
  var
    b = BitStreamReader(src: src, len: len, pos: pos)
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
      inflateNoCompression(dst, b, op)
    of 1: # Compressed with fixed Huffman codes
      inflateBlock(dst, b, op, true)
    of 2: # Compressed with dynamic Huffman codes
      inflateBlock(dst, b, op, false)
    else:
      raise newException(ZippyError, "Invalid block header")

  dst.setLen(op)

when defined(release):
  {.pop.}
