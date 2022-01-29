import common, crc, internal, std/memfiles, std/os, std/strutils, std/tables,
    std/times, std/unicode, ziparchives_v1, zippy

export ziparchives_v1

const
  fileHeaderSignature = 0x04034b50.uint32
  centralDirectoryFileHeaderSignature = 0x02014b50.uint32
  endOfCentralDirectorySignature = 0x06054b50.uint32

type
  ZipArchiveRecordKind = enum
    FileRecord, DirectoryRecord

  ZipArchiveRecord = object
    kind: ZipArchiveRecordKind
    fileHeaderOffset: int
    path: string
    uncompressedCrc32: uint32
    compressedSize: int
    uncompressedSize: int
    filePermissions: set[FilePermission]

  ZipArchiveReader = ref object
    memFile: MemFile
    records: Table[string, ZipArchiveRecord]

template failEOF() =
  raise newException(ZippyError, "Unexpected EOF, invalid zip archive?")

iterator walkFiles*(reader: ZipArchiveReader): string =
  ## Walks over all files in the archive and returns the file name
  ## (including the path).
  for _, record in reader.records:
    if record.kind == FileRecord:
      yield record.path

proc extractFile*(
  reader: ZipArchiveReader, path: string
): string {.raises: [ZippyError].} =

  template failNoFileRecord() =
    raise newException(ZippyError, "No file record found for " & path)

  let
    src = cast[ptr UncheckedArray[uint8]](reader.memFile.mem)
    record =
      try:
        reader.records[path]
      except KeyError:
        failNoFileRecord()

  var pos = record.fileHeaderOffset

  if pos + 30 > reader.memFile.size:
    failEOF()

  if read32(src, pos) != fileHeaderSignature:
    raise newException(ZippyError, "Invalid file header")

  let
    # minVersionToExtract = read16(src, pos + 4)
    # generalPurposeFlag = read16(src, pos + 6)
    compressionMethod = read16(src, pos + 8)
    # lastModifiedTime = read16(src, pos + 10)
    # lastModifiedDate = read16(src, pos + 12)
    # uncompressedCrc32 = read32(src, pos + 14)
    # compressedSize = read32(src, pos + 18).int
    # uncompressedSize = read32(src, pos + 22).int
    fileNameLen = read16(src, pos + 26).int
    extraFieldLen = read16(src, pos + 28).int

  pos += 30 + fileNameLen + extraFieldLen

  if pos + record.compressedSize > reader.memFile.size:
    failEOF()

  case record.kind:
  of FileRecord:
    if compressionMethod == 0: # No compression
      if record.compressedSize > 0:
        result.setLen(record.compressedSize)
        copyMem(result[0].addr, src[pos].addr, record.compressedSize)
    elif compressionMethod == 8: # Deflate
      result = uncompress(src[pos].addr, record.compressedSize, dfDeflate)
    else:
      raise newException(ZippyError, "Unsupported archive, compression method")
  of DirectoryRecord:
    failNoFileRecord()

  if crc32(result) != record.uncompressedCrc32:
    raise newException(ZippyError, "Verifying crc32 failed")

proc close*(reader: ZipArchiveReader) =
  reader.memFile.close()

proc parseMsDosDateTime(time, date: uint16): Time =
  let
    seconds = (time and 0b0000000000011111).int * 2
    minutes = ((time shr 5) and 0b0000000000111111).int
    hours = ((time shr 11) and 0b0000000000011111).int
    days = (date and 0b0000000000011111).int
    months = ((date shr 5) and 0b0000000000001111).int
    years = ((date shr 9) and 0b0000000001111111).int
  if seconds <= 59 and minutes <= 59 and hours <= 23:
    result = initDateTime(
      days.MonthdayRange,
      months.Month,
      years + 1980,
      hours.HourRange,
      minutes.MinuteRange,
      seconds.SecondRange,
      local()
    ).toTime()

proc parseFilePermissions(externalFileAttr: uint32): set[FilePermission] =
  let permissions = externalFileAttr shr 16
  if defined(windows) or permissions == 0:
    # Ignore file permissions on Windows. If they are absent (.zip made on
    # Windows for example), set default permissions.
    result.incl fpUserRead
    result.incl fpUserWrite
    result.incl fpGroupRead
    result.incl fpGroupWrite
    result.incl fpOthersRead
  else:
    if (permissions and 0o00400) != 0: result.incl fpUserRead
    if (permissions and 0o00200) != 0: result.incl fpUserWrite
    if (permissions and 0o00100) != 0: result.incl fpUserExec
    if (permissions and 0o00040) != 0: result.incl fpGroupRead
    if (permissions and 0o00020) != 0: result.incl fpGroupWrite
    if (permissions and 0o00010) != 0: result.incl fpGroupExec
    if (permissions and 0o00004) != 0: result.incl fpOthersRead
    if (permissions and 0o00002) != 0: result.incl fpOthersWrite
    if (permissions and 0o00001) != 0: result.incl fpOthersExec

proc utf8ify(fileName: string): string =
  const cp437AfterAscii = [
    # 0x80 - 0x8f
    0x00c7.uint32, 0x00fc, 0x00e9, 0x00e2, 0x00e4, 0x00e0, 0x00e5, 0x00e7,
    0x00ea, 0x00eb, 0x00e8, 0x00ef, 0x00ee, 0x00ec, 0x00c4, 0x00c5,
    # 0x90 - 0x9f
    0x00c9, 0x00e6, 0x00c6, 0x00f4, 0x00f6, 0x00f2, 0x00fb, 0x00f9,
    0x00ff, 0x00d6, 0x00dc, 0x00a2, 0x00a3, 0x00a5, 0x20a7, 0x0192,
    # 0xa0 - 0xaf
    0x00e1, 0x00ed, 0x00f3, 0x00fa, 0x00f1, 0x00d1, 0x00aa, 0x00ba,
    0x00bf, 0x2310, 0x00ac, 0x00bd, 0x00bc, 0x00a1, 0x00ab, 0x00bb,
    # 0xb0 - 0xbf
    0x2591, 0x2592, 0x2593, 0x2502, 0x2524, 0x2561, 0x2562, 0x2556,
    0x2555, 0x2563, 0x2551, 0x2557, 0x255d, 0x255c, 0x255b, 0x2510,
    # 0xc0 - 0xcf
    0x2514, 0x2534, 0x252c, 0x251c, 0x2500, 0x253c, 0x255e, 0x255f,
    0x255a, 0x2554, 0x2569, 0x2566, 0x2560, 0x2550, 0x256c, 0x2567,
    # 0xd0 - 0xdf
    0x2568, 0x2564, 0x2565, 0x2559, 0x2558, 0x2552, 0x2553, 0x256b,
    0x256a, 0x2518, 0x250c, 0x2588, 0x2584, 0x258c, 0x2590, 0x2580,
    # 0xd0 - 0xdf
    0x03b1, 0x00df, 0x0393, 0x03c0, 0x03a3, 0x03c3, 0x00b5, 0x03c4,
    0x03a6, 0x0398, 0x03a9, 0x03b4, 0x221e, 0x03c6, 0x03b5, 0x2229,
    # 0xf0 - 0xff
    0x2261, 0x00b1, 0x2265, 0x2264, 0x2320, 0x2321, 0x00f7, 0x2248,
    0x00b0, 0x2219, 0x00b7, 0x221a, 0x207f, 0x00b2, 0x25a0, 0x00a0
  ]

  if validateUtf8(fileName) == -1:
    return fileName

  # If the file name is not valid utf-8, assume it is CP437 / OEM / DOS
  var runes: seq[Rune]
  for c in fileName:
    if c > 0x7f.char:
      runes.add Rune(cp437AfterAscii[c.int - 0x80])
    else:
      runes.add Rune(c)
  $runes

proc findEndOfCentralDirectory(reader: ZipArchiveReader): int =
  let src = cast[ptr UncheckedArray[uint8]](reader.memFile.mem)

  result = reader.memFile.size - 22
  while true:
    if result < 0:
      failEOF()
    if read32(src, result) == endOfCentralDirectorySignature:
      return
    else:
      dec result

proc openZipArchive*(
  zipPath: string
): ZipArchiveReader {.raises: [IOError, OSError, ZippyError].} =
  result = ZipArchiveReader()
  result.memFile = memfiles.open(zipPath)

  let src = cast[ptr UncheckedArray[uint8]](result.memFile.mem)

  let eocd = result.findEndOfCentralDirectory()
  if eocd + 22 > result.memFile.size:
    failEOF()

  let
    diskNumber = read16(src, eocd + 4).int
    startDisk = read16(src, eocd + 6).int
    numRecordsOnDisk = read16(src, eocd + 8).int
    numCentralDirectoryRecords = read16(src, eocd + 10).int
    centralDirectorySize = read32(src, eocd + 12).int
    centralDirectoryStart = read32(src, eocd + 16).int
    commentLen = read16(src, eocd + 20).int

  if diskNumber == 0xffff:
    raise newException(ZippyError, "Unsupported archive, ZIP64")

  if diskNumber != 0:
    raise newException(ZippyError, "Unsupported archive, disk number")

  if startDisk != 0:
    raise newException(ZippyError, "Unsupported archive, start disk")

  if numRecordsOnDisk != numCentralDirectoryRecords:
    raise newException(ZippyError, "Unsupported archive, record number")

  if eocd + 22 + commentLen > result.memFile.size:
    failEOF()

  var pos = centralDirectoryStart

  for _ in 0 ..< numCentralDirectoryRecords:
    if pos + 46 > result.memFile.size:
      failEOF()

    if read32(src, pos) != centralDirectoryFileHeaderSignature:
      raise newException(ZippyError, "Invalid central directory file header")

    let
      # versionMadeBy = read16(src, pos + 4)
      # minVersionToExtract = read16(src, pos + 6)
      generalPurposeFlag = read16(src, pos + 8)
      compressionMethod = read16(src, pos + 10)
      # lastModifiedTime = read16(src, pos + 12)
      # lastModifiedDate = read16(src, pos + 14)
      uncompressedCrc32 = read32(src, pos + 16)
      compressedSize = read32(src, pos + 20).int
      uncompressedSize = read32(src, pos + 24).int
      fileNameLen = read16(src, pos + 28).int
      extraFieldLen = read16(src, pos + 30).int
      fileCommentLen = read16(src, pos + 32).int
      fileDiskNumber = read16(src, pos + 34).int
      # internalFileAttr = read16(src, pos + 36)
      externalFileAttr = read32(src, pos + 38)
      fileHeaderOffset = read32(src, pos + 42).int

    if compressionMethod notin [0.uint16, 8]:
      raise newException(ZippyError, "Unsupported archive, compression method")

    if fileDiskNumber != 0:
      raise newException(ZippyError, "Invalid file disk number")

    pos += 46

    if pos + fileNameLen > result.memFile.size:
      failEOF()

    var fileName = newString(fileNameLen)
    copyMem(fileName[0].addr, src[pos].addr, fileNameLen)

    if fileName in result.records:
      raise newException(ZippyError, "Unsupported archive, duplicate entry")

    pos += fileNameLen + extraFieldLen + fileCommentLen

    if pos > centralDirectoryStart + centralDirectorySize:
      raise newException(ZippyError, "Invalid central directory size")

    let utf8FileName =
      if (generalPurposeFlag and 0b100000000000) != 0:
        # Language encoding flag (EFS) set, assume utf-8
        fileName
      else:
        fileName.utf8ify()

    let
      dosDirectoryFlag = (externalFileAttr and 0x10) != 0
      unixDirectoryFlag = (externalFileAttr and (S_IFDIR.uint32 shl 16)) != 0
      recordKind =
        if dosDirectoryFlag or unixDirectoryFlag:
          DirectoryRecord
        else:
          FileRecord

    result.records[utf8FileName] = ZipArchiveRecord(
      kind: recordKind,
      fileHeaderOffset: fileHeaderOffset,
      path: utf8FileName,
      compressedSize: compressedSize,
      uncompressedSize: uncompressedSize,
      uncompressedCrc32: uncompressedCrc32,
      filePermissions: parseFilePermissions(externalFileAttr)
    )

proc extractAll*(
  zipPath, dest: string
) {.raises: [IOError, OSError, ZippyError].} =
  ## Extracts the files stored in archive to the destination directory.
  ## The path to the destination directory must exist.
  ## The destination directory itself must not exist (it is not overwitten).
  if dest == "" or dirExists(dest):
    raise newException(ZippyError, "Destination " & dest & " already exists")

  var (head, tail) = splitPath(dest)
  if tail == "": # For / at end of path
    (head, tail) = splitPath(head)
  if head != "" and not dirExists(head):
    raise newException(ZippyError, "Path to " & dest & " does not exist")

  let
    reader = openZipArchive(zipPath)
    src = cast[ptr UncheckedArray[uint8]](reader.memFile.mem)

  # Verify some things before attempting to write the files
  for _, record in reader.records:
    if record.path.isAbsolute():
      raise newException(ZippyError, "Absolute path not allowed " & record.path)

    if record.path.startsWith("../") or record.path.startsWith(r"..\"):
      raise newException(ZippyError, "Path ../ not allowed " & record.path)

    if "/../" in record.path or r"\..\" in record.path:
      raise newException(ZippyError, "Path /../ not allowed " & record.path)

  try:
    # Create the directories and write the extracted files
    for _, record in reader.records:
      case record.kind:
      of DirectoryRecord:
        createDir(dest / record.path)
      of FileRecord:
        createDir(dest / splitFile(record.path).dir)
        writeFile(dest / record.path, reader.extractFile(record.path))
        setFilePermissions(dest / record.path, record.filePermissions)

    # Set last modification time as a second pass otherwise directories get
    # updated last modification times as files are added.
    for _, record in reader.records:
      let
        lastModifiedTime = read16(src, record.fileHeaderOffset + 10)
        lastModifiedDate = read16(src, record.fileHeaderOffset + 12)
        lastModified = parseMsDosDateTime(lastModifiedTime, lastModifiedDate)
      setLastModificationTime(dest / record.path, lastModified)

  # If something bad happens delete the destination directory to avoid leaving
  # an incomplete extract.
  except IOError as e:
    removeDir(dest)
    raise e
  except OSError as e:
    removeDir(dest)
    raise e
  except ZippyError as e:
    removeDir(dest)
    raise e
  finally:
    reader.close()
