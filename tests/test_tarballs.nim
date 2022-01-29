import std/os, zippy/tarballs

removeDir("tmp/tar")

createDir("tmp/tar")
extractAll("tests/data/tarballs/Nim-1.6.2.tar.gz", "tmp/tar/zippy")

createDir("tmp/tar/gold")
let cmd = "tar -xf tests/data/ziparchives/nim-1.6.2_x64.zip -C tmp/tar/gold"
doAssert execShellCmd(cmd) == 0

for path in walkDirRec("tmp/tar/gold", relative = true):
  let
    goldPath = "tmp/tar/gold" / path
    zippyPath = "tmp/tar/zippy" / path

  if dirExists(goldPath):
    doAssert dirExists(zippyPath)
  else:
    doAssert fileExists(zippyPath)
    doAssert readFile(goldPath) == readFile(zippyPath)

  doAssert getFilePermissions(goldPath) == getFilePermissions(zippyPath)
  doAssert getLastModificationTime(goldPath) == getLastModificationTime(zippyPath)

removeDir("tmp/tar")
