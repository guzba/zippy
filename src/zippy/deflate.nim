import bitstreams, common, zippy/lz77, zippy/snappy, strformat, zippyerror

const
  # These are not the true max lengths, they trade off speed vs compression
  maxLitLenCodeLength = 9
  maxDistCodeLength = 6

when defined(release):
  {.push checks: off.}

func huffmanCodeLengths(
  frequencies: seq[int], minCodes, maxBitLen: int
): (int, seq[uint8], seq[uint16]) =
  # See https://en.wikipedia.org/wiki/Huffman_coding#Length-limited_Huffman_coding

  # TODO: Revisit this with a better understanding of the Coin Collector algo.

  assert maxBitLen <= maxCodeLength

  type Coin = object
    symbols: seq[uint16]
    weight: int

  func quickSort(s: var seq[Coin], lo, hi: int) =
    if lo >= hi:
      return

    var
      pivot = lo
      swapPos = lo + 1
    for i in lo + 1 .. hi:
      if s[i].weight < s[pivot].weight:
        swap(s[i], s[swapPos])
        swap(s[pivot], s[swapPos])
        inc pivot
        inc swapPos

    quickSort(s, lo, pivot - 1)
    quickSort(s, pivot + 1, hi)

  func insertionSort(s: var seq[Coin], hi: int) =
    for i in 1 .. hi:
      var
        j = i - 1
        k = i
      while j >= 0 and s[j].weight > s[k].weight:
        swap(s[j + 1], s[j])
        dec j
        dec k

  template sort(s: var seq[Coin], lo, hi: int) =
    if hi - lo < 64:
      insertionSort(s, hi)
    else:
      quickSort(s, lo, hi)

  var numSymbolsUsed: int
  for freq in frequencies:
    if freq > 0:
      inc numSymbolsUsed

  let numCodes = frequencies.len # max(numSymbolsUsed, minCodes)
  var
    lengths = newSeq[uint8](frequencies.len)
    codes = newSeq[uint16](frequencies.len)

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
    func addSymbolCoins(coins: var seq[Coin], start: int) =
      var idx = start
      for i in 0 ..< numCodes:
        let freq = frequencies[i]
        if freq > 0:
          coins[idx].symbols.add(i.uint16)
          coins[idx].weight = freq
          inc idx

    var
      coins = newSeq[Coin](numSymbolsUsed * 2)
      prevCoins = newSeq[Coin](coins.len)

    for i in 0 ..< coins.len:
      # Cause the symbol seqs to have the correct capacity.
      # Benchmarking shows this increases perf.
      coins[i].symbols.setLen(coins.len)
      coins[i].symbols.setLen(0)
      prevCoins[i].symbols.setLen(coins.len)
      prevCoins[i].symbols.setLen(0)

    addSymbolCoins(coins, 0)

    sort(coins, 0, numSymbolsUsed - 1)

    var
      numCoins = numSymbolsUsed
      numCoinsPrev = 0
    for bitLen in 1 .. maxBitLen:
      swap(prevCoins, coins)
      swap(numCoinsPrev, numCoins)

      for i in 0 ..< numCoins:
        coins[i].symbols.setLen(0)
        coins[i].weight = 0

      numCoins = 0

      for i in countup(0, numCoinsPrev - 2, 2):
        coins[numCoins].weight = prevCoins[i].weight
        coins[numCoins].symbols.add(prevCoins[i].symbols)
        coins[numCoins].symbols.add(prevCoins[i + 1].symbols)
        coins[numCoins].weight += prevCoins[i + 1].weight
        inc numCoins

      if bitLen < maxBitLen:
        addSymbolCoins(coins, numCoins)
        inc(numCoins, numSymbolsUsed)

      sort(coins, 0, numCoins - 1)

    for i in 0 ..< numSymbolsUsed - 1:
      for j in 0 ..< coins[i].symbols.len:
        inc lengths[coins[i].symbols[j]]

  var lengthCounts: array[maxCodeLength + 1, uint8]
  for l in lengths:
    inc lengthCounts[l]

  lengthCounts[0] = 0

  var nextCode: array[maxCodeLength + 1, uint16]
  for i in 1 .. maxBitLen:
    nextCode[i] = (nextCode[i - 1] + lengthCounts[i - 1]) shl 1

  # Convert to canonical codes (+ reversed)
  for i in 0 ..< codes.len:
    if lengths[i] != 0:
      codes[i] = reverseUint16(nextCode[lengths[i]], lengths[i])
      inc nextCode[lengths[i]]

  (numCodes, lengths, codes)

func huffmanOnlyEncode(
  src: seq[uint8]
): (seq[uint16], seq[int], seq[int], int) =
  var
    encoded = newSeq[uint16]()
    freqLitLen = newSeq[int](286)
    freqDist = newSeq[int](baseDistance.len)

  freqLitLen[256] = 1 # Alway 1 end-of-block symbol

  for i, c in src:
    inc freqLitLen[c]

  for i in 0 ..< src.len div maxLiteralLength:
    encoded.add(maxLiteralLength.uint16)

  encoded.add((src.len mod maxLiteralLength).uint16)

  (encoded, freqLitLen, freqDist, 0)

func deflateNoCompression(src: seq[uint8]): seq[uint8] =
  let blockCount = max(
    (src.len + maxUncompressedBlockSize - 1) div maxUncompressedBlockSize,
    1
  )

  var b: BitStream
  for i in 0 ..< blockCount:
    b.data.setLen(b.data.len + 6)

    let finalBlock = i == blockCount - 1
    b.addBits(finalBlock.uint8, 8)

    let
      pos = i * maxUncompressedBlockSize
      len = min(src.len - pos, maxUncompressedBlockSize).uint16
      nlen = (maxUncompressedBlockSize - len).uint16

    b.addBits(len, 16)
    b.addBits(nlen, 16)
    if len > 0:
      b.addBytes(src, pos, len.int)

  b.data.setLen(b.bytePos)
  b.data

func deflate*(src: seq[uint8], level = -1): seq[uint8] =
  if level < -2 or level > 9:
    raise newException(ZippyError, &"Invalid compression level {level}")

  if level == 0:
    return deflateNoCompression(src)

  let (encoded, freqLitLen, freqDist, literalsTotal) = block:
    if level == -2:
      huffmanOnlyEncode(src)
    elif level == 1:
      snappyEncode(src)
    else:
      lz77Encode(src, configurationTable[if level == -1: 6 else: level])

  # If lz77 encoding returned almost all literal runs then write uncompressed.
  if literalsTotal >= (src.len.float32 * 0.98).int:
    return deflateNoCompression(src)

  # Deflate using dynamic Huffman tree

  let
    (llNumCodes, llLengths, llCodes) = huffmanCodeLengths(
      freqLitLen, 257, maxLitLenCodeLength
    )
    (distNumCodes, distLengths, distCodes) = huffmanCodeLengths(
      freqDist, 2, maxDistCodeLength
    )

  var bitLens = newSeqOfCap[uint8](llNumCodes + distNumCodes)
  for i in 0 ..< llNumCodes:
    bitLens.add(llLengths[i])
  for i in 0 ..< distNumCodes:
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
        inc(i, repeatCount - 1)
        inc(bitCount, 7)
      elif repeatCount >= 3: # Repeat code for non-zero, must be >= 3 times
        var
          a = repeatCount div 6
          b = repeatCount mod 6
        bitLensRle.add(bitLens[i])
        for j in 0 ..< a:
          bitLensRle.add([16.uint8, 3])
        if b >= 3:
          bitLensRle.add([16.uint8, b.uint8 - 3])
        else:
          dec(repeatCount, b)
        inc(i, repeatCount)
        inc(bitCount, (a + b) * 2)
      else:
        bitLensRle.add(bitLens[i])
      inc i
      inc(bitCount, 7)

  var clFreq = newSeq[int](19)
  block count_cl_frequencies:
    var i: int
    while i < bitLensRle.len:
      inc clFreq[bitLensRle[i]]
      # Skip the number of times codes are repeated
      if bitLensRle[i] >= 16:
        inc i
      inc i

  let (_, clLengths, clCodes) = huffmanCodeLengths(clFreq, clFreq.len, 7)

  var bitLensCodeLen = newSeq[uint8](clFreq.len)
  for i in 0 ..< bitLensCodeLen.len:
    bitLensCodeLen[i] = clLengths[clclOrder[i]]

  while bitLensCodeLen[bitLensCodeLen.high] == 0 and bitLensCodeLen.len > 4:
    bitLensCodeLen.setLen(bitLensCodeLen.len - 1)

  let
    hlit = (llNumCodes - 257).uint8
    hdist = distNumCodes.uint8 - 1
    hclen = bitLensCodeLen.len.uint8 - 4

  var b: BitStream
  # TODO: Improve the b.data.setLens
  b.data.setLen(
    b.data.len +
    (((hclen.int + 4) * 3 + 7) div 8) + # hclen rle
    bitLensRle.len * 2
  )

  b.addBit(1)
  b.addBits(2, 2)

  b.addBits(hlit, 5)
  b.addBits(hdist, 5)
  b.addBits(hclen, 4)

  for i in 0.uint8 ..< hclen + 4:
    b.addBits(bitLensCodeLen[i], 3)

  block write_bitlens_rle:
    var i: int
    while i < bitLensRle.len:
      let symbol = bitLensRle[i]
      b.addBits(clCodes[symbol], clLengths[symbol].int)
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
          distExtra = offset - baseDistance[distIndex]
        inc(encPos, 3)
        inc(srcPos, length.int)

        if b.bytePos + 6 > b.data.len:
          b.data.setLen(b.data.len * 2)

        b.addBits(
          llCodes[lengthIndex + firstLengthCodeIndex],
          llLengths[lengthIndex + firstLengthCodeIndex].int
        )
        b.addBits(lengthExtra, lengthExtraBits)
        b.addBits(distCodes[distIndex], distLengths[distIndex].int)
        b.addBits(distExtra, distExtraBits)
      else:
        let length = encoded[encPos].int
        inc encPos

        let worstCaseBytesNeeded = (length * maxLitLenCodeLength + 7) div 8
        if b.bytePos + worstCaseBytesNeeded >= b.data.len:
          b.data.setLen(max(b.bytePos + worstCaseBytesNeeded, b.data.len * 2))

        for j in 0 ..< length:
          b.addBits(llCodes[src[srcPos]], llLengths[src[srcPos]].int)
          inc srcPos

  if llLengths[256] == 0:
    failCompress()

  b.addBits(llCodes[256], llLengths[256].int) # End of block

  b.skipRemainingBitsInCurrentByte()

  b.data.setLen(b.bytePos)
  b.data

when defined(release):
  {.pop.}
