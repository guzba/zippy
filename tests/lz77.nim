import strformat, fidget/opengl/perf

const
  windowSize = 32
  minMatchLen = 3
  maxMatchLen = 258

var
  totalMatch: int

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
  # "tor-list.gold",
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

timeIt "lz77":
  for i in 0 ..< 1:
    for file in files:
      let
        original = cast[seq[uint8]](readFile(&"tests/data/{file}"))
        encoded = lz77Encode(original)
        decoded = lz77Decode(encoded)
      echo &"{file} original: {original.len} encoded: {encoded.len}"
      echo totalMatch
      doAssert original == decoded
