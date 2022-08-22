import std/os, zippy/ziparchives

const testDir = getTempDir() # "tmp/zip"

let
  goldDir = testDir / "gold"
  zippyDir = testDir / "zippy"

removeDir(goldDir)
removeDir(zippyDir)

extractAll("tests/data/ziparchives/Nim-1.6.6.zip", zippyDir)

when not defined(macosx):
  createDir(goldDir)
  when defined(windows):
    let cmd = "tar -xf tests/data/ziparchives/Nim-1.6.6.zip -C " & goldDir
  else:
    let cmd = "unzip tests/data/ziparchives/Nim-1.6.6.zip -d " & goldDir
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
