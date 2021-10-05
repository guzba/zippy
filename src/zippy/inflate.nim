import bitstreams, common, zippyerror

const
  fastBits = 9
  fastMask = (1 shl 9) - 1

type
  Huffman = ref object
    firstCode, firstSymbol: array[16, uint16]
    maxCodes: array[17, uint]
    lengths: array[288, uint8]
    values: array[288, uint16]
    fast: array[1 shl fastBits, uint16]

when defined(release):
  {.push checks: off.}

func reverse16Bits(n: uint16): uint16 {.inline.} =
  result = ((n and 0xAAAA) shr 1) or ((n and 0x5555) shl 1)
  result = ((result and 0xCCCC) shr 2) or ((result and 0x3333) shl 2)
  result = ((result and 0xF0F0) shr 4) or ((result and 0x0F0F) shl 4)
  result = ((result and 0xFF00) shr 8) or ((result and 0x00FF) shl 8)

func reverseBits(n, bits: uint16): uint16 {.inline.} =
  assert bits <= 16
  (reverse16Bits(n.uint16) shr (16.uint16 - bits))

func newHuffman(lengths: seq[uint8], maxNumCodes: int): Huffman =
  ## See https://raw.githubusercontent.com/madler/zlib/master/doc/algorithm.txt

  result = Huffman()

  if lengths.len > maxNumCodes:
    failUncompress()

  var sizes: array[17, uint]
  for i in 0 ..< lengths.len:
    inc sizes[lengths[i]]
  sizes[0] = 0

  for i in 1 ..< 16:
    if sizes[i] > (1.uint shl i):
      failUncompress()

  var
    code, k: uint
    nextCode: array[16, uint]
  for i in 1 ..< 16:
    nextCode[i] = code
    result.firstCode[i] = code.uint16
    result.firstSymbol[i] = k.uint16
    code = code + sizes[i]
    if sizes[i] > 0.uint and code - 1 >= (1.uint shl i):
      failUncompress()
    result.maxCodes[i] = (code shl (16 - i))
    code = code shl 1
    k += sizes[i]

  result.maxCodes[16] = 1 shl 16

  for i, len in lengths:
    if len > 0.uint8:
      let symbolId =
        nextCode[len] - result.firstCode[len] + result.firstSymbol[len]
      result.lengths[symbolId] = len
      result.values[symbolId] = i.uint16
      if len <= fastBits:
        let fast = (len.uint shl 9) or i.uint
        var k = reverseBits(nextCode[len].uint16, len).uint
        while k < (1 shl fastBits):
          result.fast[k] = fast.uint16
          k += (1.uint16 shl len)
      inc nextCode[len]

func decodeSymbol(b: var BitStream, h: Huffman): uint16 {.inline.} =
  ## See https://raw.githubusercontent.com/madler/zlib/master/doc/algorithm.txt
  ## This function is the most important for inflate performance.

  if b.bitCount < 16:
    b.fillBitBuf()

  let
    maxCodesLen = h.maxCodes.len.uint
    fast = h.fast[b.bitBuf and fastMask]
  var len: uint16
  if fast > 0:
    len = (fast shr 9)
    result = fast and 511
  else: # Slow path
    let k = reverse16Bits(b.bitBuf.uint16).uint
    len = 1
    while len < maxCodesLen:
      if k < h.maxCodes[len]:
        break
      inc len

    if len >= 16:
      failUncompress()

    let symbolId = (k shr (16 - len)) - h.firstCode[len] + h.firstSymbol[len]
    result = h.values[symbolId]

  if len.int > b.bitCount:
    failEndOfBuffer()

  b.bitBuf = b.bitBuf shr len
  b.bitCount -= len.int

func inflateBlock(
  b: var BitStream, dst: var string, op: var int, fixedCodes: bool
) =
  var literalHuffman, distanceHuffman: Huffman

  if fixedCodes:
    literalHuffman = newHuffman(fixedCodeLengths, maxFixedLitLenCodes)
    distanceHuffman = newHuffman(fixedDistLengths, maxDistCodes)
  else:
    let
      hlit = b.readBits(5).int + firstLengthCodeIndex
      hdist = b.readBits(5).int + 1
      hclen = b.readBits(4).int + 4

    var clCodeLengths = newSeq[uint8](19)
    for i in 0 ..< hclen:
      clCodeLengths[clclOrder[i]] = b.readBits(3).uint8

    let h = newHuffman(clCodeLengths, 19)

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

    literalHuffman = newHuffman(unpacked[0 ..< hlit], maxLitLenCodes)
    distanceHuffman = newHuffman(unpacked[hlit ..< unpacked.len], maxDistCodes)

  while true:
    let symbol = decodeSymbol(b, literalHuffman)
    if symbol <= 255:
      if op >= dst.len:
        dst.setLen((op + 1) * 2)
      dst[op] = symbol.char
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

func inflateNoCompression(b: var BitStream, dst: var string, op: var int) =
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

func inflate*(dst: var string, src: string, pos = 0) =
  var
    b = initBitStream(src, pos)
    op: int
    finalBlock: bool
  while not finalBlock:
    let
      bfinal = b.readBits(1)
      btype = b.readBits(2)
    if bfinal > 0:
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

func inflate*(src: string): string =
  result = newStringOfCap(src.len)
  inflate(result, src)

when defined(release):
  {.pop.}
