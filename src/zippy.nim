import zippy/internal, zippy/crc, zippy/deflate, zippy/inflate, zippy/common

export common

proc compress*(
  src: pointer,
  len: int,
  level = DefaultCompression,
  dataFormat = dfGzip
): string {.raises: [ZippyError].} =
  ## Compresses src and returns the compressed data.
  let src = cast[ptr UncheckedArray[uint8]](src)

  case dataFormat:
  of dfGzip:
    result.setLen(10)
    result[0] = 31.char
    result[1] = 139.char
    result[2] = 8.char

    deflate(result, src, len, level)

    let
      checksum = crc32(src, len)
      isize = len

    result.add(((checksum shr 0) and 255).char)
    result.add(((checksum shr 8) and 255).char)
    result.add(((checksum shr 16) and 255).char)
    result.add(((checksum shr 24) and 255).char)

    result.add(((isize shr 0) and 255).char)
    result.add(((isize shr 8) and 255).char)
    result.add(((isize shr 16) and 255).char)
    result.add(((isize shr 24) and 255).char)

  of dfZlib:
    const
      cm = 8.uint8
      cinfo = 7.uint8
      cmf = (cinfo shl 4) or cm
      fcheck = (31.uint32 - (cmf.uint32 * 256) mod 31).uint8

    result.setLen(2)
    result[0] = cmf.char
    result[1] = fcheck.char

    deflate(result, src, len, level)

    let checksum = adler32(src, len)

    result.add(((checksum shr 24) and 255).char)
    result.add(((checksum shr 16) and 255).char)
    result.add(((checksum shr 8) and 255).char)
    result.add(((checksum shr 0) and 255).char)

  of dfDeflate:
    deflate(result, src, len, level)

  else:
    raise newException(ZippyError, "Invalid data format " & $dfDetect)

proc compress*(
  src: string,
  level = DefaultCompression,
  dataFormat = dfGzip
): string {.inline, raises: [ZippyError].} =
  if src.len > 0:
    compress(src[0].unsafeAddr, src.len, level, dataFormat)
  else:
    compress(nil, 0, level, dataFormat)

proc uncompress*(
  src: pointer,
  len: int,
  dataFormat = dfDetect
): string {.raises: [ZippyError].} =
  ## Uncompresses src and returns the uncompressed data.
  let src = cast[ptr UncheckedArray[uint8]](src)

  case dataFormat:
  of dfDetect:
    if (
      len > 18 and
      src[0].uint8 == 31 and src[1].uint8 == 139 and src[2].uint8 == 8 and
      (src[3].uint8 and 0b11100000) == 0
    ):
      return uncompress(src, len, dfGzip)

    if (
      len > 6 and
      (src[0].uint8 and 0b00001111) == 8 and
      (src[0].uint8 shr 4) <= 7 and
      ((src[0].uint16 * 256) + src[1].uint8) mod 31 == 0
    ):
      return uncompress(src, len, dfZlib)

    raise newException(ZippyError, "Unable to detect compressed data format")

  of dfGzip:
    # Assumes the gzip src data only contains one file.
    if len < 18:
      failUncompress()

    let
      id1 = src[0].uint8
      id2 = src[1].uint8
      cm = src[2].uint8
      flg = src[3].uint8
      # mtime = src[4 .. 7]
      # xfl = src[8]
      # os = src[9]

    if id1 != 31 or id2 != 139:
      raise newException(ZippyError, "Failed gzip identification values check")

    if cm != 8: # DEFLATE
      raise newException(ZippyError, "Unsupported compression method")

    if (flg and 0b11100000) > 0.uint8:
      raise newException(ZippyError, "Reserved flag bits set")

    let
      # ftext = (flg and (1.uint8 shl 0)) != 0
      fhcrc = (flg and (1.uint8 shl 1)) != 0.uint8
      fextra = (flg and (1.uint8 shl 2)) != 0.uint8
      fname = (flg and (1.uint8 shl 3)) != 0.uint8
      fcomment = (flg and (1.uint8 shl 4)) != 0.uint8

    var pos = 10

    if fextra:
      raise newException(ZippyError, "Currently unsupported flags are set")

    if fname:
      pos += cast[cstring](src[pos].unsafeAddr).len + 1

    if fcomment:
      pos += cast[cstring](src[pos].unsafeAddr).len + 1

    if fhcrc:
      if pos + 2 >= len:
        failUncompress()
      # TODO: Need to implement this with a test file
      pos += 2

    if pos + 8 >= len:
      failUncompress()

    inflate(result, src, len, pos)

    let
      checksum = read32(src, len - 8)
      isize = read32(src, len - 4)

    if checksum != crc32(result):
      raise newException(ZippyError, "Checksum verification failed")

    if isize != (result.len mod (1 shl 31)).uint32:
      raise newException(ZippyError, "Size verification failed")

  of dfZlib:
    if len < 6:
      failUncompress()

    let
      cmf = src[0].uint8
      flg = src[1].uint8
      cm = cmf and 0b00001111
      cinfo = cmf shr 4

    if cm != 8: # DEFLATE
      raise newException(ZippyError, "Unsupported compression method")

    if cinfo > 7.uint8:
      raise newException(ZippyError, "Invalid compression info")

    if ((cmf.uint16 * 256) + flg.uint16) mod 31 != 0:
      raise newException(ZippyError, "Invalid header")

    if (flg and 0b00100000) != 0: # FDICT
      raise newException(ZippyError, "Preset dictionary is not yet supported")

    inflate(result, src, len, 2)

    let checksum = (
      src[len - 4].uint32 shl 24 or
      src[len - 3].uint32 shl 16 or
      src[len - 2].uint32 shl 8 or
      src[len - 1].uint32
    )

    if checksum != adler32(result):
      raise newException(ZippyError, "Checksum verification failed")

  of dfDeflate:
    inflate(result, src, len, 0)

proc uncompress*(
  src: string,
  dataFormat = dfDetect
): string {.inline, raises: [ZippyError].} =
  if src.len > 0:
    uncompress(src[0].unsafeAddr, src.len, dataFormat)
  else:
    uncompress(nil, 0, dataFormat)
