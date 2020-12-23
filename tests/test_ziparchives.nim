import os, tables, zippy/ziparchives

block:
  let archive = ZipArchive()
  archive.open("tests/data/ziparchives/basic.zip")

  removeDir("tmp/ziparchives")
  createDir("tmp")

  archive.extractAll("tmp/ziparchives")

  for path, entry in archive.contents:
    if entry.kind == ekFile:
      doAssert fileExists("tmp/ziparchives" / path)
      doAssert readFile("tests/data/" & path) == entry.contents
    else:
      doAssert dirExists("tmp/ziparchives" / path)

block:
  let archive = ZipArchive()
  archive.addDir("src/")

  removeDir("tmp/ziparchives")
  createDir("tmp")

  archive.extractAll("tmp/ziparchives")

  for path, entry in archive.contents:
    if entry.kind == ekFile:
      doAssert fileExists("tmp/ziparchives" / path)
      doAssert readFile("src/" & path) == entry.contents
    else:
      doAssert dirExists("tmp/ziparchives" / path)
