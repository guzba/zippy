import std/os, zippy/ziparchives, std/tables

const testDir = getTempDir() # "tmp/zip"

let
  goldDir = testDir / "gold"
  zippyDir = testDir / "zippy"

removeDir(goldDir)
removeDir(zippyDir)

extractAll("tests/data/ziparchives/Bagnon-10.2.31.zip", zippyDir)

when not defined(macosx):
  createDir(goldDir)
  when defined(windows):
    let cmd = "tar -xf tests/data/ziparchives/Bagnon-10.2.31.zip -C " & goldDir
  else:
    let cmd = "unzip tests/data/ziparchives/Bagnon-10.2.31.zip -d " & goldDir
  doAssert execShellCmd(cmd) == 0

  for path in walkDirRec(
    goldDir,
    yieldFilter = {pcFile, pcDir},
    relative = true
  ):
    let
      goldPath = goldDir / path
      zippyPath = zippyDir / path

    if dirExists(goldPath):
      doAssert dirExists(zippyPath)
    else:
      doAssert fileExists(zippyPath)
      doAssert readFile(goldPath) == readFile(zippyPath)

    # doAssert getFilePermissions(goldPath) == getFilePermissions(zippyPath)
    # doAssert getLastModificationTime(goldPath) == getLastModificationTime(zippyPath)

block: # Test zip archive concatenated to the end of another file
  let
    archive = openZipArchive("tests/data/ziparchives/cat.jpg")
    entries = ["a.txt", "b.txt", "c.txt"]
  var numEntries: int
  for entry in archive.walkFiles:
    doAssert entry == entries[numEntries]
    inc numEntries
  doAssert numEntries == 3

block:
  let archive = ZipArchive()
  archive.addFile("tests/data/ziparchives/cat.jpg")

  let
    fromZip = archive.contents["cat.jpg"].contents
    fromDisk = readFile("tests/data/ziparchives/cat.jpg")
  doAssert fromZip == fromDisk

  try:
    archive.addFile("tests/data/ziparchives/")
  except:
    let e = getCurrentException()
    doAssert e.msg == "Error adding file tests/data/ziparchives/ to archive, appears to be a directory?"
