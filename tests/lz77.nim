import strformat, strutils, fidget/opengl/perf

const
  minMatchLen = 3

  windowSize = 1 shl 16
  maxMatchLen = 258
  goodMatchLen = 32
  maxChainLen = 1024

  hashBits = 16
  hashSize = 1 shl hashBits
  hashMask = hashSize - 1
  hashShift = (hashBits + minMatchLen - 1) div minMatchLen

var
  totalMatch: int

proc lz77Encode2(src: seq[uint8]): seq[uint16] =
  echo windowSize

  # assert windowSize <= maxWindowSize
  assert (windowSize and (windowSize - 1)) == 0
  assert (hashSize and hashMask) == 0

  proc addLookBack(result: var seq[uint16], offset, length: int) =
    # debugEcho &"lookback <{offset},{length}>"
    result.add(uint16.high)
    result.add(offset.uint16)
    result.add(length.uint16)

    inc(totalMatch, length)

  if src.len <= minMatchLen:
    for i in 0 ..< src.len:
      result.add(src[i])
    return

  var
    pos, windowPos, hash: int
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
    if pos + minMatchLen > src.len:
      result.add(src[pos])
      inc pos
      continue

    updateHash(src[pos + minMatchLen - 1])
    updateChain()

    windowPos = pos and (windowSize - 1)

    var
      hashPos = chain[pos]
      stop = min(src.len, pos + maxMatchLen)
      chainLen, longestMatchOffset, longestMatchLen: int
    while true:
      if chainLen >= maxChainLen:
        break
      inc chainLen


      # let offset = pos - hashPos
      # if offset == 0:
      #   break



      var matchLen: int
      for i in 0 ..< stop - pos:
        if src[hashPos + i] != src[pos + i]:
          break
        inc matchLen

      if matchLen > longestMatchLen:
        longestMatchLen = matchLen
        longestMatchOffset = offset

      if longestMatchLen >= goodMatchLen:
        break

      let nextPos = chain[hashPos]
      if hashPos == nextPos:
        break
      hashPos = nextPos

    if longestMatchLen > minMatchLen:
      addLookBack(result, longestMatchOffset, longestMatchLen)
      for i in 1 ..< longestMatchLen:
        inc pos
        windowPos = pos and (windowSize - 1)
        if pos + minMatchLen < src.len:
          updateHash(src[pos + minMatchLen - 1])
          updateChain()
    else:
      result.add(src[pos])
    inc pos

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
      # debugEcho &"lookback <{offset},{length}>"
      inc(ip, 3)

      var copyPos = op - offset
      if op + length > result.len:
        result.setLen(max(result.len * 2, result.len + length))
      for j in 0 ..< length:
        result[op + j] = result[copyPos + j]
      inc(op, length)
    else:
      result[op] = encoded[ip].uint8
      inc ip
      inc op

  result.setLen(op)

proc lz77Encode(src: seq[uint8]): seq[uint16] =
  result.setLen(src.len div 2)

  var pos, windowStart, matchStart, matchOffset, matchLen: int
  for i, c in src:
    if pos + 3 >= result.len:
      result.setLen(result.len * 2)

    template emit() =
      if matchLen >= minMatchLen:
        # debugEcho &"<{matchOffset},{matchLen}>"
        result[pos] = uint16.high
        result[pos + 1] = matchOffset.uint16
        result[pos + 2] = matchLen.uint16
        inc(pos, 3)
        inc(totalMatch, matchLen)
      else:
        for j in 0 ..< matchLen:
          # debugEcho src[windowStart + matchStart + j].char
          result[pos] = src[windowStart + matchStart + j]
          inc pos
      matchLen = 0

    func find(
      src: seq[uint8], value: uint8, start, stop: int
    ): int {.inline.} =
      result = -1
      for j in start ..< stop:
        if src[j] == value:
          result = j - start
          break

    if matchLen > 0:
      if src[windowStart + matchStart + matchLen] == c:
        inc matchLen
        if matchLen == maxMatchLen or i == src.high:
          emit()
          # We've consumed this c so don't hit the matchLen == 0 block
          continue
      else:
        emit()

    if matchLen == 0:
      windowStart = max(i - windowSize, 0)
      let index = src.find(c, windowStart, i)
      if index >= 0:
        matchStart = index
        matchOffset = i - windowStart - index
        inc matchLen
        if i == src.high:
          emit()
      else:
        # debugEcho c.char
        result[pos] = c
        inc pos

  result.setLen(pos)

proc lz77Decode(encoded: seq[uint16]): seq[uint8] =
  result.setLen(encoded.len)

  var ip, op: int
  while ip < encoded.len:
    if op >= result.len:
      result.setLen(result.len * 2)

    if encoded[ip] == uint16.high:
      let
        offset = encoded[ip + 1].int
        length = encoded[ip + 2].int
      # debugEcho &"<{offset},{length}>"
      inc(ip, 3)

      var copyPos = op - offset
      if op + length > result.len:
        result.setLen(max(result.len * 2, result.len + length))
      for j in 0 ..< length:
        result[op + j] = result[copyPos + j]
      inc(op, length)
    else:
      # debugEcho encoded[ip].char
      result[op] = encoded[ip].uint8
      inc ip
      inc op

  result.setLen(op)

const files = [
  # "randtest1.gold",
  # "randtest2.gold",
  # "randtest3.gold",
  "rfctest1.gold",
  # "rfctest2.gold",
  # "rfctest3.gold",
  # # "tor-list.gold",
  # "zerotest1.gold",
  # "zerotest2.gold",
  # "zerotest3.gold",
  # "empty.gold",
  # "alice29.txt",
  # "asyoulik.txt",
  # "fireworks.jpg",
  # "geo.protodata",
  # "html",
  # "html_x_4",
  # "kppkn.gtb",
  # "lcet10.txt",
  # "paper-100k.pdf",
  # "plrabn12.txt",
  # "urls.10K"
]

# timeIt "lz77":
#   for i in 0 ..< 1:
#     for file in files:
#       let
#         original = cast[seq[uint8]](readFile(&"tests/data/{file}"))
#         encoded = lz77Encode(original)
#         decoded = lz77Decode(encoded)
#       echo &"{file} original: {original.len} encoded: {encoded.len}"
#       echo totalMatch
#       doAssert original == decoded

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
      if original != decoded:
        for i in 0 ..< original.len:
          if original[i] != decoded[i]:
            echo "bad @ ", i, " ", original[i], " ", decoded[i]
            break

# let
#   original = cast[seq[uint8]]("zSAM SAM SAMz")
#   encoded = lz77Encode2(original)
# echo &"original: {original.len} encoded: {encoded.len}"
# echo totalMatch
# echo encoded
# echo lz77Decode2(original, encoded)
# doAssert original == lz77Decode2(original, encoded)
