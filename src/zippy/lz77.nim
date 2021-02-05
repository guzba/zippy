import common

const
  hashBits = 17
  hashSize = 1 shl hashBits

func lz77Encode*(
  src: seq[uint8], config: CompressionConfig
): (seq[uint16], seq[int], seq[int], int) =
  var
    encoded = newSeq[uint16](src.len div 2)
    freqLitLen = newSeq[int](286)
    freqDist = newSeq[int](baseDistances.len)
    op, literalsTotal: int

  freqLitLen[256] = 1 # Alway 1 end-of-block symbol

  template addLiteral(start, length: int) =
    if op + 1 > encoded.len:
      encoded.setLen(encoded.len * 2)

    for i in 0 ..< length:
      inc freqLitLen[src[start + i]]

    encoded[op] = length.uint16
    inc op
    inc(literalsTotal, length)

  template addCopy(offset, length: int) =
    if op + 3 > encoded.len:
      encoded.setLen(encoded.len * 2)

    let
      lengthIndex = baseLengthIndices[length - baseMatchLen].uint16
      distIndex = distanceCodeIndex((offset - 1).uint16)
    inc freqLitLen[lengthIndex + firstLengthCodeIndex]
    inc freqDist[distIndex]

    # The length and dist indices are packed into this value with the highest
    # bit set as a flag to indicate this starts a run.
    encoded[op] = ((lengthIndex shl 8) or distIndex) or (1 shl 15)
    encoded[op + 1] = offset.uint16
    encoded[op + 2] = length.uint16
    inc(op, 3)

  if minMatchLen >= src.len:
    for c in src:
      inc freqLitLen[c]
    encoded.setLen(1)
    addLiteral(0, src.len)
    return (encoded, freqLitLen, freqDist, literalsTotal)

  encoded.setLen(4096)

  var
    pos, literalLen: int
    hash: uint32
    windowPos: uint16
    head = newSeq[uint16](hashSize)       # hash -> pos
    chain = newSeq[uint16](maxWindowSize) # pos a -> pos b

  template hash4(start: int): uint32 =
    (read32(src, start) * 0x1e35a7bd) shr (32 - hashBits)

  template updateChain() =
    chain[windowPos] = head[hash]
    head[hash] = windowPos

  while pos < src.len:
    if pos + minMatchLen >= src.len:
      addLiteral(pos - literalLen, src.len - pos + literalLen)
      break

    windowPos = (pos and (maxWindowSize - 1)).uint16

    hash = hash4(pos)
    updateChain()

    var
      hashPos = chain[windowPos]
      limit = min(src.len, pos + maxMatchLen)
      tries = config.chain
      prevOffset, longestMatchOffset, longestMatchLen: int
    while tries > 0 and hashPos != 0:
      dec tries

      var offset: int
      if hashPos <= windowPos:
        offset = (windowPos - hashPos).int
      else:
        offset = (windowPos - hashPos + maxWindowSize).int

      if offset <= 0 or offset < prevOffset:
        break

      prevOffset = offset

      let matchLen = findMatchLength(src, pos - offset, pos, limit)
      if matchLen > longestMatchLen:
        if matchLen >= config.good:
          tries = tries shr 2
        longestMatchLen = matchLen
        longestMatchOffset = offset

      if longestMatchLen >= config.nice or hashPos == chain[hashPos]:
        break

      hashPos = chain[hashPos]

    if longestMatchLen > minMatchLen:
      if literalLen > 0:
        addLiteral(pos - literalLen, literalLen)
        literalLen = 0

      addCopy(longestMatchOffset, longestMatchLen)
      for i in 1 ..< longestMatchLen:
        inc pos
        windowPos = (pos and (maxWindowSize - 1)).uint16
        if pos + minMatchLen < src.len:
          hash = hash4(pos)
          updateChain()
    else:
      inc literalLen
      if literalLen == maxLiteralLength:
        addLiteral(pos + 1 - literalLen, literalLen)
        literalLen = 0
    inc pos

  encoded.setLen(op)
  (encoded, freqLitLen, freqDist, literalsTotal)
