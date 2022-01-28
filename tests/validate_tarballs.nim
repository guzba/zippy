import std/os, std/tables, untar, zippy/internal, zippy/tarballs

proc trim(s: string): string =
  for i in 0 ..< s.len:
    if s[i] == '\0':
      return s[0 ..< i]
  s

createDir("tmp")

let tarball = Tarball()
tarball.addDir("tests/data")
tarball.writeTarball("tmp/tarball.tar")

tarball.open("tmp/tarball.tar")

let tarFile = newTarFile("tmp/tarball.tar")

for info, contents in tarFile.walk:
  let path = info.filename.trim().toUnixPath()
  doAssert tarball.contents[path].contents == contents
