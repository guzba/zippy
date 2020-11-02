import zippyerror, common, deques, bitstreams, strutils

const
  bitReverseTable = [
    0x00.uint8, 0x80, 0x40, 0xC0, 0x20, 0xA0, 0x60, 0xE0, 0x10, 0x90, 0x50,
    0xD0, 0x30, 0xB0, 0x70, 0xF0, 0x08, 0x88, 0x48, 0xC8, 0x28, 0xA8, 0x68,
    0xE8, 0x18, 0x98, 0x58, 0xD8, 0x38, 0xB8, 0x78, 0xF8, 0x04, 0x84, 0x44,
    0xC4, 0x24, 0xA4, 0x64, 0xE4, 0x14, 0x94, 0x54, 0xD4, 0x34, 0xB4, 0x74,
    0xF4, 0x0C, 0x8C, 0x4C, 0xCC, 0x2C, 0xAC, 0x6C, 0xEC, 0x1C, 0x9C, 0x5C,
    0xDC, 0x3C, 0xBC, 0x7C, 0xFC, 0x02, 0x82, 0x42, 0xC2, 0x22, 0xA2, 0x62,
    0xE2, 0x12, 0x92, 0x52, 0xD2, 0x32, 0xB2, 0x72, 0xF2, 0x0A, 0x8A, 0x4A,
    0xCA, 0x2A, 0xAA, 0x6A, 0xEA, 0x1A, 0x9A, 0x5A, 0xDA, 0x3A, 0xBA, 0x7A,
    0xFA, 0x06, 0x86, 0x46, 0xC6, 0x26, 0xA6, 0x66, 0xE6, 0x16, 0x96, 0x56,
    0xD6, 0x36, 0xB6, 0x76, 0xF6, 0x0E, 0x8E, 0x4E, 0xCE, 0x2E, 0xAE, 0x6E,
    0xEE, 0x1E, 0x9E, 0x5E, 0xDE, 0x3E, 0xBE, 0x7E, 0xFE, 0x01, 0x81, 0x41,
    0xC1, 0x21, 0xA1, 0x61, 0xE1, 0x11, 0x91, 0x51, 0xD1, 0x31, 0xB1, 0x71,
    0xF1, 0x09, 0x89, 0x49, 0xC9, 0x29, 0xA9, 0x69, 0xE9, 0x19, 0x99, 0x59,
    0xD9, 0x39, 0xB9, 0x79, 0xF9, 0x05, 0x85, 0x45, 0xC5, 0x25, 0xA5, 0x65,
    0xE5, 0x15, 0x95, 0x55, 0xD5, 0x35, 0xB5, 0x75, 0xF5, 0x0D, 0x8D, 0x4D,
    0xCD, 0x2D, 0xAD, 0x6D, 0xED, 0x1D, 0x9D, 0x5D, 0xDD, 0x3D, 0xBD, 0x7D,
    0xFD, 0x03, 0x83, 0x43, 0xC3, 0x23, 0xA3, 0x63, 0xE3, 0x13, 0x93, 0x53,
    0xD3, 0x33, 0xB3, 0x73, 0xF3, 0x0B, 0x8B, 0x4B, 0xCB, 0x2B, 0xAB, 0x6B,
    0xEB, 0x1B, 0x9B, 0x5B, 0xDB, 0x3B, 0xBB, 0x7B, 0xFB, 0x07, 0x87, 0x47,
    0xC7, 0x27, 0xA7, 0x67, 0xE7, 0x17, 0x97, 0x57, 0xD7, 0x37, 0xB7, 0x77,
    0xF7, 0x0F, 0x8F, 0x4F, 0xCF, 0x2F, 0xAF, 0x6F, 0xEF, 0x1F, 0x9F, 0x5F,
    0xDF, 0x3F, 0xBF, 0x7F, 0xFF
  ]

type
  Coin = object
    symbols: seq[uint16]
    weight: uint64

# {.push checks: off.}

template failCompress() =
  raise newException(
    ZippyError, "Unexpected error while compressing"
  )

func `<`(a, b: Coin): bool = a.weight < b.weight

func quicksort[T](s: var seq[T], inl, inr: int) =
  var
    r = inr
    l = inl
  let n = r - l + 1
  if n < 2:
    return
  let p = l + 3 * n div 4
  while l <= r:
    if s[l] < s[p]:
      inc l
      continue
    if s[r] > s[p]:
      dec r
      continue
    if l <= r:
      swap(s[l], s[r])
      inc l
      dec r
  quicksort(s, inl, r)
  quicksort(s, l, inr)

func lengthLimitedHuffmanCodeLengths(
  frequencies: seq[uint64], minCodes, maxBitLen: int
): (int, seq[uint8], seq[uint16]) =
  # See https://en.wikipedia.org/wiki/Huffman_coding#Length-limited_Huffman_coding

  var numSymbolsUsed: int
  for freq in frequencies:
    if freq > 0:
      inc numSymbolsUsed

  let numCodes = max(numSymbolsUsed, minCodes)
  var
    depths = newSeq[uint8](frequencies.len)
    codes = newSeq[uint16](frequencies.len)

  if numSymbolsUsed == 0:
    depths[0] = 1
    depths[1] = 1
  elif numSymbolsUsed == 1:
    for i, freq in frequencies:
      if freq != 0:
        depths[i] = 1
        if i == 0:
          depths[1] = 1
        else:
          depths[0] = 1
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
      coins[i].symbols.setLen(coins.len)
      coins[i].symbols.setLen(0)
      prevCoins[i].symbols.setLen(coins.len)
      prevCoins[i].symbols.setLen(0)

    addSymbolCoins(coins, 0)

    quicksort(coins, 0, numSymbolsUsed - 1)

    var
      numCoins = numSymbolsUsed
      numCoinsPrev: int
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

      quicksort(coins, 0, numCoins - 1)

    for i in 0 ..< numSymbolsUsed - 1:
      for j in 0 ..< coins[i].symbols.len:
        inc depths[coins[i].symbols[j]]

  var depthCounts: array[16, uint8]
  for d in depths:
    inc depthCounts[d]

  depthCounts[0] = 0

  # debugEcho "c depthCounts: ", depthCounts

  var nextCode: array[16, uint16]
  for i in 1 .. maxBitLen:
    nextCode[i] = (nextCode[i - 1] + depthCounts[i - 1]) shl 1

  # debugEcho "c nextCode: ", nextCode

  template reverseCode(code: uint16, depth: uint8): uint16 =
    (
      (bitReverseTable[code.uint8].uint16 shl 8) or
      (bitReverseTable[(code shr 8).uint8].uint16)
    ) shr (16 - depth)

  # Convert to canonical codes (+ reversed)
  for i in 0 ..< codes.len:
    if depths[i] != 0:
      codes[i] = reverseCode(nextCode[depths[i]], depths[i])
      inc nextCode[depths[i]]

  (numCodes, depths, codes)

func compress*(src: seq[uint8]): seq[uint8] =
  ## Uncompresses src and returns the compressed data seq.

  var b = initBitStream()
  b.data.setLen(5)

  const
    cm = 8.uint8
    cinfo = 7.uint8
    cmf = (cinfo shl 4) or cm
    fcheck = (31 - (cmf.uint32 * 256) mod 31).uint8

  b.addBits(cmf, 8)
  b.addBits(fcheck, 8)

  # No lz77 for now, just Huffman coding
  let encoded = src

  var
    freqLitLen = newSeq[uint64](286)
    freqDist = newSeq[uint64](30)

  for symbol in encoded:
    inc freqLitLen[symbol]

  # debugEcho encoded.len
  # debugEcho "c freqLitLen: ", freqLitLen

  freqLitLen[256] = 1 # Alway 1 end-of-block symbol

  let
    (numCodesLitLen, depthsLitLen, codesLitLen) = lengthLimitedHuffmanCodeLengths(freqLitLen, 257, 10)
    (numCodesDist, depthsDist, codesDist) = lengthLimitedHuffmanCodeLengths(freqDist, 2, 6)
    storedCodesLitLen = min(numCodesLitLen, maxLitLenCodes)
    storedCodesDist = min(numCodesDist, maxDistCodes)

  # fail if numCodesLitLen + numCodesDist > max stored limit

  var bitLens = newSeq[uint8](storedCodesLitLen + storedCodesDist)
  for i in 0 ..< storedCodesLitLen:
    bitLens[i] = depthsLitLen[i]
  for i in 0 ..< storedCodesDist:
    bitLens[i + storedCodesLitLen] = depthsDist[i]

  # debugEcho "c bitLens: ", bitLens

  var
    bitLensRle: seq[uint8]
    i, bitCount: int
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

  # debugEcho "c bitLensRle: ", bitLensRle

  # debugEcho (bitCount + 7) div 8
  b.data.setLen(b.data.len + (bitCount + 7) div 8)

  var
    freqCodeLen = newSeq[uint64](19)
    j: int
  while j < bitLensRle.len:
    inc freqCodeLen[bitLensRle[j]]
    # Skip the number of times codes are repeated
    if bitLensRle[j] >= 16:
      inc j
    inc j

  # debugEcho "c freqCodeLen: ", freqCodeLen

  let (_, depthsCodeLen, codesCodeLen) = lengthLimitedHuffmanCodeLengths(freqCodeLen, freqCodeLen.len, 7)

  var bitLensCodeLen = newSeq[uint8](freqCodeLen.len)
  for i in 0 ..< bitLensCodeLen.len:
    bitLensCodeLen[i] = depthsCodeLen[codeLengthOrder[i]]

  # debugEcho bitLensCodeLen

  while bitLensCodeLen[bitLensCodeLen.high] == 0 and bitLensCodeLen.len > 4:
    bitLensCodeLen.setLen(bitLensCodeLen.len - 1)

  # debugEcho "c bitLensCodeLen: ", bitLensCodeLen

  b.addBit(1)
  b.addBits(2, 2)

  let
    hlit = (storedCodesLitLen - 257).uint8
    hdist = storedCodesDist.uint8 - 1
    hclen = bitLensCodeLen.len.uint8 - 4

  # debugEcho hlit + 257, " ", hdist + 1, " ", hclen + 4

  b.addBits(hlit, 5)
  b.addBits(hdist, 5)
  b.addBits(hclen, 4)

  # debugEcho "c depthsCodeLen: ", depthsCodeLen

  b.data.setLen(b.data.len + (((hclen.int + 4) * 3 + 7) div 8))

  for i in 0.uint8 ..< hclen + 4:
    b.addBits(bitLensCodeLen[i], 3)

  # debugEcho b.bytePos, " ", b.bitPos

  var k: int
  while k < bitLensRle.len:
    let symbol = bitLensRle[k]
    # debugEcho "c s: ", symbol, " ", codesCodeLen[symbol], " ", depthsCodeLen[symbol], " ", toBin(codesCodeLen[symbol].int, 8)
    b.addBits(codesCodeLen[symbol], depthsCodeLen[symbol].int)
    if symbol == 16:
      inc k
      b.addBits(bitLensRle[k], 2)
    elif symbol == 17:
      inc k
      b.addBits(bitLensRle[k], 3)
    elif symbol == 18:
      inc k
      b.addBits(bitLensRle[k], 7)
    inc k

  b.data.setLen(b.data.len + ((encoded.len * 15) + 7) div 8)

  for i in 0 ..< encoded.len:
    let symbol = encoded[i]
    b.addBits(codesLitLen[symbol], depthsLitLen[symbol].int)

  if depthsLitLen[256] == 0:
    failCompress()

  b.addBits(codesLitLen[256], depthsLitLen[256].int) # End of block

  b.skipRemainingBitsInCurrentByte()
  b.data.setLen(b.data.len + 1)

  let checksum = cast[array[4, uint8]](adler32(src))
  b.addBits(checkSum[3], 8)
  b.addBits(checkSum[2], 8)
  b.addBits(checkSum[1], 8)
  b.addBits(checkSum[0], 8)

  b.data.setLen(b.bytePos + 1)
  b.data

template compress*(src: string): string =
  ## Helper for when preferring to work with strings.
  cast[string](compress(cast[seq[uint8]](src)))

# {.pop.}
