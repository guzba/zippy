import common, internal

## Use Snappy's algorithm for encoding repeated data instead of LZ77.
## This is much faster but does not compress as well. Perfect for BestSpeed.
## See https://github.com/guzba/supersnappy

func encodeFragment(
  encoded: var seq[uint16],
  src: string,
  op: var int,
  start, bytesToRead: int,
  compressTable: var seq[uint16],
  freqLitLen, freqDist: var seq[int],
  literalsTotal: var int
) =
  let ipEnd = start + bytesToRead
  var
    ip = start
    nextEmit = ip
    tableSize = 256
    shift = 24

  while tableSize < compressTable.len and tableSize < bytesToRead:
    tableSize = tableSize shl 1
    dec shift

  zeroMem(compressTable[0].addr, tableSize * sizeof(uint16))

  template addLiteral(start, length: int) =
    for i in 0 ..< length:
      inc freqLitLen[cast[uint8](src[start + i])]

    literalsTotal += length

    var remaining = length
    while remaining > 0:
      if op + 1 > encoded.len:
        encoded.setLen(encoded.len * 2)

      let added = min(remaining, (1 shl 15) - 1)
      encoded[op] = added.uint16
      inc op
      remaining -= added

  template addCopy(offset: int, length: int) =
    if op + 3 > encoded.len:
      encoded.setLen(encoded.len * 2)

    let
      lengthIndex = baseLengthIndices[length - baseMatchLen]
      distIndex = distanceCodeIndex((offset - 1).uint16)
    inc freqLitLen[lengthIndex + firstLengthCodeIndex]
    inc freqDist[distIndex]

    # The length and dist indices are packed into this value with the highest
    # bit set as a flag to indicate this starts a run.
    encoded[op] = ((lengthIndex shl 8) or distIndex) or (1 shl 15)
    encoded[op + 1] = offset.uint16
    encoded[op + 2] = length.uint16
    op += 3

  template emitRemainder() =
    if nextEmit < ipEnd:
      addLiteral(nextEmit, ipEnd - nextEmit)

  template hash(v: uint32): uint32 =
    (v * 0x1e35a7bd) shr shift

  template uint32AtOffset(v: uint64, offset: int): uint32 =
    ((v shr (8 * offset)) and 0xffffffff.uint32).uint32

  if bytesToRead >= 15:
    let ipLimit = start + bytesToRead - 15
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

      addLiteral(nextEmit, ip - nextEmit)

      var
        inputBytes: uint64
        candidateBytes: uint32
      while true:
        let
          limit = min(ipEnd, ip + maxMatchLen)
          matched = 4 + findMatchLength(src, candidate + 4, ip + 4, limit)
          offset = ip - candidate
        ip += matched
        addCopy(offset, matched)

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

func snappyEncode*(src: string): (seq[uint16], seq[int], seq[int], int) =
  var
    encoded = newSeq[uint16](4096)
    freqLitLen = newSeq[int](286)
    freqDist = newSeq[int](baseDistances.len)
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
    ip += bytesToRead

  encoded.setLen(op)
  (encoded, freqLitLen, freqDist, literalsTotal)
