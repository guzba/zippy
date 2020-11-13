import zippy/common, zippy/deflate, zippy/inflate, zippy/zippyerror

export zippyerror

const
  NoCompression* = 0
  BestSpeed* = 1
  BestCompression* = 9
  DefaultCompression* = -1
  HuffmanOnly* = -2

type
  CompressedDataFormat* = enum ## Supported compressed data formats
    dfDetect, dfZlib, dfGzip, dfDeflate

func compress*(
  src: seq[uint8], level = DefaultCompression, dataFormat = dfGzip
): seq[uint8] =
  ## Compresses src and returns the compressed data.

  if dataFormat == dfDetect:
    raise newException(
      ZippyError,
      "A data format must be specified to compress"
    )

  let deflated = deflate(src, level)

  if dataFormat == dfGzip:
    result.setLen(10)
    result[0] = 31
    result[1] = 139
    result[2] = 8

    result.add(deflated)

    let checksum = crc32(src)
    result.add([
      ((checksum shr 0) and 255).uint8,
      ((checksum shr 8) and 255).uint8,
      ((checksum shr 16) and 255).uint8,
      ((checksum shr 24) and 255).uint8
    ])
    result.add([
      ((src.len shr 0) and 255).uint8,
      ((src.len shr 8) and 255).uint8,
      ((src.len shr 16) and 255).uint8,
      ((src.len shr 24) and 255).uint8
    ])
  elif dataFormat == dfZlib:
    const
      cm = 8.uint8
      cinfo = 7.uint8
      cmf = (cinfo shl 4) or cm
      fcheck = (31 - (cmf.uint32 * 256) mod 31).uint8

    result.setLen(2)
    result[0] = cmf
    result[1] = fcheck

    result.add(deflated)

    let checksum = adler32(src)
    result.add([
      ((checksum shr 24) and 255).uint8,
      ((checksum shr 16) and 255).uint8,
      ((checksum shr 8) and 255).uint8,
      ((checksum shr 0) and 255).uint8
    ])
  else:
    result = deflated

template compress*(
  src: string, level = DefaultCompression, dataFormat = dfGzip
): string =
  ## Helper for when preferring to work with strings.
  when nimvm:
    # This is unfortunately needed to convert to and from string -> seq[uint]
    # since we cannot cast when nimvm.
    var tmp = newSeq[uint8](src.len)
    for i, c in src:
      tmp[i] = c.uint8
    let compressed = compress(tmp, level, dataFormat)
    var result = newStringOfCap(compressed.len)
    for c in compressed:
      result.add(c.char)
    result
  else:
    cast[string](compress(cast[seq[uint8]](src), level, dataFormat))

func uncompress(
  src: seq[uint8], dataFormat: CompressedDataFormat, dst: var seq[uint8]
) =
  case dataFormat:
  of dfGzip:
    # Assumes the gzip src data to uncompress contains only one member.

    if src.len < 18:
      failUncompress()

    let
      id1 = src[0]
      id2 = src[1]
      cm = src[2]
      flg = src[3]
      # mtime = src[4 .. 7]
      # xfl = src[8]
      # os = src[9]

    if id1 != 31 or id2 != 139:
      raise newException(ZippyError, "Failed gzip identification values check")
    if cm != 8: # DEFLATE
      raise newException(ZippyError, "Unsupported compression method")
    if (flg and 0b11100000) > 0:
      raise newException(ZippyError, "Reserved flag bits set")

    let
      # ftext = (flg and (1.uint8 shl 0)) > 0
      fhcrc = (flg and (1.uint8 shl 1)) > 0
      fextra = (flg and (1.uint8 shl 2)) > 0
      fname = (flg and (1.uint8 shl 3)) > 0
      fcomment = (flg and (1.uint8 shl 4)) > 0

    var pos = 10

    func nextZeroByte(s: seq[uint8], start: int): int =
      for i in start ..< s.len:
        if s[i] == 0:
          return i
      failUncompress()

    if fextra:
      raise newException(ZippyError, "Currently unsupported flags are set")

    if fname:
      pos = nextZeroByte(src, pos) + 1
    if fcomment:
      pos = nextZeroByte(src, pos) + 1
    if fhcrc:
      if pos + 2 >= src.len:
        failUncompress()
      # TODO: Need to verify this works with a test file
      # let checksum =
      # if checksum != crc32(src[0 ..< pos]):
      #   raise newException(ZippyError, "Header checksum verification failed")
      inc(pos, 2)

    if pos + 8 >= src.len:
      failUncompress()

    inflate(dst, src[pos ..< ^8])

    let checksum = read32(src, src.len - 8)
    if checksum != crc32(dst):
      raise newException(ZippyError, "Checksum verification failed")

    let isize = read32(src, src.len - 4)
    if isize != (dst.len mod (1 shl 32)).uint32:
      raise newException(ZippyError, "Size verification failed")
  of dfZlib:
    if src.len < 6:
      failUncompress()

    let checksum = (
      src[^4].uint32 shl 24 or
      src[^3].uint32 shl 16 or
      src[^2].uint32 shl 8 or
      src[^1].uint32
    )

    let
      cmf = src[0]
      flg = src[1]
      cm = cmf and 0b00001111
      cinfo = cmf shr 4

    if cm != 8: # DEFLATE
      raise newException(ZippyError, "Unsupported compression method")
    if cinfo > 7:
      raise newException(ZippyError, "Invalid compression info")
    if ((cmf.uint16 * 256) + flg.uint16) mod 31 != 0:
      raise newException(ZippyError, "Invalid header")
    if (flg and 0b00100000) != 0: # FDICT
      raise newException(ZippyError, "Preset dictionary is not yet supported")

    inflate(dst, src[2 .. ^4])

    if checksum != adler32(dst):
      raise newException(ZippyError, "Checksum verification failed")
  of dfDeflate:
    inflate(dst, src)
  of dfDetect:
    # Should never happen
    failUncompress()

func uncompress*(src: seq[uint8], dataFormat = dfDetect): seq[uint8] =
  ## Uncompresses src and returns the uncompressed data seq.

  result = newSeqOfCap[uint8](src.len)

  case dataFormat:
  of dfDetect:
    if (
      src.len >= 18 and
      src[0 .. 2] == [31.uint8, 139, 8] and
      (src[3] and 0b11100000) == 0
    ): # This looks like gzip
      uncompress(src, dfGzip, result)
    elif (
      src.len >= 6 and
      (src[0] and 0b00001111) == 8 and
      (src[0] shr 4) <= 7 and
      ((src[0].uint16 * 256) + src[1].uint16) mod 31 == 0
    ): # This looks like zlib
      uncompress(src, dfZlib, result)
    else:
      raise newException(ZippyError, "Unable to detect compressed data format")
  else:
    uncompress(src, dataFormat, result)

template uncompress*(src: string, dataFormat = dfDetect): string =
  ## Helper for when preferring to work with strings.
  when nimvm:
    # This is unfortunately needed to convert to and from string -> seq[uint]
    # since we cannot cast when nimvm.
    var tmp = newSeq[uint8](src.len)
    for i, c in src:
      tmp[i] = c.uint8
    let uncompressed = uncompress(tmp)
    var result = newStringOfCap(uncompressed.len)
    for c in uncompressed:
      result.add(c.char)
    result
  else:
    cast[string](uncompress(cast[seq[uint8]](src), dataFormat))
