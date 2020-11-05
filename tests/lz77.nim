import strformat

const
  # windowSize = 16
  minMatchLen = 3

func lz77Encode(src: seq[uint8]): seq[uint16] =
  var matchStart, matchOffset, matchLen: int
  for i, c in src:
    template emit() =
      if matchLen >= minMatchLen:
        # debugEcho &"<{matchOffset},{matchLen}>"
        result.add([
          uint16.high,
          matchOffset.uint16,
          matchLen.uint16
        ])
      else:
        for j in 0 ..< matchLen:
          # debugEcho src[0 ..< i][matchStart + j].char
          result.add(src[0 ..< i][matchStart + j])

    if matchLen > 0:
      if src[0 ..< i][matchStart + matchLen] == c:
        inc matchLen
        if i == src.high:
          emit()
      else:
        emit()
        matchLen = 0

    if matchLen == 0:
      let index = src[0 ..< i].find(c)
      if index >= 0:
        matchStart = index
        matchOffset = i - index
        inc matchLen
        if i == src.high:
          emit()
      else:
        # debugEcho c.char
        result.add(c)


func lz77Decode(encoded: seq[uint16]): seq[uint8] =
  var i: int
  while i < encoded.len:
    if encoded[i] == uint16.high:
      let
        offset = encoded[i + 1].int
        length = encoded[i + 2].int
      # debugEcho &"<{offset},{length}>"
      inc(i, 3)

      var
        pos = result.len
        copyPos = result.len - offset
      result.setLen(result.len + length)
      for j in 0 ..< length:
        result[pos + j] = result[copyPos + j]
    else:
      # debugEcho encoded[i].char
      result.add(encoded[i].uint8)
      inc i



# let text = cast[seq[uint8]]("SAM SAM")
# let text = cast[seq[uint8]]("SAM SAMz")
# let text = cast[seq[uint8]]("SAM SAM SAM SAM")
# let text = cast[seq[uint8]]("SAM SAM SAM SAMz")
# let text = cast[seq[uint8]]("ISAM YAM SAM")
let text = cast[seq[uint8]]("supercalifragilisticexpialidocious supercalifragilisticexpialidocious")

let encoded = lz77Encode(text)

let decoded = lz77Decode(encoded)

assert decoded == text
