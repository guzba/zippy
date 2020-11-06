import bitstreams, common, deques, zippyerror, bitops

const
  minMatchLen = 3
  maxMatchLen = 258

  windowSize = 1 shl 12
  goodMatchLen = 32
  maxChainLen = 256

  hashBits = 16
  hashSize = 1 shl hashBits
  hashMask = hashSize - 1
  hashShift = (hashBits + minMatchLen - 1) div minMatchLen

  bitReverseTable = block:
    var result: array[256, uint8]
    for i in 0 ..< result.len:
      result[i] = reverseBits(i.uint8)
    result

# {.push checks: off.}

template failCompress() =
  raise newException(
    ZippyError, "Unexpected error while compressing"
  )

func huffmanCodeLengths(
  frequencies: seq[int], minCodes, maxBitLen: int
): (int, seq[uint8], seq[uint16]) =
  # See https://en.wikipedia.org/wiki/Huffman_coding#Length-limited_Huffman_coding

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

  var lengthCounts: array[16, uint8]
  for l in lengths:
    inc lengthCounts[l]

  lengthCounts[0] = 0

  var nextCode: array[16, uint16]
  for i in 1 .. maxBitLen:
    nextCode[i] = (nextCode[i - 1] + lengthCounts[i - 1]) shl 1

  template reverseCode(code: uint16, length: uint8): uint16 =
    (
      (bitReverseTable[code.uint8].uint16 shl 8) or
      (bitReverseTable[(code shr 8).uint8].uint16)
    ) shr (16 - length)

  # Convert to canonical codes (+ reversed)
  for i in 0 ..< codes.len:
    if lengths[i] != 0:
      codes[i] = reverseCode(nextCode[lengths[i]], lengths[i])
      inc nextCode[lengths[i]]

  (numCodes, lengths, codes)

func findCodeIndex(a: openarray[uint16], value: uint16): uint16 =
  for i in 1 .. a.high:
    if value < a[i]:
      return i.uint16 - 1
  a.high.uint16

func lz77Encode(src: seq[uint8]): (seq[uint16], seq[int]) =
  var
    encoded = newSeq[uint16](src.len div 2)
    freqDist = newSeq[int](30)

  assert windowSize <= maxWindowSize
  assert (windowSize and (windowSize - 1)) == 0
  assert (hashSize and hashMask) == 0

  if src.len <= minMatchLen:
    for i in 0 ..< src.len:
      encoded.add(src[i])
    return (encoded, freqDist)

  encoded.setLen(src.len div 2)

  var
    pos, windowPos, hash, op: int
    head = newSeq[int](hashSize) # hash -> pos
    chain = newSeq[int](windowSize) # pos a -> pos b

  template updateHash(value: uint8) =
    hash = ((hash shl hashShift) xor value.int) and hashMask

  template updateChain() =
    chain[windowPos] = head[hash]
    head[hash] = windowPos

  for i in 0 ..< minMatchLen - 1:
    updateHash(src[i])

  while pos < src.len:
    if op + max(4, minMatchLen) > encoded.len:
      encoded.setLen(encoded.len * 2)

    if pos + minMatchLen > src.len:
      encoded[op] = src[pos]
      inc pos
      inc op
      continue

    windowPos = pos and (windowSize - 1)

    updateHash(src[pos + minMatchLen - 1])
    updateChain()

    var
      hashPos = chain[windowPos]
      stop = min(src.len, pos + maxMatchLen)
      chainLen, prevOffset, longestMatchOffset, longestMatchLen: int
    while true:
      if chainLen >= maxChainLen:
        break
      inc chainLen

      let offset =
        if hashPos <= windowPos:
          windowPos - hashPos
        else:
          windowPos - hashPos + windowSize

      if offset <= 0 or offset < prevOffset:
        break

      prevOffset = offset

      var matchLen: int
      for i in 0 ..< stop - pos:
        if src[pos - offset + i] != src[pos + i]:
          break
        inc matchLen

      if matchLen > longestMatchLen:
        longestMatchLen = matchLen
        longestMatchOffset = offset

      if longestMatchLen >= goodMatchLen or hashPos == chain[hashPos]:
        break

      hashPos = chain[hashPos]

    if longestMatchLen > minMatchLen:
      let
        lengthCode = findCodeIndex(baseLengths, longestMatchLen.uint16)
        distCode = findCodeIndex(baseDistance, longestMatchOffset.uint16)
      encoded[op] = (lengthCode + firstLengthCodeIndex).uint16
      encoded[op + 1] = longestMatchLen.uint16 - baseLengths[lengthCode]
      encoded[op + 2] = distCode
      encoded[op + 3] = longestMatchOffset.uint16 - baseDistance[distCode]
      inc(op, 4)
      inc freqDist[distCode]

      for i in 1 ..< longestMatchLen:
        inc pos
        windowPos = pos and (windowSize - 1)
        if pos + minMatchLen < src.len:
          updateHash(src[pos + minMatchLen - 1])
          updateChain()
    else:
      encoded[op] = src[pos]
      inc op
    inc pos

  encoded.setLen(op)
  (encoded, freqDist)

func compress*(src: seq[uint8]): seq[uint8] =
  ## Uncompresses src and returns the compressed data seq.

  var b = BitStream()
  b.data.setLen(5)

  const
    cm = 8.uint8
    cinfo = 7.uint8
    cmf = (cinfo shl 4) or cm
    fcheck = (31 - (cmf.uint32 * 256) mod 31).uint8

  b.addBits(cmf, 8)
  b.addBits(fcheck, 8)

  let (encoded, freqDist) = lz77Encode(src)

  var freqLitLen = newSeq[int](286)
  block count_litlen_frequencies:
    var i: int
    while i < encoded.len:
      let symbol = encoded[i]
      inc freqLitLen[symbol]
      inc i
      if symbol > 256:
        # Skip encoded code and extras
        inc(i, 3)

  freqLitLen[256] = 1 # Alway 1 end-of-block symbol

  let
    (llNumCodes, llLengths, llCodes) = huffmanCodeLengths(freqLitLen, 257, 9)
    (distNumCodes, distLengths, distCodes) = huffmanCodeLengths(freqDist, 2, 6)

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

  b.data.setLen(b.data.len + (bitCount + 7) div 8)

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

  b.addBit(1)
  b.addBits(2, 2)

  let
    hlit = (llNumCodes - 257).uint8
    hdist = distNumCodes.uint8 - 1
    hclen = bitLensCodeLen.len.uint8 - 4

  b.addBits(hlit, 5)
  b.addBits(hdist, 5)
  b.addBits(hclen, 4)

  # TODO: Make these b.data.setLens better
  b.data.setLen(b.data.len +
    (((hclen.int + 4) * 3 + 7) div 8) + # hclen rle
    ((encoded.len * 15 + 7) div 8) + 4 # encoded symbols + checksum
  )

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
    var i: int
    while i < encoded.len:
      let symbol = encoded[i]
      b.addBits(llCodes[symbol], llLengths[symbol].int)
      inc i
      if symbol > 256:
        let
          lengthIndex = (symbol - firstLengthCodeIndex).uint16
          lengthExtraBits = baseLengthsExtraBits[lengthIndex]
          lengthExtra = encoded[i]
          distIndex = encoded[i + 1]
          distExtraBits = baseDistanceExtraBits[distIndex]
          distExtra = encoded[i + 2]
        inc(i, 3)

        b.addBits(lengthExtra, lengthExtraBits)
        b.addBits(distCodes[distIndex], distLengths[distIndex].int)
        b.addBits(distExtra, distExtraBits)

  if llLengths[256] == 0:
    failCompress()

  b.addBits(llCodes[256], llLengths[256].int) # End of block

  b.skipRemainingBitsInCurrentByte()

  let checksum = cast[array[4, uint8]](adler32(src))
  b.addBits(checksum[3], 8)
  b.addBits(checksum[2], 8)
  b.addBits(checksum[1], 8)
  b.addBits(checksum[0], 8)

  b.data.setLen(b.bytePos)
  b.data

template compress*(src: string): string =
  ## Helper for when preferring to work with strings.
  cast[string](compress(cast[seq[uint8]](src)))

# {.pop.}
