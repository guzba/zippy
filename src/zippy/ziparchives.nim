import os, random, strutils, streams, tables, zippy, zippy/common, zippy/crc,
    zippy/zippyerror

export zippyerror

type
  EntryKind* = enum
    ekFile, ekDirectory

  ArchiveEntry* = object
    kind*: EntryKind
    contents*: string

  ZipArchive* = ref object
    contents*: OrderedTable[string, ArchiveEntry]

proc addDir(archive: ZipArchive, base, relative: string) =
  if relative.len > 0 and relative notin archive.contents:
    archive.contents[(relative & os.DirSep).toUnixPath()] =
      ArchiveEntry(kind: ekDirectory)

  for kind, path in walkDir(base / relative, relative = true):
    case kind:
    of pcFile:
      archive.contents[(relative / path).toUnixPath()] = ArchiveEntry(
        kind: ekFile,
        contents: readFile(base / relative / path)
      )
    of pcDir:
      archive.addDir(base, relative / path)
    else:
      discard

proc addDir*(archive: ZipArchive, dir: string) =
  ## Recursively adds all of the files and directories inside dir to archive.
  if splitFile(dir).ext.len > 0:
    raise newException(
      ZippyError,
      "Error adding dir " & dir & " to archive, appears to be a file?"
    )

  let (head, tail) = splitPath(dir)
  archive.addDir(head, tail)

proc clear*(archive: ZipArchive) =
  archive.contents.clear()

template failEOF() =
  raise newException(
    ZippyError, "Attempted to read past end of file, corrupted zip archive?"
  )

proc open*(archive: ZipArchive, data: seq[uint8]) =
  ## Opens the zip archive data and reads its contents into
  ## tarball.contents (clears any existing archive.contents entries).

  archive.clear()

  template failOpen() =
    raise newException(ZippyError, "Unexpected error opening zip archive")

  var pos: int
  while true:
    if pos + 4 > data.len:
      failEOF()

    let signature = read32(data, pos)
    case signature:
    of 0x04034b50: # Local file header
      if pos + 30 > data.len:
        failEOF()

      let
        # minVersionToExtract = read16(data, pos + 4)
        generalPurposeFlag = read16(data, pos + 6)
        compressionMethod = read16(data, pos + 8)
        # lastModifiedTime = read16(data, pos + 10)
        # lastModifiedDate = read16(data, pos + 12)
        uncompressedCrc32 = read32(data, pos + 14)
        compressedSize = read32(data, pos + 18).int
        uncompressedSize = read32(data, pos + 22).int
        fileNameLength = read16(data, pos + 26).int
        extraFieldLength = read16(data, pos + 28).int

      pos += 30 # Move to end of fixed-size entries

      if (generalPurposeFlag and 0b100) != 0:
        raise newException(
          ZippyError,
          "Unsupported zip archive, data descriptor bit set"
        )

      if (generalPurposeFlag and 0b1000) != 0:
        raise newException(
          ZippyError,
          "Unsupported zip archive, uses deflate64"
        )

      # echo minVersionToExtract
      # echo generalPurposeFlag
      # echo compressionMethod
      # echo lastModifiedTime
      # echo lastModifiedDate
      # echo uncompressedCrc32
      # echo compressedSize
      # echo uncompressedSize
      # echo fileNameLength
      # echo extraFieldLength

      if compressionMethod notin [0.uint16, 8]:
        raise newException(
          ZippyError,
          "Unsupported zip archive compression method " & $compressionMethod
        )

      if pos + fileNameLength + extraFieldLength > data.len:
        failEOF()

      let fileName = cast[string](data[pos ..< pos + fileNameLength])
      pos += fileNameLength
      # let extraField = cast[string](data[pos ..< pos + extraFieldLength])
      pos += extraFieldLength

      # echo fileName
      # echo extraField

      if pos + compressedSize > data.len:
        failEOF()

      let uncompressed =
        if compressionMethod == 0:
          data[pos ..< pos + compressedSize]
        else:
          uncompress(data[pos ..< pos + compressedSize], dfDeflate)

      if crc32(uncompressed) != uncompressedCrc32:
        raise newException(
          ZippyError,
          "Verifying archive entry " & fileName & " CRC-32 failed"
        )
      if uncompressed.len != uncompressedSize:
        raise newException(
          ZippyError,
          "Unexpected error verifying " & fileName & " uncompressed size"
        )

      archive.contents[fileName.toUnixPath()] =
        ArchiveEntry(contents: cast[string](uncompressed))

      pos += compressedSize

    of 0x02014b50: # Central directory header
      if pos + 46 > data.len:
        failEOF()

      let
        # versionMadeBy = read16(data, pos + 4)
        # minVersionToExtract = read16(data, pos + 6)
        # generalPurposeFlag = read16(data, pos + 8)
        # compressionMethod = read16(data, pos + 10)
        # lastModifiedTime = read16(data, pos + 12)
        # lastModifiedDate = read16(data, pos + 14)
        # uncompressedCrc32 = read32(data, pos + 16)
        # compressedSize = read32(data, pos + 20).int
        # uncompressedSize = read32(data, pos + 24).int
        fileNameLength = read16(data, pos + 28).int
        extraFieldLength = read16(data, pos + 30).int
        fileCommentLength = read16(data, pos + 32).int
        # diskNumber = read16(data, pos + 34)
        # internalFileAttr = read16(data, pos + 36)
        externalFileAttr = read32(data, pos + 38) and uint16.high
        # relativeOffsetOfLocalFileHeader = read32(data, pos + 42)

      # echo versionMadeBy
      # echo minVersionToExtract
      # echo generalPurposeFlag
      # echo compressionMethod
      # echo lastModifiedTime
      # echo lastModifiedDate
      # echo uncompressedCrc32
      # echo compressedSize
      # echo uncompressedSize
      # echo fileNameLength
      # echo extraFieldLength
      # echo fileCommentLength
      # echo diskNumber
      # echo internalFileAttr
      # echo externalFileAttr
      # echo relativeOffsetOfLocalFileHeader

      pos += 46 # Move to end of fixed-size entries

      if pos + fileNameLength + extraFieldLength + fileCommentLength > data.len:
        failEOF()

      let fileName = cast[string](data[pos ..< pos + fileNameLength])
      pos += fileNameLength
      # let extraField = cast[string](data[pos ..< pos + extraFieldLength])
      pos += extraFieldLength
      # let fileComment = cast[string](data[pos ..< pos + fileCommentLength])
      pos += fileCommentLength

      # echo fileName
      # echo extraField
      # echo fileComment

      try:
        # Update the entry kind for directories
        if (externalFileAttr and 0x10) == 0x10:
          archive.contents[fileName].kind = ekDirectory
      except KeyError:
        failOpen()

    of 0x06054b50: # End of central directory record
      if pos + 22 > data.len:
        failEOF()

      let
        # diskNumber = read16(data, pos + 4)
        # startDisk = read16(data, pos + 6)
        # numRecordsOnDisk = read16(data, pos + 8)
        # numCentralDirectoryRecords = read16(data, pos + 10)
        # centralDirectorySize = read32(data, pos + 12)
        # relativeOffsetOfCentralDirectory = read32(data, pos + 16)
        commentLength = read16(data, pos + 20).int

      # echo diskNumber
      # echo startDisk
      # echo numRecordsOnDisk
      # echo numCentralDirectoryRecords
      # echo centralDirectorySize
      # echo relativeOffsetOfCentralDirectory
      # echo commentLength

      pos += 22 # Move to end of fixed-size entries

      if pos + commentLength > data.len:
        failEOF()

      # let comment = readStr(data, pos, commentLength)
      pos += commentLength

      # echo comment

      break

    else:
      failOpen()

proc open*(archive: ZipArchive, stream: StringStream) =
  ## Opens the zip archive from a stream (in-memory) and reads its contents into
  ## archive.contents (clears any existing archive.contents entries).
  open(archive, cast[seq[uint8]](stream.readAll()))

proc open*(archive: ZipArchive, path: string) =
  ## Opens the zip archive file located at path and reads its contents into
  ## archive.contents (clears any existing archive.contents entries).
  open(archive, cast[seq[uint8]](readFile(path)))

proc writeZipArchive*(archive: ZipArchive, path: string) =
  ## Writes archive.contents to a zip file at path.

  if archive.contents.len == 0:
    raise newException(ZippyError, "Zip archive has no contents")

  type Values = object
    offset, crc32, compressedLen, uncompressedLen: uint32
    compressionMethod: uint16

  var
    data: seq[uint8]
    values: Table[string, Values]

  # Write each file entry
  for path, entry in archive.contents:
    var v: Values
    v.offset = data.len.uint32

    let contents = cast[seq[uint8]](entry.contents)
    data.add(cast[array[4, uint8]](0x04034b50)) # Local file header signature
    data.add(cast[array[2, uint8]](20.uint16)) # Min version to extract
    data.add(cast[array[2, uint8]](1.uint16 shl 11)) # General purpose flag UTF-8

    # Compression method
    if splitFile(path).name.len == 0 or contents.len == 0:
      v.compressionMethod = 0
    else:
      v.compressionMethod = 8

    data.add(cast[array[2, uint8]](v.compressionMethod))

    data.add([0.uint8, 0]) # Last modified time
    data.add([0.uint8, 0]) # Last modified date

    v.crc32 = crc32(contents)
    data.add(cast[array[4, uint8]](v.crc32))

    let compressed =
      if contents.len > 0:
        compress(contents, DefaultCompression, dfDeflate)
      else:
        newSeq[uint8]()

    v.compressedLen = compressed.len.uint32
    v.uncompressedLen = contents.len.uint32

    data.add(cast[array[4, uint8]](v.compressedLen))
    data.add(cast[array[4, uint8]](v.uncompressedLen))

    data.add(cast[array[2, uint8]](path.len.uint16)) # File name len
    data.add([0.uint8, 0]) # Extra field len

    data.add(cast[seq[uint8]](path))

    data.add(compressed)
    values[path] = v

  # Write the central directory
  let centralDirectoryOffset = data.len
  var centralDirectorySize: int
  for path, entry in archive.contents:
    let v =
      try:
        values[path]
      except KeyError:
        raise newException(ZippyError, "Unexpected error writing archive")

    data.add(cast[array[4, uint8]](0x02014b50)) # Central directory signature
    data.add(cast[array[2, uint8]](63.uint16)) # Version made by
    data.add(cast[array[2, uint8]](20.uint16)) # Min version to extract
    data.add(cast[array[2, uint8]](1.uint16 shl 11)) # General purpose flag UTF-8
    data.add(cast[array[2, uint8]](v.compressionMethod))
    data.add([0.uint8, 0]) # Last modified time
    data.add([0.uint8, 0]) # Last modified date
    data.add(cast[array[4, uint8]](v.crc32))
    data.add(cast[array[4, uint8]](v.compressedLen))
    data.add(cast[array[4, uint8]](v.uncompressedLen))
    data.add(cast[array[2, uint8]](path.len.uint16)) # File name len
    data.add([0.uint8, 0]) # Extra field len
    data.add([0.uint8, 0]) # File comment len
    data.add([0.uint8, 0]) # Disk number
    data.add([0.uint8, 0]) # Internal file attrib

    # External file attrib
    case entry.kind:
    of ekDirectory:
      data.add([0x10.uint8, 0, 0, 0])
    of ekFile:
      data.add([0x20.uint8, 0, 0, 0])

    data.add(cast[array[4, uint8]](v.offset)) # Relative offset of local file header
    data.add(cast[seq[uint8]](path))

    centralDirectorySize += 46 + path.len

  # Write the end of central directory record
  data.add(cast[array[4, uint8]](0x06054b50)) # End of central directory signature
  data.add([0.uint8, 0])
  data.add([0.uint8, 0])
  data.add(cast[array[2, uint8]](archive.contents.len.uint16))
  data.add(cast[array[2, uint8]](archive.contents.len.uint16))
  data.add(cast[array[4, uint8]](centralDirectorySize.uint32))
  data.add(cast[array[4, uint8]](centralDirectoryOffset.uint32))
  data.add([0.uint8, 0])

  writeFile(path, data)

proc extractAll*(archive: ZipArchive, dest: string) =
  ## Extracts the files stored in archive to the destination directory.
  ## The path to the destination directory must exist.
  ## The destination directory itself must not exist (it is not overwitten).

  if dirExists(dest):
    raise newException(
      ZippyError, "Destination " & dest & " already exists"
    )
  let (head, tail) = splitPath(dest)
  if tail != "" and not dirExists(head):
    raise newException(
      ZippyError, "Path to destination " & dest & " does not exist"
    )

  proc randomString(len: int): string =
    for _ in 0 ..< len:
      result.add(rand('a'.int .. 'z'.int).char)

  let tmpDir =
    when defined(windows):
      getHomeDir() / r"AppData\Local\Temp" / "ziparchive_" & randomString(10)
    else:
      getTempDir() / "ziparchive_" & randomString(10)
  removeDir(tmpDir)
  createDir(tmpDir)

  for path, entry in archive.contents:
    if path.isAbsolute():
      raise newException(
        ZippyError,
        "Extracting absolute paths is not supported (" & path & ")"
      )
    if path.contains(".."):
      raise newException(
        ZippyError,
        "Extracting paths containing `...` is not supported (" & path & ")"
      )

    case entry.kind:
    of ekDirectory:
      createDir(tmpDir / path)
    of ekFile:
      createDir(tmpDir / splitFile(path).dir)
      writeFile(tmpDir / path, entry.contents)

  moveDir(tmpDir, dest)

proc extractAll*(zipPath, dest: string) =
  ## Extracts the files in the archive located at zipPath into the destination
  ## directory.
  let archive = ZipArchive()
  archive.open(zipPath)
  archive.extractAll(dest)

proc createZipArchive*(source, dest: string) =
  ## Creates an archive containing all of the files and directories inside
  ## source and writes the zip file to dest.
  let archive = ZipArchive()
  archive.addDir(source)
  archive.writeZipArchive(dest)
