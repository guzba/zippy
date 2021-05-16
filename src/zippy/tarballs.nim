import os, random, strutils, tables, times, zippy, zippy/common,
    zippy/zippyerror, streams

export zippyerror

type
  EntryKind* = enum
    ekNormalFile = '0',
    ekDirectory = '5'

  TarballEntry* = object
    kind*: EntryKind
    contents*: string
    lastModified*: times.Time

  Tarball* = ref object
    contents*: OrderedTable[string, TarballEntry]

proc addDir(tarball: Tarball, base, relative: string) =
  if relative.len > 0 and relative notin tarball.contents:
    tarball.contents[relative.toUnixPath()] = TarballEntry(kind: ekDirectory)

  for kind, path in walkDir(base / relative, relative = true):
    case kind:
    of pcFile:
      tarball.contents[(relative / path).toUnixPath()] = TarballEntry(
        kind: ekNormalFile,
        contents: readFile(base / relative / path),
        lastModified: getLastModificationTime(base / relative / path)
      )
    of pcDir:
      tarball.addDir(base, relative / path)
    else:
      discard

proc addDir*(tarball: Tarball, dir: string) =
  ## Recursively adds all of the files and directories inside dir to tarball.
  if splitFile(dir).ext.len > 0:
    raise newException(
      ZippyError,
      "Error adding dir " & dir & " to tarball, appears to be a file?"
    )

  let (head, tail) = splitPath(dir)
  tarball.addDir(head, tail)

proc clear*(tarball: Tarball) =
  tarball.contents.clear()

template failEOF() =
  raise newException(
    ZippyError, "Attempted to read past end of file, corrupted tarball?"
  )

type
  TarFormat = enum
    tfUnk, tfTar, tfTgz,tfLzw, tfLzh, tfXz

proc guessTarFormat(fname:string):TarFormat =
  #[
  Position: 0
  1F 8B: .tgz
  1F 9D: tar.z (tar zip) Lempel-Ziv-Welch 
  1F a0: tar.z (tar zip) LZH
  FD 37 7A 58 5A 00: .tar.xz

  Position 0x101:
  75 73 74 61 72 00 30 30: 0x101 (tar)
  75 73 74 61 72 20 20 00: 0x101 (tar)  
  ]#
  let fs = newFileStream(fname, fmRead)
  defer: fs.close

  var buffer: array[8, uint8]
  discard fs.readData(buffer.addr, 6)
  #let n1 = fs.readUint8
  if  buffer[0] == 0x1F:
    case buffer[1]:
    of 0x8B: return tfTgz
    of 0x9D: return tfLzw
    of 0xA0: return tfLzh
    else:    return tfUnk
  
  elif buffer[0 .. 5] == [0xFD'u8,0x37, 0x7A, 0x58, 0x5A, 0x00]:
    return tfXz
  
  fs.setPosition(0x101)
  discard fs.readData(buffer.addr, 8)  
  if buffer == [0x75'u8, 0x73, 0x74, 0x61, 0x72, 0x00, 0x30, 0x30] or
     buffer == [0x75'u8, 0x73, 0x74, 0x61, 0x72, 0x20, 0x20, 0x00]:
    return tfTar
  
  else:
    return tfUnk

proc open*(tarball: Tarball, path: string) =
  ## Opens the tarball file located at path and reads its contents into
  ## tarball.contents (clears any existing tarball.contents entries).
  ## Supports .tar, .tar.gz, .taz and .tgz file extensions.

  tarball.clear()

  proc trim(s: string): string =
    for i in 0 ..< s.len:
      if s[i] == '\0':
        return s[0 ..< i]
    s

  let
    ext = splitFile(path).ext
    # Using magic number instead of extension
    fileFormat = guessTarFormat(path)
    data =
      case fileFormat:
      of tfTar:
        readFile(path)
      of tfTgz: #".gz", ".taz", ".tgz":
        # Tarball compressed using gzip
        uncompress(readFile(path), dfGzip)
      else:
        raise newException(ZippyError, "Unsupported tarball extension " & ext)

  var pos: int
  while pos < data.len:
    if pos + 512 > data.len:
      failEOF()

    let
      header = data[pos ..< pos + 512]
      fileName = header[0 ..< 100].trim()

    pos += 512

    if fileName.len == 0:
      continue

    let
      fileSize =
        try:
          parseOctInt(header[124 .. 134])
        except ValueError:
          raise newException(
            ZippyError, "Unexpected error while opening tarball"
          )
      typeFlag = header[156]
      fileNamePrefix =
        if header[257 ..< 263] == "ustar\0":
          header[345 ..< 500].trim()
        else:
          ""

    if pos + fileSize > data.len:
      failEOF()

    if typeFlag == '0' or typeFlag == '\0':
      tarball.contents[(fileNamePrefix / fileName).toUnixPath()] =
        TarballEntry(
          kind: ekNormalFile,
          contents: data[pos ..< pos + fileSize]
        )
    elif typeFlag == '5':
      tarball.contents[(fileNamePrefix / fileName).toUnixPath()] =
        TarballEntry(
          kind: ekDirectory
        )

    # Move pos by fileSize, where fileSize is 512 byte aligned
    pos += (fileSize + 511) and not 511

proc writeTarball*(tarball: Tarball, path: string) =
  ## Writes tarball.contents to a tarball file at path. Uses the path's file
  ## extension to determine the tarball format. Supports .tar, .tar.gz, .taz
  ## and .tgz file extensions.

  if tarball.contents.len == 0:
    raise newException(ZippyError, "Tarball has no contents")

  var data = ""

  for path, entry in tarball.contents:
    if path.len >= 100:
      raise newException(
        ZippyError,
        "File names >= 100 characters long are currently unsupported"
      )

    var header = newStringOfCap(512)
    header.add(path)
    header.setLen(100)
    header.add("000777 \0") # File mode
    header.add(toOct(0, 6) & " \0") # Owner's numeric user ID
    header.add(toOct(0, 6) & " \0") # Group's numeric user ID
    header.add(toOct(entry.contents.len, 11) & ' ') # File size
    header.add(toOct(entry.lastModified.toUnix(), 11) & ' ') # Last modified time
    header.add("        ") # Empty checksum for now
    header.setLen(156)
    header.add(ord(entry.kind).char)
    header.setLen(257)
    header.add("ustar\0") # UStar indicator
    header.add(toOct(0, 2)) # UStar version
    header.setLen(329)
    header.add(toOct(0, 6) & "\0 ") # Device major number
    header.add(toOct(0, 6) & "\0 ") # Device minor number
    header.setLen(512)

    var checksum: int
    for i in 0 ..< header.len:
      checksum += header[i].int

    let checksumStr = toOct(checksum, 6) & '\0'
    for i in 0 ..< checksumStr.len:
      header[148 + i] = checksumStr[i]

    data.add(header)
    data.add(entry.contents)
    data.setLen((data.len + 511) and not 511) # 512 byte aligned

  data.setLen(data.len + 1024) # Two consecutive zero-filled records at end

  let ext = splitFile(path).ext
  case ext:
  of ".tar":
    writeFile(path, data)
  of ".gz", ".taz", ".tgz":
    # Tarball compressed using gzip
    writeFile(path, compress(data, DefaultCompression, dfGzip))
  else:
    raise newException(ZippyError, "Unsupported tarball extension " & ext)

proc extractAll*(tarball: Tarball, dest: string) =
  ## Extracts the files stored in tarball to the destination directory.
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

  let tmpDir = getTempDir() / "tarball_" & randomString(10)
  removeDir(tmpDir)
  createDir(tmpDir)

  for path, entry in tarball.contents:
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
    of ekNormalFile:
      createDir(tmpDir / splitFile(path).dir)
      writeFile(tmpDir / path, entry.contents)
      if entry.lastModified > Time():
        setLastModificationTime(tmpDir / path, entry.lastModified)
    of ekDirectory:
      createDir(tmpDir / path)

  moveDir(tmpDir, dest)

proc extractAll*(tarPath, dest: string) =
  ## Extracts the files in the tarball located at tarPath into the destination
  ## directory. Supports .tar, .tar.gz, .taz and .tgz file extensions.
  let tarball = Tarball()
  tarball.open(tarPath)
  tarball.extractAll(dest)

proc createTarball*(source, dest: string) =
  ## Creates a tarball containing all of the files and directories inside
  ## source and writes the tarball file to dest. Uses the dest path's file
  ## extension to determine the tarball format. Supports .tar, .tar.gz, .taz
  ## and .tgz file extensions.
  let tarball = Tarball()
  tarball.addDir(source)
  tarball.writeTarball(dest)
