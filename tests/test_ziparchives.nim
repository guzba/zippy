import std/os, zippy/ziparchives

removeDir("tmp/zip")

createDir("tmp/zip")
extractAll("tests/data/ziparchives/nim-1.6.2_x64.zip", "tmp/zip/zippy")

createDir("tmp/zip/gold")
when defined(windows) or defined(macosx):
  let cmd = "tar -xf tests/data/ziparchives/nim-1.6.2_x64.zip -C tmp/zip/gold"
else:
  let cmd = "unzip tests/data/ziparchives/nim-1.6.2_x64.zip -d tmp/zip/gold"
doAssert execShellCmd(cmd) == 0

for path in walkDirRec(
  "tmp/zip/gold",
  yieldFilter = {pcFile, pcDir},
  relative = true
):
  let
    goldPath = "tmp/zip/gold" / path
    zippyPath = "tmp/zip/zippy" / path

  if dirExists(goldPath):
    doAssert dirExists(zippyPath)
  else:
    doAssert fileExists(zippyPath)
    doAssert readFile(goldPath) == readFile(zippyPath)

  doAssert getFilePermissions(goldPath) == getFilePermissions(zippyPath)
  doAssert getLastModificationTime(goldPath) == getLastModificationTime(zippyPath)

removeDir("tmp/zip")
