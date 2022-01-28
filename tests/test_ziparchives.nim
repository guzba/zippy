import std/os, zippy/ziparchives

removeDir("test_tmp")

createDir("test_tmp")
extractAll("tests/data/ziparchives/nim-1.6.2_x64.zip", "test_tmp/zippy")

createDir("test_tmp/gold")
when defined(windows) or defined(macosx):
  let cmd = "tar -xf tests/data/ziparchives/nim-1.6.2_x64.zip -C test_tmp/gold"
else:
  let cmd = "unzip tests/data/ziparchives/nim-1.6.2_x64.zip -d test_tmp/gold"
doAssert execShellCmd(cmd) == 0

for path in walkDirRec("test_tmp/tar", relative = true):
  let
    goldPath = "test_tmp/gold" / path
    zippyPath = "test_tmp/zippy" / path

  if dirExists(goldPath):
    doAssert dirExists(zippyPath)
  else:
    doAssert fileExists(zippyPath)
    doAssert readFile(goldPath) == readFile(zippyPath)

  doAssert getFilePermissions(goldPath) == getFilePermissions(zippyPath)
  doAssert getLastModificationTime(goldPath) == getLastModificationTime(zippyPath)
