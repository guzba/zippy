import benchy, std/tables, zippy/ziparchives

timeIt "zippy":
# for i in 0 ..< 100:
  let archive = ZipArchive()
  archive.open("tests/data/ziparchives/nim-1.6.2_x64.zip")

  var i: int
  for path, entry in archive.contents:
    inc i
