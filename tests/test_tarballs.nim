import std/os, std/strformat, zippy/tarballs

block:
  let testFilePaths = [
    # "tests/data/tarballs/Nim-1.6.2.tar.gz",
    "tests/data/tarballs/libressl-3.4.2.tar.gz"
  ]

  for testFilePath in testFilePaths:
    removeDir("tmp/tar")
    createDir("tmp/tar")

    extractAll(testFilePath, "tmp/tar/zippy")

    createDir("tmp/tar/gold")
    let cmd = &"tar -xf {testFilePath} -C tmp/tar/gold"
    doAssert execShellCmd(cmd) == 0

    for path in walkDirRec(
      "tmp/tar/gold",
      yieldFilter = {pcFile, pcDir, pcLinkToFile, pcLinkToDir},
      relative = true
    ):
      let
        goldPath = "tmp/tar/gold" / path
        zippyPath = "tmp/tar/zippy" / path

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

    removeDir("tmp/tar")
    createDir("tmp/tar")

    extractAll(testFilePath, "tmp/tar/zippy")

    createDir("tmp/tar/gold")
    let cmd = &"tar -xf {testFilePath} -C tmp/tar/gold"
    doAssert execShellCmd(cmd) == 0

    for path in walkDirRec(
      "tmp/tar/gold",
      yieldFilter = {pcFile, pcDir, pcLinkToFile, pcLinkToDir},
      relative = true
    ):
      let
        goldPath = "tmp/tar/gold" / path
        zippyPath = "tmp/tar/zippy" / path

      if dirExists(goldPath):
        doAssert dirExists(zippyPath)
      elif symlinkExists(goldPath):
        doAssert symlinkExists(zippyPath)
        doAssert expandSymlink(goldPath) == expandSymlink(zippyPath)
      else:
        doAssert fileExists(zippyPath)
        doAssert readFile(goldPath) == readFile(zippyPath)

    removeDir("tmp/tar")
