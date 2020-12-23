import os, tables, zippy/tarballs

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

block: # .tar
  let tarball = Tarball()
  tarball.open("tests/data/tarballs/dir.tar")

  for path, entry in tarball.contents:
    if entry.kind == NormalFile:
      doAssert readFile("tests/data/" & splitPath(path).tail) == entry.contents

block: # .tar.gz
  let tarball = Tarball()
  tarball.open("tests/data/tarballs/dir.tar.gz")

  for path, entry in tarball.contents:
    if entry.kind == NormalFile:
      doAssert readFile("tests/data/" & splitPath(path).tail) == entry.contents

block:
  let tarball = Tarball()
  tarball.open("tests/data/tarballs/Nim-1.4.2.tar.gz")

  var i: int
  for path, entry in tarball.contents:
    inc i
  doAssert i == 3026

  removeDir("tmp/tarballs")
  createDir("tmp")
  tarball.extractAll("tmp/tarballs")

  for path, entry in tarball.contents:
    if entry.kind == Directory:
      doAssert dirExists("tmp/tarballs" / path)
    else:
      doAssert fileExists("tmp/tarballs" / path)
