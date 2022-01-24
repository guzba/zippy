import common, internal

type
  BitStreamReader* = object
    src*: ptr UncheckedArray[uint8]
    len*, pos*: int
    bitBuffer*: uint64
    bitsBuffered*: int

  BitStreamWriter* = object
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

proc readBits*(
  b: var BitStreamReader,
  bits: int,
  fillBitBuffer: static[bool] = true
): uint16 {.inline.} =
  assert bits >= 0 and bits <= 16

  when fillBitBuffer:
    b.fillBitBuffer()

  result = (b.bitBuffer and ((1.uint64 shl bits) - 1)).uint16
  b.bitBuffer = b.bitBuffer shr bits
  b.bitsBuffered -= bits # Can go negative if we've read past the end

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
  b.pos += (bits + b.bitPos) shr 3
  b.bitPos = (bits + b.bitPos) and 7

proc addBits*(
  b: var BitStreamWriter,
  dst: var string,
  value: uint32,
  bitLen: int
) =
  assert bitLen >= 0 and bitLen <= 32

  if b.pos + 8 > dst.len:
    # Make sure we have room to read64
    dst.setLen(max(dst.len * 2, 8))

  let
    dst = cast[ptr UncheckedArray[uint8]](dst[0].addr)
    value = value.uint64 and ((1.uint64 shl bitLen) - 1)
  write64(dst, b.pos, read32(dst, b.pos).uint64 or (value.uint64 shl b.bitPos))
  b.incPos(bitLen)

proc addBytes*(
  b: var BitStreamWriter,
  dst: var string,
  src: ptr UncheckedArray[uint8],
  srcPos, len: int
) =
  if b.bitPos != 0:
    raise newException(ZippyError, "Must be at a byte boundary")

  if b.pos + len > dst.len:
    dst.setLen(b.pos + len)

  copyMem(dst[b.pos].addr, src[srcPos].addr, len)
  b.incPos(len * 8)

proc skipRemainingBitsInCurrentByte*(b: var BitStreamWriter) =
  if b.bitPos > 0:
    b.incPos(8 - b.bitPos)

when defined(release):
  {.pop.}
