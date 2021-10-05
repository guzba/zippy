import os, strformat, tables, zippy/ziparchives

proc testTempDir(): string =
  when defined(windows):
    getHomeDir() / r"AppData\Local\Temp" / "ziparchives"
  else:
    getTempDir() / "ziparchives"

# block:
#   let archive = ZipArchive()
#   archive.open("tests/data/ziparchives/basic.zip")

#   removeDir(testTempDir())

#   archive.extractAll(testTempDir())

#   for path, entry in archive.contents:
#     if entry.kind == ekFile:
#       doAssert fileExists(testTempDir() / path)
#       doAssert readFile("tests/data/" & path) == entry.contents
#     else:
#       doAssert dirExists(testTempDir() / path)

# block:
#   let archive = ZipArchive()
#   archive.addDir("src/")

#   removeDir(testTempDir())

#   archive.extractAll(testTempDir())

#   for path, entry in archive.contents:
#     if entry.kind == ekFile:
#       doAssert fileExists(testTempDir() / path)
#       doAssert readFile("src/" & path) == entry.contents
#     else:
#       doAssert dirExists(testTempDir() / path)

block:
  let archive = ZipArchive()
  archive.open("tests/data/ziparchives/permissions.zip")

  let tmpdir = testTempDir()
  removeDir(tmpdir)
  createDir(tmpdir)

  let
    tmpdir_a = tmpdir / "zippy"
    tmpdir_b = tmpdir / "unzip"

  # use zippy
  archive.extractAll(tmpdir_a)

  # use zip
  createDir(tmpdir_b)
  doAssert execShellCmd(&"unzip tests/data/ziparchives/permissions.zip -d {tmpdir_b}") == 0
  doAssert dirExists(tmpdir_b)

  # compare the two
  for path in walkDirRec(tmpdir_b, relative = true):
    doAssert getFilePermissions(tmpdir_a / path) == getFilePermissions(tmpdir_b / path), "Permissions didn't match for " & path
