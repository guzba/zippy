import internal, common

type
  BitStream* = object
    pos*: int
    data*: string
    # Reading
    bitCount*: int
    bitBuf*: uint64
    # Writing
    bitPos: uint

when defined(release):
  {.push checks: off.}

template failEndOfBuffer*() =
  raise newException(ZippyError, "Cannot read further, at end of buffer")

proc initBitStream*(data: string, pos = 0): BitStream =
  result.data = data
  result.pos = pos

proc fillBitBuf*(b: var BitStream) {.inline.} =
  while b.bitCount <= 56:
    if b.pos >= b.data.len:
      break
    b.bitBuf = b.bitBuf or (b.data[b.pos].uint64 shl b.bitCount)
    inc b.pos
    b.bitCount += 8

proc readBits*(b: var BitStream, bits: uint): uint16 =
  assert bits <= 16

  if b.bitCount < 16:
    b.fillBitBuf()

  result = (b.bitBuf and ((1.uint64 shl bits) - 1)).uint16
  b.bitBuf = b.bitBuf shr bits
  b.bitCount -= bits.int # bitCount can go negative if we've read past the end

proc readBytes*(b: var BitStream, dst: var string, start, len: int) =
  assert b.bitPos == 0
  assert b.bitCount mod 8 == 0

  let posOffset = b.bitCount div 8

  if b.pos - posOffset + len > b.data.len:
    failEndOfBuffer()

  copyMem(dst[start].addr, b.data[b.pos - posOffset].addr, len)

  b.pos = b.pos - posOffset + len
  b.bitCount = 0
  b.bitBuf = 0

proc incPos(b: var BitStream, bits: uint) {.inline.} =
  # Used when writing
  b.pos += ((bits + b.bitPos) shr 3).int
  b.bitPos = (bits + b.bitPos) and 7

proc skipRemainingBitsInCurrentByte*(b: var BitStream) =
  # If writing
  if b.bitPos > 0.uint:
    b.incPos(8.uint - b.bitPos)

  # If reading
  let mod8 = b.bitCount mod 8
  if mod8 != 0:
    b.bitCount -= mod8
    b.bitBuf = b.bitBuf shr mod8

proc addBytes*(b: var BitStream, src: string, start, len: int) =
  assert b.bitPos == 0

  if b.pos + len > b.data.len:
    b.data.setLen(b.pos + len)

  copyMem(b.data[b.pos].addr, src[start].unsafeAddr, len)

  b.incPos(len.uint * 8)

proc addBits*(b: var BitStream, value: uint32, bits: uint32) {.inline.} =
  assert bits <= 32

  if b.pos + 8 > b.data.len:
    # Make sure we have room to read64
    b.data.setLen(max(b.data.len * 2, 64))

  let value = value.uint64 and ((1.uint64 shl bits) - 1)

  write64(b.data, b.pos, read64(b.data, b.pos) or (value.uint64 shl b.bitPos))

  b.incPos(bits)

when defined(release):
  {.pop.}
