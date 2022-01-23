import internal, common

type
  BitStreamReader* = object
    src*: ptr UncheckedArray[uint8]
    len*, pos*: int
    bitBuffer*: uint64
    bitsBuffered*: int

  BitStreamWriter* = object
    dst*: string
    pos*, bitPos*: int

template failEndOfBuffer*() =
  raise newException(ZippyError, "Cannot read further, at end of buffer")

when defined(release):
  {.push checks: off.}

proc fillBitBuffer*(b: var BitStreamReader) {.inline.} =
  while b.bitsBuffered <= 56:
    if b.pos >= b.len:
      break
    b.bitBuffer = b.bitBuffer or (b.src[b.pos].uint64 shl b.bitsBuffered)
    inc b.pos
    b.bitsBuffered += 8

proc readBits*(b: var BitStreamReader, bits: int): uint16 =
  assert bits >= 0 and bits <= 16

  if bits == 0:
    return

  if b.bitsBuffered < 16:
    b.fillBitBuffer()

  result = (b.bitBuffer and ((1.uint64 shl bits) - 1)).uint16
  b.bitBuffer = b.bitBuffer shr bits
  b.bitsBuffered -= bits # bitCount can go negative if we've read past the end

proc readBytes*(b: var BitStreamReader, dst: pointer, len: int) =
  if b.bitsBuffered mod 8 != 0:
    raise newException(ZippyError, "Must be at a byte boundary")

  let offset = b.bitsBuffered div 8
  if b.pos - offset + len > b.len:
    failEndOfBuffer()

  copyMem(dst, b.src[b.pos - offset].addr, len)

  b.pos = b.pos - offset + len
  b.bitsBuffered = 0
  b.bitBuffer = 0

proc skipRemainingBitsInCurrentByte*(b: var BitStreamReader) =
  let mod8 = b.bitsBuffered mod 8
  if mod8 != 0:
    b.bitsBuffered -= mod8
    b.bitBuffer = b.bitBuffer shr mod8

func incPos(b: var BitStreamWriter, bits: int) {.inline.} =
  b.pos += cast[int](cast[uint](bits + b.bitPos) shr 3)
  b.bitPos = cast[int](cast[uint](bits + b.bitPos) and 7)
  # does this matter^?

proc addBytes*(
  b: var BitStreamWriter,
  src: ptr UncheckedArray[uint8],
  start, len: int
) =
  assert b.bitPos == 0

  if b.pos + len > b.dst.len:
    b.dst.setLen(b.pos + len)

  copyMem(b.dst[b.pos].addr, src[start].unsafeAddr, len)

  b.incPos(len * 8)

proc addBits*(b: var BitStreamWriter, value: uint32, bitLen: int) {.inline.} =
  assert bitLen <= 32

  if b.pos + 8 > b.dst.len:
    # Make sure we have room to read64
    b.dst.setLen(max(b.dst.len * 2, 64))

  let value = value.uint64 and ((1.uint64 shl bitLen) - 1)

  write64(b.dst, b.pos, read64(b.dst, b.pos) or (value.uint64 shl b.bitPos))

  b.incPos(bitLen)

proc skipRemainingBitsInCurrentByte*(b: var BitStreamWriter) =
  if b.bitPos > 0:
    b.incPos(8 - b.bitPos)

when defined(release):
  {.pop.}
