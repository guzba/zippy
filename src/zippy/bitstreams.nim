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

func initBitStream*(data: seq[uint8]): BitStream =
  result.data = data

func initBitStream*(): BitStream =
  result.data.setLen(1)

func len*(b: BitStream): int =
  b.data.len

func incBytePos(b: var BitStream) {.inline.} =
  inc b.bytePos
  b.bitPos = 0

template failEndOfBuffer*() =
  raise newException(ZippyError, "Cannot read further, at end of buffer")

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
    inc(b.bitPos, bits)
    if b.bitPos == 8:
      b.incBytePos()
    result = result and masks[bits]
  else:
    let bitsNeeded = bits - bitsLeftInByte
    b.incBytePos()
    result = result or (b.read(bitsNeeded) shl bitsLeftInByte)

func readBits*(b: var BitStream, bits: int): uint16 =
  assert bits <= 16

  result = b.read(min(bits, 8)).uint16
  if bits > 8:
    result = result or (b.read(bits - 8).uint16 shl 8)

func skipBits*(b: var BitStream, bits: int) =
  if b.bitPos == 8 and bits > 0:
    b.incBytePos()

  var bitsLeftToSkip = bits
  while bitsLeftToSkip > 0:
    let bitsLeftInByte = 8 - b.bitPos
    if bitsLeftInByte > 0:
      let skipping = min(bitsLeftToSkip, bitsLeftInByte)
      dec(bitsLeftToSkip, skipping)
      inc(b.bitPos, skipping)
      if b.bitPos == 8:
        b.incBytePos()

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
    b.bitPos = 0
    inc b.bytePos

func readBytes*(b: var BitStream, dst: pointer, len: int) =
  if b.bytePos + len > b.data.len:
    failEndOfBuffer()

  copyMem(dst, b.data[b.bytePos].addr, len)
  b.skipBits(len * 8)

func addBit*(b: var BitStream, bit: uint8) =
  if b.bitPos == 8:
    b.incBytePos()

  b.data[b.bytePos] = b.data[b.bytePos] or (bit shl b.bitPos)
  inc b.bitPos

func addBits*(b: var BitStream, value: uint16, bits: int) =
  assert bits <= 16

  var bitsRemaining = bits
  for i in 0 ..< 3: # 16 bits cannot spread out across more than 3 bytes
    if bitsRemaining == 0:
      break
    if b.bitPos == 8:
      b.incBytePos()
    let
      bitsLeftInByte = 8 - b.bitPos
      bitsAdded = min(bitsLeftInByte, bitsRemaining)
      bitsToAdd = ((value shr (bits - bitsRemaining)) shl b.bitPos).uint8
    b.data[b.bytePos] = b.data[b.bytePos] or bitsToAdd
    inc(b.bitPos, bitsAdded)
    dec(bitsRemaining, bitsAdded)
