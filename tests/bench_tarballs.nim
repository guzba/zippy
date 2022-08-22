import benchy, std/tables, untar, zippy/tarballs

timeIt "untar":
  let tarFile = newTarFile("tests/data/tarballs/julia-1.7.1.tar.gz")

  var i: int
  for info, contents in tarFile.walk:
    inc i

timeIt "zippy":
  let tarball = Tarball()
  tarball.open("tests/data/tarballs/julia-1.7.1.tar.gz")

  var i: int
  for path, entry in tarball.contents:
    inc i
