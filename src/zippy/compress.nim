import zippyerror, common, deques, bitstreams, strutils

const
  minLitLenCodes = 286
  minDistCodes = 30
#   blockSize = 65535
#   windowSize = 32768

type
  Node {.acyclic.} = ref object
    symbol: uint16
    weight: uint32
    kids: array[2, Node] # left = [0], right = [1]
    leaf: bool

# {.push checks: off.}

template failCompress() =
  raise newException(
    ZippyError, "Unexpected error while compressing"
  )

func `<`(a, b: Node): bool = a.weight < b.weight

func quicksort(s: var seq[Node], inl, inr: int) =
  var
    r = inr
    l = inl
  let n = r - l + 1
  if n < 2:
    return
  let p = s[l + 3 * n div 4]
  while l <= r:
    if s[l] < p:
      inc l
      continue
    if s[r] > p:
      dec r
      continue
    if l <= r:
      swap(s[l], s[r])
      inc l
      dec r
  quicksort(s, inl, r)
  quicksort(s, l, inr)

template quicksort(s: var seq[Node]) =
  quicksort(s, 0, s.high)

func newHuffmanTree(
  frequencies: seq[uint16], minCodes: int, maxBitLen: uint8
): (int, seq[uint8], seq[uint16]) =
  # result = (numCodes, symbol -> depth, symbol -> code)

  var
    numCodes = frequencies.len
    nodes = newSeq[Node]()
  for i, freq in frequencies:
    if numCodes > minCodes and freq == 0: # Trim unused codes down to minCodes
      dec numCodes
      continue

    # if freq == 0 and numCodes > 1:
    #   dec numCodes
    #   continue

    let n = Node()
    n.symbol = i.uint16
    n.weight = freq.uint32
    n.leaf = true
    nodes.add(n)

  quicksort(nodes)

  # See https://en.wikipedia.org/wiki/Huffman_coding#Compression

  var q1, q2: Deque[Node]
  for n in nodes:
    q1.addLast(n)

  while q1.len + q2.len > 1:
    var kids: array[2, Node]
    for i in 0 .. 1:
      if q1.len > 0 and q2.len > 0:
        if q1.peekFirst().weight <= q2.peekFirst().weight:
          kids[i] = q1.popFirst()
        else:
          kids[i] = q2.popFirst()
      elif q1.len > 0:
        kids[i] = q1.popFirst()
      else:
        kids[i] = q2.popFirst()
    let internal = Node()
    internal.kids = kids
    internal.weight = kids[0].weight + kids[1].weight
    # debugEcho kids[0].weight, " ", kids[1].weight
    q2.addLast(internal)

  let root = if q2.len > 0: q2.popFirst() else: q1.popFirst()

  # This will have at most 286 symbol depths
  var
    depths = newSeq[uint8](frequencies.len)
    codes = newSeq[uint16](frequencies.len)
  func walk(n: Node, d: uint8, code: uint16) =
    if n == nil or n.weight == 0:
      return
    if d > maxBitLen:
      failCompress()
    if n.leaf:
      depths[n.symbol] = d
      codes[n.symbol] = code
    else:
      walk(n.kids[0], d + 1, (code shl 1))
      walk(n.kids[1], d + 1, (code shl 1) or 1)
  walk(root, 0, 0)

  for i, code in codes:
    if depths[i] != 0:
      debugEcho toBin(code.int, 16), " ", depths[i], " ", i

  var depthCounts: array[16, uint8]
  for d in depths:
    inc depthCounts[d]

  depthCounts[0] = 0

  debugEcho "c depthCounts: ", depthCounts

  var nextCode = newSeq[uint16](maxBitLen + 1)
  for i in 1.uint8 .. maxBitLen:
    nextCode[i] = (nextCode[i - 1] + depthCounts[i - 1]) shl 1

  debugEcho "c nextCode: ", nextCode

  var canonicalCodes = newSeq[uint16](codes.len)
  for i in 0 ..< codes.len:
    if depths[i] != 0:
      canonicalCodes[i] = nextCode[depths[i]]
      debugEcho toBin(canonicalCodes[i].int, 16), " ", i
      inc nextCode[depths[i]]

  (numCodes, depths, canonicalCodes)

func compress*(src: seq[uint8]): seq[uint8] =
  ## Uncompresses src and returns the compressed data seq.

  var b = initBitStream()

  const
    cm = 8.uint8
    cinfo = 7.uint8
    cmf = (cinfo shl 4) or cm
    fcheck = (31 - (cmf.uint32 * 256) mod 31).uint8

  b.addBits(cmf, 8)
  b.addBits(fcheck, 8)

  # No lz77 for now, just Huffman compressed
  let encoded = src

  var
    freqLitLen = newSeq[uint16](286)
    freqDist = newSeq[uint16](30)

  for symbol in encoded:
    inc freqLitLen[symbol]

  # debugEcho "c freqLitLen: ", freqLitLen

  freqLitLen[256] = 1 # Alway 1 end-of-block symbol

  let
    (numCodesLitLen, depthsLitLen, codesLitLen) = newHuffmanTree(freqLitLen, 257, maxCodeLength)
    (numCodesDist, depthsDist, codesDist) = newHuffmanTree(freqDist, 2, maxCodeLength)
    storedCodesLitLen = min(numCodesLitLen, maxLitLenCodes)
    storedCodesDist = min(numCodesDist, maxDistCodes)

  var bitLens = newSeq[uint8](storedCodesLitLen + storedCodesDist)
  for i in 0 ..< storedCodesLitLen:
    bitLens[i] = depthsLitLen[i]
  for i in 0 ..< storedCodesDist:
    bitLens[i + storedCodesLitLen] = depthsDist[i]

  debugEcho "c bitLens: ", bitLens

  var
    bitLensRle: seq[uint8]
    i: int
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
    else:
      bitLensRle.add(bitLens[i])
    inc i

  debugEcho "c bitLensRle: ", bitLensRle

  var
    freqCodeLen = newSeq[uint16](19)
    j: int
  while j < bitLensRle.len:
    inc freqCodeLen[bitLensRle[j]]
    # Skip the number of times codes are repeated
    if bitLensRle[j] >= 16:
      inc j
    inc j

  debugEcho "c freqCodeLen: ", freqCodeLen

  let (_, depthsCodeLen, codesCodeLen) = newHuffmanTree(freqCodeLen, freqCodeLen.len, 7)

  var bitLensCodeLen = newSeq[uint8](freqCodeLen.len)
  for i in 0 ..< bitLensCodeLen.len:
    bitLensCodeLen[i] = depthsCodeLen[codeLengthOrder[i]]

  # debugEcho bitLensCodeLen

  while bitLensCodeLen[bitLensCodeLen.high] == 0 and bitLensCodeLen.len > 4:
    bitLensCodeLen.setLen(bitLensCodeLen.len - 1)

  debugEcho "c bitLensCodeLen: ", bitLensCodeLen

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

  debugEcho "c depthsCodeLen: ", depthsCodeLen

  for i in 0.uint8 ..< hclen + 4:
    b.addBits(bitLensCodeLen[i], 3)

  debugEcho b.bytePos, " ", b.bitPos

  var k: int
  while k < bitLensRle.len:
    let symbol = bitLensRle[k]
    debugEcho "c s: ", symbol, " ", codesCodeLen[symbol], " ", depthsCodeLen[symbol], " ", toBin(codesCodeLen[symbol].int, 8)
    b.addBitsReverse(codesCodeLen[symbol], depthsCodeLen[symbol])
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

  for i in 0 ..< encoded.len:
    let symbol = encoded[i]
    b.addBitsReverse(codesLitLen[symbol], depthsLitLen[symbol])

  if depthsLitLen[256] == 0:
    failCompress()

  b.addBitsReverse(codesLitLen[256], depthsLitLen[256]) # End of block

  b.skipRemainingBitsInCurrentByte()
  b.data.setLen(b.data.len + 1)

  let checksum = cast[array[4, uint8]](adler32(src))
  b.addBits(checkSum[3], 8)
  b.addBits(checkSum[2], 8)
  b.addBits(checkSum[1], 8)
  b.addBits(checkSum[0], 8)

  b.data

template compress*(src: string): string =
  ## Helper for when preferring to work with strings.
  cast[string](compress(cast[seq[uint8]](src)))

# {.pop.}
