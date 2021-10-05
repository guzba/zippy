import os, tables, zippy/ziparchives

proc testTempDir(): string =
  when defined(windows):
    getHomeDir() / r"AppData\Local\Temp" / "ziparchives"
  else:
    getTempDir() / "ziparchives"

block:
  let archive = ZipArchive()
  archive.open("tests/data/ziparchives/basic.zip")

  removeDir(testTempDir())

  archive.extractAll(testTempDir())

  for path, entry in archive.contents:
    if entry.kind == ekFile:
      doAssert fileExists(testTempDir() / path)
      doAssert readFile("tests/data/" & path) == entry.contents
    else:
      doAssert dirExists(testTempDir() / path)

block:
  let archive = ZipArchive()
  archive.addDir("src/")

  removeDir(testTempDir())

  archive.extractAll(testTempDir())

  for path, entry in archive.contents:
    if entry.kind == ekFile:
      doAssert fileExists(testTempDir() / path)
      doAssert readFile("src/" & path) == entry.contents
    else:
      doAssert dirExists(testTempDir() / path)

block:
  let archive = ZipArchive()
  archive.open("tests/data/ziparchives/permissions.zip")

  let tmpdir = testTempDir()
  removeDir(tmpdir)

  archive.extractAll(tmpdir)
  doAssert fileExists(tmpdir/"tmp"/"script.sh")
  doassert fpUserExec in getFilePermissions(tmpdir/"tmp"/"script.sh")
