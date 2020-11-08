import zippyerror

const
  masks = [
    0b00000000.uint8,
    0b00000001,
    0b00000011,
    0b00000111,
    0b00001111,
    0b00011111,
    0b00111111,
    0b01111111,
    0b11111111,
  ]

type
  BitStream* = object
    bytePos*, bitPos*: int
    data*: seq[uint8]

{.push checks: off.}

template failEndOfBuffer*() =
  raise newException(ZippyError, "Cannot read further, at end of buffer")

func initBitStream*(data: seq[uint8]): BitStream =
  result.data = data

func len*(b: BitStream): int =
  b.data.len

func incPos(b: var BitStream) {.inline.} =
  inc b.bytePos
  b.bitPos = 0

func movePos(b: var BitStream, bits: int) {.inline.} =
  assert b.bitPos + bits <= 8
  inc(b.bitPos, bits)
  inc(b.bytePos, b.bitPos shr 3)
  b.bitPos = b.bitPos and 7

template checkBytePos*(b: BitStream) =
  if b.data.len <= b.bytePos:
    failEndOfBuffer()

func read(b: var BitStream, bits: int): uint8 =
  assert bits <= 8

  b.checkBytePos()

  result = b.data[b.bytePos]
  result = result shr b.bitPos

  let bitsLeftInByte = 8 - b.bitPos
  if bitsLeftInByte >= bits:
    b.movePos(bits)
    result = result and masks[bits]
  else:
    let bitsNeeded = bits - bitsLeftInByte
    b.incPos()
    result = result or (b.read(bitsNeeded) shl bitsLeftInByte)

func readBits*(b: var BitStream, bits: int): uint16 =
  assert bits <= 16

  result = b.read(min(bits, 8)).uint16
  if bits > 8:
    result = result or (b.read(bits - 8).uint16 shl 8)

func skipBits*(b: var BitStream, bits: int) =
  var bitsLeftToSkip = bits
  while bitsLeftToSkip > 0:
    let bitsLeftInByte = 8 - b.bitPos
    if bitsLeftInByte > 0:
      let skipping = min(bitsLeftToSkip, bitsLeftInByte)
      dec(bitsLeftToSkip, skipping)
      b.movePos(skipping)

func peekBits*(b: var BitStream, bits: int): uint16 =
  let
    bytePos = b.bytePos
    bitPos = b.bitPos

  result = b.readBits(bits)

  # Restore these values after reading
  b.bytePos = bytePos
  b.bitPos = bitPos

func skipRemainingBitsInCurrentByte*(b: var BitStream) =
  if b.bitPos > 0:
    b.incPos()

func readBytes*(b: var BitStream, dst: pointer, len: int) =
  assert b.bitPos == 0

  if b.bytePos + len > b.data.len:
    failEndOfBuffer()

  copyMem(dst, b.data[b.bytePos].addr, len)
  b.skipBits(len * 8)

func addBytes*(b: var BitStream, src: pointer, len: int) =
  assert b.bitPos == 0

  if b.bytePos + len > b.data.len:
    b.data.setLen(b.bytePos + len)

  copyMem(b.data[b.bytePos].addr, src, len)
  b.skipBits(len * 8)

func addBit*(b: var BitStream, bit: uint8) =
  b.data[b.bytePos] = b.data[b.bytePos] or (bit shl b.bitPos)
  b.movePos(1)

func addBits*(b: var BitStream, value: uint16, bits: int) =
  assert bits <= 16

  var bitsRemaining = bits
  for i in 0 ..< 3: # 16 bits cannot spread out across more than 3 bytes
    let
      bitsLeftInByte = 8 - b.bitPos
      bitsAdded = min(bitsLeftInByte, bitsRemaining) # Can be 0 which is fine
      bitsToAdd = ((value shr (bits - bitsRemaining)) shl b.bitPos).uint8
    b.data[b.bytePos] = b.data[b.bytePos] or bitsToAdd
    dec(bitsRemaining, bitsAdded)
    b.movePos(bitsAdded)

{.pop.}
