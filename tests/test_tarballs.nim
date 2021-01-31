import os, tables, zippy/tarballs, sequtils

block: # .tar
  let tarball = Tarball()
  tarball.open("tests/data/tarballs/basic.tar")

  for path, entry in tarball.contents:
    doAssert readFile("tests/data/" & path) == entry.contents

block: # .tar.gz
  let tarball = Tarball()
  tarball.open("tests/data/tarballs/basic.tar.gz")

  for path, entry in tarball.contents:
    doAssert readFile("tests/data/" & path) == entry.contents

# block: # .tar
#   let tarball = Tarball()
#   tarball.open("tests/data/tarballs/dir.tar")

#   for path, entry in tarball.contents:
#     if entry.kind == ekNormalFile:
#       doAssert readFile("tests/data/" & splitPath(path).tail) == entry.contents

block: # .tar.gz
  let tarball = Tarball()
  tarball.open("tests/data/tarballs/dir.tar.gz")

  for path, entry in tarball.contents:
    if entry.kind == ekNormalFile:
      doAssert readFile("tests/data/" & splitPath(path).tail) == entry.contents

block: # .tar Creation
  let
    tarball  = Tarball()
    data_loc = "tests/data/"
    cwd      = getCurrentDir()

  data_loc.setCurrentDir

  [
    "alice29.txt",
    "asyoulik.txt",
    "html"
  ].apply(
    proc(x: string) =
      tarball.contents[x] = TarballEntry(
        contents: readFile(x)
      )
  )

  tarball.writeTarball("test_tar.tar")

  cwd.setCurrentDir

block: # .tar Extraction
  let
    tarball  = Tarball()
    data_loc = "tests/data/"
    tar_loc  = "test_tar.tar"
    tmpDir   = "tmp"
    cwd      = getCurrentDir()

  data_loc.setCurrentDir

  tarball.open(tar_loc)

  if tmpDir.dirExists: tmpDir.removeDir
  tarball.extractAll(getCurrentDir() / tmpDir)

  [
    "alice29.txt",
    "asyoulik.txt",
    "html"
  ].apply(
    proc(x: string) =
      for kind, path in tmpDir.walkDir:
        if kind != pcFile: continue
        if path.lastPathPart == x:
          doAssert path.sameFileContent(x)
  )

  discard tryRemoveFile tar_loc

  cwd.setCurrentDir

# block:
#   let tarball = Tarball()
#   tarball.open("tests/data/tarballs/Nim-1.4.2.tar.gz")

#   var i: int
#   for path, entry in tarball.contents:
#     inc i
#   doAssert i == 3026

#   removeDir("tmp/tarballs")
#   createDir("tmp")
#   tarball.extractAll("tmp/tarballs")

#   for path, entry in tarball.contents:
#     if entry.kind == ekDirectory:
#       doAssert dirExists("tmp/tarballs" / path)
#     else:
#       doAssert fileExists("tmp/tarballs" / path)
