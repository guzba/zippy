import benchy, tables, untar, zippy/tarballs

timeIt "untar":
  let tarFile = newTarFile("tests/data/tarballs/Nim-1.4.2.tar.gz")

  var i: int
  for info, contents in tarFile.walk:
    inc i
  keep i

timeIt "zippy":
  let tarball = Tarball()
  tarball.open("tests/data/tarballs/Nim-1.4.2.tar.gz")

  var i: int
  for path, entry in tarball.contents:
    inc i
  keep i
