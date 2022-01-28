import fidget/opengl/perf, std/strformat, std/strutils

const
  minMatchLen = 3

  windowSize = 1 shl 15
  maxMatchLen = 258
  maxChainLen = 32
  goodMatchLen = 32

  hashBits = 16
  hashSize = 1 shl hashBits
  hashMask = hashSize - 1
  hashShift = (hashBits + minMatchLen - 1) div minMatchLen

var
  totalMatch: int

proc lz77Encode2(src: seq[uint8]): seq[uint16] =
  # assert windowSize <= maxWindowSize
  assert (windowSize and (windowSize - 1)) == 0
  assert (hashSize and hashMask) == 0

  var op: int

  template addLiteral(length: int) =
    # debugEcho &"literal <{length}>"
    result[op] = length.uint16
    inc op

  template addLookBack(offset, length: int) =
    # debugEcho &"lookback <{offset},{length}>"
    result[op] = uint16.high
    result[op + 1] = offset.uint16
    result[op + 2] = length.uint16
    inc(op, 3)

    inc(totalMatch, length)

  if src.len <= minMatchLen:
    result.setLen(1)
    addLiteral(src.len)
    return

  result.setLen(src.len div 2)

  var
    pos, literalLen: int
    windowPos, hash: uint16
    head = newSeq[uint16](hashSize)    # hash -> pos
    chain = newSeq[uint16](windowSize) # pos a -> pos b

  template updateHash(value: uint8) =
    hash = ((hash shl hashShift) xor value) and hashMask

  template updateChain() =
    chain[windowPos] = head[hash]
    head[hash] = windowPos

  for i in 0 ..< minMatchLen - 1:
    updateHash(src[i])

  while pos < src.len:
    if op + minMatchLen > result.len:
      result.setLen(result.len * 2)

    if pos + minMatchLen > src.len:
      addLiteral(literalLen + src.len - pos)
      break

    windowPos = (pos and (windowSize - 1)).uint16

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

      var offset: int
      if hashPos <= windowPos:
        offset = (windowPos - hashPos).int
      else:
        offset = (windowPos - hashPos + windowSize).int

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
      if literalLen > 0:
        addLiteral(literalLen)
        literalLen = 0

      addLookBack(longestMatchOffset, longestMatchLen)
      for i in 1 ..< longestMatchLen:
        inc pos
        windowPos = (pos and (windowSize - 1)).uint16
        if pos + minMatchLen < src.len:
          updateHash(src[pos + minMatchLen - 1])
          updateChain()
    else:
      inc literalLen
      if literalLen == uint16.high.int shr 1:
        addLiteral(literalLen)
        literalLen = 0
    inc pos

  result.setLen(op)

proc lz77Decode2(src: seq[uint8], encoded: seq[uint16]): seq[uint8] =
  result.setLen(encoded.len)

  var ip, op: int
  while ip < encoded.len:
    if op >= result.len:
      result.setLen(result.len * 2)

    if encoded[ip] == uint16.high:
      let
        offset = encoded[ip + 1].int
        length = encoded[ip + 2].int
      inc(ip, 3)

      var copyPos = op - offset
      if op + length > result.len:
        result.setLen(max(result.len * 2, result.len + length))
      for j in 0 ..< length:
        result[op + j] = result[copyPos + j]
      inc(op, length)
    else:
      let length = encoded[ip].int
      inc ip

      if op + length > result.len:
        result.setLen(max(result.len * 2, result.len + length))
      for j in 0 ..< length:
        result[op + j] = src[op + j]
      inc(op, length)

  result.setLen(op)

const files = [
  "randtest1.gold",
  "randtest2.gold",
  "randtest3.gold",
  "rfctest1.gold",
  "rfctest2.gold",
  "rfctest3.gold",
  "tor-list.gold",
  "zerotest1.gold",
  "zerotest2.gold",
  "zerotest3.gold",
  "empty.gold",
  "alice29.txt",
  "asyoulik.txt",
  "fireworks.jpg",
  "geo.protodata",
  "html",
  "html_x_4",
  "kppkn.gtb",
  "lcet10.txt",
  "paper-100k.pdf",
  "plrabn12.txt",
  "urls.10K"
]

timeIt "lz77_2":
  for i in 0 ..< 1:
    for file in files:
      let
        original = cast[seq[uint8]](readFile(&"tests/data/{file}"))
        encoded = lz77Encode2(original)
        decoded = lz77Decode2(original, encoded)
      echo &"{file} original: {original.len} encoded: {encoded.len}"
      echo "totalMatch: ", totalMatch
      echo "decoded: ", decoded.len
      assert original == decoded
      # if original != decoded:
      #   for i in 0 ..< original.len:
      #     if original[i] != decoded[i]:
      #       echo "bad @ ", i, " ", original[i], " ", decoded[i]
      #       break

    # let
    #   original = cast[seq[uint8]]("zSAM SAM SAM a SAM SAM SAMz")
    #   encoded = lz77Encode2(original)
    # echo &"original: {original.len} encoded: {encoded.len}"
    # echo totalMatch
    # echo encoded
    # echo cast[string](lz77Decode2(original, encoded))
    # doAssert original == lz77Decode2(original, encoded)
