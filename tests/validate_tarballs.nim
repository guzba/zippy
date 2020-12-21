import tables, untar, zippy/tarballs

proc trim(s: string): string =
  for i in 0 ..< s.len:
    if s[i] == '\0':
      return s[0 ..< i]
  s

let tarball = Tarball()
tarball.addDir("tests/data")
tarball.writeTarball("tmp/tarball.tar")

tarball.open("tmp/tarball.tar")

let tarFile = newTarFile("tmp/tarball.tar")

for info, contents in tarFile.walk:
  doAssert tarball.contents[info.filename.trim()].contents == contents
