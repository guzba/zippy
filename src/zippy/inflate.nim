import bitstreams, common, zippyerror

const
  fastBits = 9
  fastMask = (1 shl 9) - 1

type
  Huffman = object
    firstCode, firstSymbol: array[16, uint16]
    maxCodes: array[17, int]
    lengths: array[288, uint8]
    values: array[288, uint16]
    fast: array[1 shl 9, uint16]

when defined(release):
  {.push checks: off.}

func reverse16Bits(n: int): int {.inline.} =
  result = n
  result = ((result and 0xAAAA) shr 1) or ((result and 0x5555) shl 1)
  result = ((result and 0xCCCC) shr 2) or ((result and 0x3333) shl 2)
  result = ((result and 0xF0F0) shr 4) or ((result and 0x0F0F) shl 4)
  result = ((result and 0xFF00) shr 8) or ((result and 0x00FF) shl 8)

func reverseBits(n, bits: int): int {.inline.} =
  assert bits <= 16
  reverse16Bits(n) shr (16 - bits)

func initHuffman(lengths: seq[uint8], maxCodes: int): Huffman =
  ## See https://raw.githubusercontent.com/madler/zlib/master/doc/algorithm.txt

  var sizes: array[17, int]
  for i in 0 ..< lengths.len:
    inc sizes[lengths[i]]
  sizes[0] = 0

  for i in 1 ..< 16:
    if sizes[i] > (1 shl i):
      failUncompress()

  var
    code, k: int
    nextCode: array[16, int]
  for i in 1 ..< 16:
    nextCode[i] = code
    result.firstCode[i] = code.uint16
    result.firstSymbol[i] = k.uint16
    code = code + sizes[i]
    if sizes[i] > 0 and code - 1 >= (1 shl i):
      failUncompress()
    result.maxCodes[i] = (code shl (16 - i))
    code = code shl 1
    k += sizes[i]

  result.maxCodes[16] = 1 shl 16

  for i, len in lengths:
    if len > 0:
      let symbolId =
        nextCode[len] - result.firstCode[len].int + result.firstSymbol[len].int
      result.lengths[symbolId] = len
      result.values[symbolId] = i.uint16
      if len <= fastBits:
        let fast = (len.uint16 shl 9) or i.uint16
        var k = reverseBits(nextCode[len], len.int)
        while k < (1 shl fastBits):
          result.fast[k] = fast
          k += (1 shl len)
      inc nextCode[len]

func decodeSymbol(b: var BitStream, h: Huffman): uint16 {.inline.} =
  ## See https://raw.githubusercontent.com/madler/zlib/master/doc/algorithm.txt
  ## This function is the most important for inflate performance.

  b.checkBytePos()

  var
    bits = b.data[b.bytePos].int shr b.bitPos
    numBits = 8 - b.bitPos

  # Fill bits up since we know codes must be between 1 and 15 bits long
  if b.bytePos + 1 < b.data.len:
    bits = bits or (b.data[b.bytePos + 1].int shl numBits)
  if b.bytePos + 2 < b.data.len:
    bits = bits or (b.data[b.bytePos + 2].int shl (numBits + 8))

  let fast = h.fast[bits and fastMask]
  var len: int
  if fast > 0:
    len = (fast.int shr 9)
    result = fast and 511
  else: # Slow path
    let k = reverse16Bits(bits)
    len = fastBits + 1
    while len < h.maxCodes.len:
      if k < h.maxCodes[len]:
        break
      inc len

    if len == 16:
      failUncompress()

    let symbolId =
      (k shr (16 - len)) - h.firstCode[len].int + h.firstSymbol[len].int
    result = h.values[symbolId]

  b.bytePos += (len + b.bitPos) shr 3
  b.bitPos = (len + b.bitPos) and 7

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

  var op = dst.len
  while true:
    let symbol = decodeSymbol(b, literalHuffman)
    if symbol <= 255:
      if op >= dst.len:
        dst.setLen((op + 1) * 2)
      dst[op] = symbol.uint8
      inc op
    elif symbol == 256:
      break
    else:
      let lengthIndex = symbol - firstLengthCodeIndex
      if lengthIndex >= baseLengths.len:
        failUncompress()

      let totalLength = (
        baseLengths[lengthIndex] +
        b.readBits(baseLengthsExtraBits[lengthIndex])
      ).int

      let distIndex = decodeSymbol(b, distanceHuffman)
      if distIndex >= baseDistances.len:
        failUncompress()

      let totalDist = (
        baseDistances[distIndex] +
        b.readBits(baseDistanceExtraBits[distIndex])
      ).int
      if totalDist > op:
        failUncompress()

      # Min match is 3 so leave room to overwrite by 13
      if op + totalLength + 13 > dst.len:
        dst.setLen((op + totalLength) * 2 + 10)

      if totalLength <= 16 and totalDist >= 8 and dst.len > op + 16:
        copy64(dst, dst, op, op - totalDist)
        copy64(dst, dst, op + 8, op - totalDist + 8)
        inc(op, totalLength)
      elif dst.len - op >= totalLength + 10:
        var
          src = op - totalDist
          pos = op
          remaining = totalLength
        while pos - src < 8:
          copy64(dst, dst, pos, src)
          dec(remaining, pos - src)
          inc(pos, pos - src)
        while remaining > 0:
          copy64(dst, dst, pos, src)
          inc(src, 8)
          inc(pos, 8)
          dec(remaining, 8)
        inc(op, totalLength)
      else:
        for i in op ..< op + totalLength:
          dst[op] = dst[op - totalDist]
          inc op

  dst.setLen(op)

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

func inflate*(dst: var seq[uint8], src: seq[uint8]) =
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
  inflate(result, src)

when defined(release):
  {.pop.}
