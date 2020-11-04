import strformat

const
  minMatchLen = 3

# let text = cast[seq[uint8]]("SAM SAM")
# let text = cast[seq[uint8]]("SAM SAMz")
# let text = cast[seq[uint8]]("SAM SAM SAM SAM")
# let text = cast[seq[uint8]]("SAM SAM SAM SAMz")
# let text = cast[seq[uint8]]("ISAM YAM SAM")
let text = cast[seq[uint8]]("supercalifragilisticexpialidocious supercalifragilisticexpialidocious")

var
  searchBuffer: seq[uint8]

func emitToken(offset, length: int) =
  debugEcho &"<{offset},{length}>"

var
  matchStart, matchOffset, matchLen: int
for i, c in text:

  template emit() =
    if matchLen >= minMatchLen:
      emitToken(matchOffset, matchLen)
    else:
      for j in 0 ..< matchLen:
        echo searchBuffer[matchStart + j].char

  if matchLen > 0:
    if searchBuffer[matchStart + matchLen] == c:
      inc matchLen
      if i == text.high:
        emit()
    else:
      emit()
      matchLen = 0

  if matchLen == 0:
    let index = searchBuffer.find(c)
    if index >= 0:
      matchStart = index
      matchOffset = searchBuffer.len - index
      inc matchLen
      if i == text.high:
        emit()
    else:
      echo c.char

  searchBuffer.add(c)
