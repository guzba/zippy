import benchy, std/tables, zippy/ziparchives

timeIt "zippy":
  let archive = ZipArchive()
  archive.open("tests/data/ziparchives/Nim-1.6.6.zip")

  var i: int
  for path, entry in archive.contents:
    inc i
