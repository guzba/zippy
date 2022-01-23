import internal, common

type
  BitStream* = object
    pos*: int
    # Writing
    dst*: string
    bitPos: uint

  BitStreamReader* = object
    src*: ptr UncheckedArray[uint8]
    len*, pos*: int
    bitBuffer*: uint64
    bitsBuffered*: int

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

proc incPos(b: var BitStream, bits: uint) {.inline.} =
  # Used when writing
  b.pos += ((bits + b.bitPos) shr 3).int
  b.bitPos = (bits + b.bitPos) and 7

proc skipRemainingBitsInCurrentByte*(b: var BitStream) =
  # If writing
  if b.bitPos > 0.uint:
    b.incPos(8.uint - b.bitPos)

proc addBytes*(b: var BitStream, src: string, start, len: int) =
  assert b.bitPos == 0

  if b.pos + len > b.dst.len:
    b.dst.setLen(b.pos + len)

  copyMem(b.dst[b.pos].addr, src[start].unsafeAddr, len)

  b.incPos(len.uint * 8)

proc addBits*(b: var BitStream, value: uint32, bits: uint32) {.inline.} =
  assert bits <= 32

  if b.pos + 8 > b.dst.len:
    # Make sure we have room to read64
    b.dst.setLen(max(b.dst.len * 2, 64))

  let value = value.uint64 and ((1.uint64 shl bits) - 1)

  write64(b.dst, b.pos, read64(b.dst, b.pos) or (value.uint64 shl b.bitPos))

  b.incPos(bits)

when defined(release):
  {.pop.}
