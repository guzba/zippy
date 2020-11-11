import zippy/common

## Use Snappy's algorithm for encoding repeated data instead of LZ77.
## This is much faster but does not compress as well. Perfect for BestSpeed.
## See https://github.com/guzba/supersnappy

func emitLiteral(
  dst: var seq[uint16],
  src: seq[uint8],
  op: var int,
  ip: int,
  len: int,
  freqLitLen: var seq[int],
  literalsTotal: var int
) =
  if op + len > dst.len:
    dst.setLen(dst.len * 2)

  dst[op] = len.uint16
  inc op
  inc(literalsTotal, len)

  for i in 0 ..< len:
    inc freqLitLen[src[ip + i]]

func emitCopy(
  dst: var seq[uint16],
  op: var int,
  offset: int,
  len: int,
  freqLitLen, freqDist: var seq[int]
) =
  if op + len > dst.len:
    dst.setLen(dst.len * 2)

  let
    lengthIndex = findCodeIndex(baseLengths, len.uint16)
    distIndex = findCodeIndex(baseDistance, offset.uint16)
  inc freqLitLen[lengthIndex + firstLengthCodeIndex]
  inc freqDist[distIndex]

  # The length and dist indices are packed into this value with the highest
  # bit set as a flag to indicate this starts a run.
  dst[op] = ((lengthIndex shl 8) or distIndex) or (1 shl 15)
  dst[op + 1] = offset.uint16
  dst[op + 2] = len.uint16
  inc(op, 3)

func encodeFragment(
  dst: var seq[uint16],
  src: seq[uint8],
  op: var int,
  start: int,
  len: int,
  compressTable: var seq[uint16],
  freqLitLen, freqDist: var seq[int],
  literalsTotal: var int
) =
  let ipEnd = start + len
  var
    ip = start
    nextEmit = ip
    tableSize = 256
    shift = 24

  while tableSize < compressTable.len and tableSize < len:
    tableSize = tableSize shl 1
    dec shift

  when nimvm:
    for i in 0 ..< tableSize:
      compressTable[i] = 0
  else:
    zeroMem(compressTable[0].addr, tableSize * sizeof(uint16))

  template hash(v: uint32): uint32 =
    (v * 0x1e35a7bd) shr shift

  template uint32AtOffset(v: uint64, offset: int): uint32 =
    ((v shr (8 * offset)) and 0xffffffff.uint32).uint32

  template emitRemainder() =
    if nextEmit < ipEnd:
      emitLiteral(
        dst,
        src,
        op,
        nextEmit,
        ipEnd - nextEmit,
        freqLitLen,
        literalsTotal
      )

  if len >= 15:
    let ipLimit = start + len - 15
    inc ip

    var nextHash = hash(read32(src, ip))
    while true:
      var
        skipBytes = 32
        nextIp = ip
        candidate: int
      while true:
        ip = nextIp
        var
          h = nextHash
          bytesBetweenHashLookups = skipBytes shr 5
        inc skipBytes
        nextIp = ip + bytesBetweenHashLookups
        if nextIp > ipLimit:
          emitRemainder()
          return
        nextHash = hash(read32(src, nextIp))
        candidate = start + compressTable[h].int
        compressTable[h] = (ip - start).uint16

        if read32(src, ip) == read32(src, candidate):
          break

      emitLiteral(
        dst,
        src,
        op,
        nextEmit,
        ip - nextEmit,
        freqLitLen,
        literalsTotal
      )

      var
        inputBytes: uint64
        candidateBytes: uint32
      while true:
        let
          limit = min(ipEnd, ip + maxMatchLen)
          matched = 4 + findMatchLength(src, candidate + 4, ip + 4, limit)
          offset = ip - candidate
        inc(ip, matched)
        emitCopy(dst, op, offset, matched, freqLitLen, freqDist)

        let insertTail = ip - 1
        nextEmit = ip
        if ip >= ipLimit:
          emitRemainder()
          return
        inputBytes = read64(src, insertTail)
        let
          prevHash = hash(uint32AtOffset(inputBytes, 0))
          curHash = hash(uint32AtOffset(inputBytes, 1))
        compressTable[prevHash] = (ip - start - 1).uint16
        candidate = start + compressTable[curHash].int
        candidateBytes = read32(src, candidate)
        compressTable[curHash] = (ip - start).uint16

        if uint32AtOffset(inputBytes, 1) != candidateBytes:
          break

      nextHash = hash(uint32AtOffset(inputBytes, 2))
      inc ip

  emitRemainder()

func snappyEncode*(
  src: seq[uint8]
): (seq[uint16], seq[int], seq[int], int) =
  var
    encoded = newSeq[uint16](src.len div 2)
    freqLitLen = newSeq[int](286)
    freqDist = newSeq[int](baseDistance.len)
    literalsTotal: int

  freqLitLen[256] = 1 # Alway 1 end-of-block symbol

  const
    maxBlockSize = maxWindowSize
    maxCompressTableSize = 1 shl 14

  var
    ip, op: int
    compressTable = newSeq[uint16](maxCompressTableSize)
  while ip < src.len:
    let
      fragmentSize = src.len - ip
      bytesToRead = min(fragmentSize, maxBlockSize)
    if bytesToRead <= 0:
      failCompress()

    encodeFragment(
      encoded,
      src,
      op,
      ip,
      bytesToRead,
      compressTable,
      freqLitLen,
      freqDist,
      literalsTotal
    )
    inc(ip, bytesToRead)

  encoded.setLen(op)
  (encoded, freqLitLen, freqDist, literalsTotal)
