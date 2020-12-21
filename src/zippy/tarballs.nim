import os, random, strutils, tables, times, zippy, zippy/common,
    zippy/zippyerror

type
  EntryKind* = enum
    NormalFile = '0',
    Directory = '5'

  TarballEntry* = object
    kind*: EntryKind
    contents*: string
    lastModified*: times.Time

  Tarball* = ref object
    contents*: OrderedTable[string, TarballEntry]

proc addDir(tarball: Tarball, base, relative: string) =
  if relative.len > 0 and relative notin tarball.contents:
    tarball.contents[relative] = TarballEntry(kind: Directory)

  for kind, path in walkDir(base / relative, relative = true):
    case kind:
    of pcFile:
      tarball.contents[relative / path] = TarballEntry(
        kind: NormalFile,
        contents: readFile(base / relative / path),
        lastModified: getLastModificationTime(base / relative / path)
      )
    of pcDir:
      tarball.addDir(base, relative / path)
    else:
      discard

proc addDir*(tarball: Tarball, dir: string) =
  ## Recursively adds all of the files and directories inside dir to tarball.
  let (head, tail) = splitPath(dir)
  tarball.addDir(head, tail)

template failEOF() =
  raise newException(
    ZippyError, "Attempted to read past end of file, corrupted tarball?"
  )

proc open*(tarball: Tarball, path: string) =
  ## Opens the tarball file located at path and reads its contents into
  ## tarball.contents (clears any existing tarball.contents entries).
  ## Supports .tar, .tar.gz, .taz and .tgz file extensions.

  tarball.contents.clear()

  proc trim(s: string): string =
    for i in 0 ..< s.len:
      if s[i] == '\0':
        return s[0 ..< i]
    s

  let
    ext = splitFile(path).ext
    data =
      case ext:
      of ".tar":
        readFile(path)
      of ".gz", ".taz", ".tgz":
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

    if typeFlag == '0' or typeFlag == '5':
      tarball.contents[fileNamePrefix / fileName] = TarballEntry(
        kind: EntryKind(typeFlag),
        contents: data[pos ..< pos + fileSize]
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
  if not dirExists(splitPath(dest).head):
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
    of NormalFile:
      createDir(tmpDir / splitFile(path).dir)
      writeFile(tmpDir / path, entry.contents)
    of Directory:
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
