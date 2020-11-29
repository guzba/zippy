import zippyerror

type
  BitStream* = object
    bytePos*, bitPos*: int
    data*: seq[uint8]

when defined(release):
  {.push checks: off.}

template failEndOfBuffer*() =
  raise newException(ZippyError, "Cannot read further, at end of buffer")

func initBitStream*(data: seq[uint8]): BitStream =
  result.data = data

func len*(b: BitStream): int =
  b.data.len

func movePos(b: var BitStream, bits: int) {.inline.} =
  assert b.bitPos + bits <= 8
  inc(b.bitPos, bits)
  inc(b.bytePos, b.bitPos shr 3)
  b.bitPos = b.bitPos and 7

template checkBytePos*(b: BitStream) =
  if b.bytePos >= b.data.len:
    failEndOfBuffer()

func readBits*(b: var BitStream, bits: int): uint16 =
  b.checkBytePos()

  assert bits <= 16

  result = b.data[b.bytePos].uint16 shr b.bitPos
  let numBits = 8 - b.bitPos

  # Fill result up
  if b.bytePos + 1 < b.data.len:
    result = result or (b.data[b.bytePos + 1].uint16 shl numBits)
  if b.bytePos + 2 < b.data.len:
    result = result or (b.data[b.bytePos + 2].uint16 shl (numBits + 8))

  # Mask out any bits past requested bit length
  result = result and ((1 shl bits) - 1).uint16

  b.bytePos += (bits + b.bitPos) shr 3
  b.bitPos = (bits + b.bitPos) and 7

func skipBits*(b: var BitStream, bits: int) =
  var bitsLeftToSkip = bits
  while bitsLeftToSkip > 0:
    let
      bitsLeftInByte = 8 - b.bitPos
      skipping = min(bitsLeftToSkip, bitsLeftInByte)
    dec(bitsLeftToSkip, skipping)
    b.movePos(skipping)

func skipRemainingBitsInCurrentByte*(b: var BitStream) =
  if b.bitPos > 0:
    inc b.bytePos
    b.bitPos = 0

func readBytes*(b: var BitStream, dst: var seq[uint8], start, len: int) =
  assert b.bitPos == 0

  if b.bytePos + len > b.data.len:
    failEndOfBuffer()

  when nimvm:
    for i in 0 ..< len:
      dst[start + i] = b.data[b.bytePos + i]
  else:
    copyMem(dst[start].addr, b.data[b.bytePos].addr, len)

  b.skipBits(len * 8)

func addBytes*(b: var BitStream, src: seq[uint8], start, len: int) =
  assert b.bitPos == 0

  if b.bytePos + len > b.data.len:
    b.data.setLen(b.bytePos + len)

  when nimvm:
    for i in 0 ..< len:
      b.data[b.bytePos + i] = src[start + i]
  else:
    copyMem(b.data[b.bytePos].addr, src[start].unsafeAddr, len)

  b.skipBits(len * 8)

func addBit*(b: var BitStream, bit: uint8) =
  b.data[b.bytePos] = b.data[b.bytePos] or (bit shl b.bitPos)
  b.movePos(1)

func addBits*(b: var BitStream, value: uint16, bits: int) =
  assert bits <= 16

  var bitsRemaining = bits

  template add() =
    let
      bitsLeftInByte = 8 - b.bitPos
      bitsAdded = min(bitsLeftInByte, bitsRemaining) # Can be 0 which is fine
      bitsToAdd = (value shr (bits - bitsRemaining)) shl b.bitPos
    b.data[b.bytePos] = b.data[b.bytePos] or (bitsToAdd and 255).uint8
    dec(bitsRemaining, bitsAdded)
    b.movePos(bitsAdded)

  # 16 bits cannot spread out across more than 3 bytes
  add()
  add()
  if bitsRemaining > 0:
    add()

when defined(release):
  {.pop.}
