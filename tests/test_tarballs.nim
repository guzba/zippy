import std/os, std/strformat, zippy/tarballs

let testDir = getTempDir()

block:
  let testFilePaths = [
    "tests/data/tarballs/libressl-3.4.2.tar.gz"
  ]

  for i, testFilePath in testFilePaths:
    let
      goldDir = testDir / "gold" & $i
      zippyDir = testDir / "zippy" & $i

    removeDir(goldDir)
    removeDir(zippyDir)

    extractAll(testFilePath, zippyDir)

    createDir(goldDir)
    let cmd = &"tar -xf {testFilePath} -C " & goldDir
    doAssert execShellCmd(cmd) == 0

    for path in walkDirRec(
      goldDir,
      yieldFilter = {pcFile, pcDir, pcLinkToFile, pcLinkToDir},
      relative = true
    ):
      let
        goldPath = goldDir / path
        zippyPath = zippyDir / path

      if dirExists(goldPath):
        doAssert dirExists(zippyPath)
      else:
        when defined(windows):
          # tar on Windows creates this monster, zippy handles this file correctly
          if path == "Nim-1.6.2\\tests\\misc\\\226\148\156\195\145\226\148\156\195\177\226\148\156\226\149\162.nim":
            continue
        doAssert fileExists(zippyPath)
        doAssert readFile(goldPath) == readFile(zippyPath)

when not defined(windows):
  block:
    let testFilePath = "tests/data/tarballs/julia-1.7.1.tar.gz"

    let
      goldDir = testDir / "julia_gold"
      zippyDir = testDir / "julia_zippy"

    removeDir(goldDir)
    removeDir(zippyDir)

    extractAll(testFilePath, zippyDir)

    createDir(goldDir)
    let cmd = &"tar -xf {testFilePath} -C " & goldDir
    doAssert execShellCmd(cmd) == 0

    for path in walkDirRec(
      goldDir,
      yieldFilter = {pcFile, pcDir, pcLinkToFile, pcLinkToDir},
      relative = true
    ):
      let
        goldPath = goldDir / path
        zippyPath = zippyDir / path

      if dirExists(goldPath):
        doAssert dirExists(zippyPath)
      elif symlinkExists(goldPath):
        doAssert symlinkExists(zippyPath)
        doAssert expandSymlink(goldPath) == expandSymlink(zippyPath)
      else:
        doAssert fileExists(zippyPath)
        doAssert readFile(goldPath) == readFile(zippyPath)
