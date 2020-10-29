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
  Buffer* = object
    bytePos*, bitPos*: int
    data*: seq[uint8]

func initBuffer*(data: seq[uint8]): Buffer =
  result = Buffer()
  result.data = data

func len*(b: Buffer): int =
  b.data.len

func incBytePos(b: var Buffer) {.inline.} =
  inc b.bytePos
  b.bitPos = 0

template failEndOfBuffer*() =
  raise newException(ZippyError, "Cannot read further, at end of buffer")

template checkBytePos*(b: Buffer) =
  if b.data.len <= b.bytePos:
    failEndOfBuffer()

func read(b: var Buffer, bits: int): uint8 =
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

func readBits*(b: var Buffer, bits: int): uint16 =
  assert bits <= 16

  result = b.read(min(bits, 8)).uint16
  if bits > 8:
    result = result or (b.read(bits - 8).uint16 shl 8)

func skipBits*(b: var Buffer, bits: int) =
  var bitsLeftToSkip = bits
  while bitsLeftToSkip > 0:
    let bitsLeftInByte = 8 - b.bitPos
    if bitsLeftInByte > 0:
      let skipping = min(bitsLeftToSkip, bitsLeftInByte)
      dec(bitsLeftToSkip, skipping)
      inc(b.bitPos, skipping)
      if b.bitPos == 8:
        b.incBytePos()

func peekBits*(b: var Buffer, bits: int): uint16 =
  let
    bytePos = b.bytePos
    bitPos = b.bitPos

  result = b.readBits(bits)

  # Restore these values after reading
  b.bytePos = bytePos
  b.bitPos = bitPos

func skipRemainingBitsInCurrentByte*(b: var Buffer) =
  if b.bitPos > 0:
    b.bitPos = 0
    inc b.bytePos

func readBytes*(b: var Buffer, dst: pointer, len: int) =
  if b.bytePos + len > b.data.len:
    failEndOfBuffer()

  copyMem(dst, b.data[b.bytePos].addr, len)
  b.skipBits(len * 8)
