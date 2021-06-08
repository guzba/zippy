import zippyerror

type
  BitStream* = object
    pos*: int
    data*: seq[uint8]
    # Reading
    bitCount*: int
    bitBuf*: uint64
    # Writing
    bitPos: uint

when defined(release):
  {.push checks: off.}

template failEndOfBuffer*() =
  raise newException(ZippyError, "Cannot read further, at end of buffer")

func initBitStream*(data: seq[uint8], pos = 0): BitStream =
  result.data = data
  result.pos = pos

func fillBitBuf*(b: var BitStream) {.inline.} =
  while b.bitCount <= 56:
    if b.pos >= b.data.len:
      break
    b.bitBuf = b.bitBuf or (b.data[b.pos].uint64 shl b.bitCount)
    inc b.pos
    b.bitCount += 8

func readBits*(b: var BitStream, bits: uint): uint16 =
  assert bits <= 16

  if b.bitCount < 16:
    b.fillBitBuf()

  result = (b.bitBuf and ((1.uint32 shl bits) - 1)).uint16
  b.bitBuf = b.bitBuf shr bits
  b.bitCount -= bits.int # bitCount can go negative if we've read past the end

func readBits*(b: var BitStream, bits: int): uint16 {.inline.} =
  readBits(b, bits.uint) # TODO remove

func readBytes*(b: var BitStream, dst: var seq[uint8], start, len: int) =
  assert b.bitPos == 0
  assert b.bitCount mod 8 == 0

  let posOffset = b.bitCount div 8

  if b.pos - posOffset + len > b.data.len:
    failEndOfBuffer()

  when nimvm:
    for i in 0 ..< len:
      dst[start + i] = b.data[b.pos - posOffset + i]
  else:
    copyMem(dst[start].addr, b.data[b.pos - posOffset].addr, len)

  b.pos = b.pos - posOffset + len
  b.bitCount = 0
  b.bitBuf = 0

func incPos(b: var BitStream, bits: uint) {.inline.} =
  # Used when writing
  b.pos += ((bits + b.bitPos) shr 3).int
  b.bitPos = (bits + b.bitPos) and 7

func skipRemainingBitsInCurrentByte*(b: var BitStream) =
  # If writing
  if b.bitPos > 0:
    b.incPos(8 - b.bitPos)

  # If reading
  let mod8 = b.bitCount mod 8
  if mod8 != 0:
    b.bitCount -= mod8
    b.bitBuf = b.bitBuf shr mod8

func addBytes*(b: var BitStream, src: seq[uint8], start, len: int) =
  assert b.bitPos == 0

  if b.pos + len > b.data.len:
    b.data.setLen(b.pos + len)

  when nimvm:
    for i in 0 ..< len:
      b.data[b.pos + i] = src[start + i]
  else:
    copyMem(b.data[b.pos].addr, src[start].unsafeAddr, len)

  b.incPos(len.uint * 8)

func addBits*(b: var BitStream, value: uint16, bits: uint) =
  assert bits <= 16

  var bitsRemaining = bits

  template add() =
    let
      bitsLeftInByte = 8 - b.bitPos
      bitsAdded = min(bitsLeftInByte, bitsRemaining) # Can be 0 which is fine
      bitsToAdd = (value shr (bits - bitsRemaining)) shl b.bitPos
    b.data[b.pos] = b.data[b.pos] or (bitsToAdd and 255).uint8
    bitsRemaining -= bitsAdded
    b.incPos(bitsAdded)

  # 16 bits cannot spread out across more than 3 bytes
  add()
  add()
  if bitsRemaining > 0:
    add()

when defined(release):
  {.pop.}
