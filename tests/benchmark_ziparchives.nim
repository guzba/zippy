import benchy, tables, zippy/ziparchives

timeIt "zippy":
# for i in 0 ..< 100:
  let archive = ZipArchive()
  archive.open("tests/data/ziparchives/Nim-1.4.2.zip")

  var i: int
  for path, entry in archive.contents:
    inc i
  keep i
