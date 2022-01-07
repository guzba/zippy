import bitstreams, heapqueue, internal, zippy/lz77, zippy/snappy, zippyerror

when defined(release):
  {.push checks: off.}

type Node = ref object
  symbol, freq: int
  left, right: Node

proc `<`(a, b: Node): bool {.inline.} =
  a.freq < b.freq

func huffmanCodeLengths(
  frequencies: seq[int], minCodes, maxCodeLen: int
): (seq[uint8], seq[uint16]) =
  # https://en.wikipedia.org/wiki/Huffman_coding#Length-limited_Huffman_coding
  # https://en.wikipedia.org/wiki/Canonical_Huffman_code
  # https://create.stephan-brumme.com/length-limited-prefix-codes/

  var
    highestSymbol: int
    numSymbolsUsed: int
  for symbol, freq in frequencies:
    if freq > 0:
      highestSymbol = symbol
      inc numSymbolsUsed

  var
    numCodes = max(highestSymbol + 1, 2)
    lengths = newSeq[uint8](numCodes)
    codes = newSeq[uint16](numCodes)

  if numSymbolsUsed == 0:
    lengths[0] = 1
    lengths[1] = 1
  elif numSymbolsUsed == 1:
    for i, freq in frequencies:
      if freq != 0:
        lengths[i] = 1
        if i == 0:
          lengths[1] = 1
        else:
          lengths[0] = 1
        break
  else:
    var nodes: seq[Node]
    for symbol, freq in frequencies:
      if freq > 0:
        nodes.add(Node(
          symbol: symbol,
          freq: freq
        ))

    proc buildTree(nodes: seq[Node]): bool =
      var needsLengthLimiting: bool

      var heap: HeapQueue[Node]
      for node in nodes:
        heap.push(node)

      while heap.len >= 2:
        let node = Node(
          symbol: -1,
          left: heap.pop(),
          right: heap.pop()
        )
        node.freq = node.left.freq + node.right.freq
        heap.push(node)

      proc walk(node: Node, level: int) =
        if node.symbol == -1:
          heap.push(node.left)
          heap.push(node.right)
          walk(node.left, level + 1)
          walk(node.right, level + 1)
        else:
          node.freq = level # Re-use freq for level
          if level > maxCodeLen:
            needsLengthLimiting = true

      walk(heap[0], 0)

      needsLengthLimiting

    let needsLengthLimiting = buildTree(nodes)

    if not needsLengthLimiting:
      for node in nodes:
        lengths[node.symbol] = node.freq.uint8
    else:
      var maxLength: int
      for node in nodes:
        maxLength = max(maxLength, node.freq)

      var histogramNumBits = newSeq[int](maxLength + 1)
      for node in nodes:
        inc histogramNumBits[node.freq]

      var i = maxLength
      while i > maxCodeLen:
        if histogramNumBits[i] == 0:
          dec i
          continue

        var j = i - 2
        while j > 0 and histogramNumBits[j] == 0:
          dec j

        histogramNumBits[i] -= 2
        inc histogramNumBits[i - 1]

        histogramNumBits[j + 1] += 2
        dec histogramNumBits[j]

      proc quickSort(a: var seq[Node], inl, inr: int) =
        var
          r = inr
          l = inl
        let n = r - l + 1
        if n < 2:
          return
        let p = a[l + 3 * n div 4].freq
        while l <= r:
          if a[l].freq < p:
            inc l
          elif a[r].freq > p:
            dec r
          else:
            swap(a[l], a[r])
            inc l
            dec r
        quickSort(a, inl, r)
        quickSort(a, l, inr)

      quicksort(nodes, 0, nodes.high)

      var bitLen = 1
      for node in nodes:
        while histogramNumBits[bitLen] == 0:
          inc bitLen
          continue
        node.freq = bitLen
        dec histogramNumBits[bitLen]

      for node in nodes:
        lengths[node.symbol] = node.freq.uint8

  var lengthCounts: array[maxCodeLength + 1, uint8]
  for l in lengths:
    inc lengthCounts[l]

  lengthCounts[0] = 0

  var nextCode: array[maxCodeLength + 1, uint16]
  for i in 1 .. maxCodeLength:
    nextCode[i] = (nextCode[i - 1] + lengthCounts[i - 1]) shl 1

  # Convert to canonical codes (+ reversed)
  for i in 0 ..< codes.len:
    if lengths[i] != 0:
      codes[i] = reverseUint16(nextCode[lengths[i]], lengths[i])
      inc nextCode[lengths[i]]

  numCodes = max(numCodes, minCodes)
  if lengths.len < numCodes:
    lengths.setLen(numCodes)
  if codes.len < numCodes:
    codes.setLen(numCodes)

  (lengths, codes)

func huffmanOnlyEncode(src: string): (seq[uint16], seq[int], seq[int], int) =
  var
    encoded = newSeq[uint16]()
    freqLitLen = newSeq[int](286)
    freqDist = newSeq[int](baseDistances.len)

  freqLitLen[256] = 1 # Alway 1 end-of-block symbol

  for i, c in src:
    inc freqLitLen[cast[uint8](c)]

  for i in 0 ..< src.len div maxLiteralLength:
    encoded.add(maxLiteralLength.uint16)

  encoded.add((src.len mod maxLiteralLength).uint16)

  (encoded, freqLitLen, freqDist, 0)

func deflateNoCompression(src: string): string =
  let blockCount = max(
    (src.len + maxUncompressedBlockSize - 1) div maxUncompressedBlockSize,
    1
  )

  var b: BitStream
  for i in 0 ..< blockCount:
    let finalBlock = i == blockCount - 1
    b.addBits(finalBlock.uint16, 8)

    let
      pos = i * maxUncompressedBlockSize
      len = min(src.len - pos, maxUncompressedBlockSize).uint16
      nlen = maxUncompressedBlockSize.uint16 - len

    b.addBits(len, 16)
    b.addBits(nlen, 16)
    if len > 0.uint16:
      b.addBytes(src, pos, len.int)

  b.data.setLen(b.pos)
  b.data

func deflate*(src: string, level = -1): string =
  if level < -2 or level > 9:
    raise newException(ZippyError, "Invalid compression level " & $level)

  if level == 0:
    return deflateNoCompression(src)

  let (encoded, freqLitLen, freqDist, literalsTotal) = block:
    if level == -2:
      huffmanOnlyEncode(src)
    elif level == 1:
      snappyEncode(src)
    else:
      # -1 or [2, 9]
      lz77Encode(src, configurationTable[if level == -1: 6 else: level])

  # If encoding returned almost all literals then write uncompressed.
  if literalsTotal >= (src.len.float32 * 0.98).int:
    return deflateNoCompression(src)

  let
    useFixedCodes = src.len <= 2048
    (llLengths, llCodes) = block:
      if useFixedCodes:
        (fixedCodeLengths, fixedCodes)
      else:
        huffmanCodeLengths(freqLitLen, 257, maxCodeLength)
    (distLengths, distCodes) = block:
      if useFixedCodes:
        (fixedDistLengths, fixedDistCodes)
      else:
        huffmanCodeLengths(freqDist, 2, maxCodeLength)

  var b: BitStream
  if useFixedCodes:
    b.addBits(1, 1)
    b.addBits(1, 2) # Fixed Huffman codes
  else:
    var bitLens = newSeqOfCap[uint8](llCodes.len + distCodes.len)
    for i in 0 ..< llCodes.len:
      bitLens.add(llLengths[i])
    for i in 0 ..< distCodes.len:
      bitLens.add(distLengths[i])

    var
      bitLensRle: seq[uint8]
      bitCount: int
    block construct_binlens_rle:
      var i: int
      while i < bitLens.len:
        var repeatCount: int
        while i + repeatCount + 1 < bitLens.len and
          bitLens[i + repeatCount + 1] == bitLens[i]:
          inc repeatCount

        if bitLens[i] == 0 and repeatCount >= 2:
          inc repeatCount # Initial zero
          if repeatCount <= 10:
            bitLensRle.add([17.uint8, repeatCount.uint8 - 3])
          else:
            repeatCount = min(repeatCount, 138) # Max of 138 zeros for code 18
            bitLensRle.add([18.uint8, repeatCount.uint8 - 11])
          i += repeatCount - 1
          bitCount += 7
        elif repeatCount >= 3: # Repeat code for non-zero, must be >= 3 times
          var
            a = repeatCount div 6
            b = repeatCount mod 6
          bitLensRle.add(bitLens[i])
          for j in 0 ..< a:
            # bitLensRle.add([16.uint8, 3]) Makes ARC unhappy?
            bitLensRle.add(16)
            bitLensRle.add(3)
          if b >= 3:
            bitLensRle.add([16.uint8, b.uint8 - 3])
          else:
            repeatCount -= b
          i += repeatCount
          bitCount += (a + b) * 2
        else:
          bitLensRle.add(bitLens[i])
        inc i
        bitCount += 7

    var clFreq = newSeq[int](19)
    block count_cl_frequencies:
      var i: int
      while i < bitLensRle.len:
        inc clFreq[bitLensRle[i]]
        # Skip the number of times codes are repeated
        if bitLensRle[i] >= 16.uint8:
          inc i
        inc i

    let (clLengths, clCodes) = huffmanCodeLengths(clFreq, clFreq.len, 7)

    var bitLensCodeLen = newSeq[uint8](clFreq.len)
    for i in 0 ..< bitLensCodeLen.len:
      bitLensCodeLen[i] = clLengths[clclOrder[i]]

    while bitLensCodeLen[bitLensCodeLen.high] == 0 and bitLensCodeLen.len > 4:
      bitLensCodeLen.setLen(bitLensCodeLen.len - 1)

    let
      hlit = (llCodes.len - 257).uint8
      hdist = distCodes.len.uint8 - 1
      hclen = bitLensCodeLen.len.uint8 - 4

    b.addBits(1, 1)
    b.addBits(2, 2) # Dynamic Huffman codes

    b.addBits(hlit, 5)
    b.addBits(hdist, 5)
    b.addBits(hclen, 4)

    for i in 0.uint8 ..< hclen + 4:
      b.addBits(bitLensCodeLen[i], 3)

    block write_bitlens_rle:
      var i: int
      while i < bitLensRle.len:
        let symbol = bitLensRle[i]
        b.addBits(clCodes[symbol], clLengths[symbol])
        inc i
        if symbol == 16:
          b.addBits(bitLensRle[i], 2)
          inc i
        elif symbol == 17:
          b.addBits(bitLensRle[i], 3)
          inc i
        elif symbol == 18:
          b.addBits(bitLensRle[i], 7)
          inc i

  block write_encoded_data:
    var srcPos, encPos: int
    while encPos < encoded.len:
      if (encoded[encPos] and (1 shl 15)) != 0:
        let
          value = encoded[encPos]
          offset = encoded[encPos + 1]
          length = encoded[encPos + 2]
          lengthIndex = (value shr 8) and (uint8.high shr 1)
          distIndex = value and uint8.high
          lengthExtraBits = baseLengthsExtraBits[lengthIndex]
          lengthExtra = length - baseLengths[lengthIndex]
          distExtraBits = baseDistanceExtraBits[distIndex]
          distExtra = offset - baseDistances[distIndex]
        encPos += 3
        srcPos += length.int

        var
          buf = llCodes[lengthIndex + firstLengthCodeIndex].uint32
          len = llLengths[lengthIndex + firstLengthCodeIndex].uint32

        buf = buf or (lengthExtra.uint32 shl len)
        len += lengthExtraBits

        b.addBits(buf, len)

        buf = distCodes[distIndex].uint32
        len = distLengths[distIndex].uint32

        buf = buf or (distExtra.uint32 shl len)
        len += distExtraBits

        b.addBits(buf, len)
      else:
        let length = encoded[encPos].int
        inc encPos

        var j: int
        for _ in 0 ..< length div 2:
          var
            buf = llCodes[cast[uint8](src[srcPos + 0])].uint32
            len = llLengths[cast[uint8](src[srcPos + 0])].uint32

          buf = buf or (llCodes[cast[uint8](src[srcPos + 1])].uint32 shl len)
          len += llLengths[cast[uint8](src[srcPos + 1])]

          b.addBits(buf, len)

          srcPos += 2
          j += 2

        if j != length:
          b.addBits(
            llCodes[cast[uint8](src[srcPos])],
            llLengths[cast[uint8](src[srcPos])]
          )
          inc srcPos

  if llLengths[256] == 0:
    failCompress()

  b.addBits(llCodes[256], llLengths[256]) # End of block

  b.skipRemainingBitsInCurrentByte()

  b.data.setLen(b.pos)
  b.data

when defined(release):
  {.pop.}
