import zippy/tarballs



# import os, streams, strformat, tables, zippy/tarballs

# proc testTempDir(): string =
#   when defined(windows):
#     getHomeDir() / r"AppData\Local\Temp" / "tarballs"
#   else:
#     getTempDir() / "tarballs"

# block:
#   let tarball = Tarball()
#   tarball.open("tests/data/tarballs/basic.tar.gz")

#   removeDir(testTempDir())

#   tarball.extractAll(testTempDir())

#   for path, entry in tarball.contents:
#     if entry.kind == ekNormalFile:
#       doAssert fileExists(testTempDir() / path)
#       doAssert readFile("tests/data/" & path) == entry.contents
#     else:
#       doAssert dirExists(testTempDir() / path)

# block:
#   let tarball = Tarball()
#   tarball.addDir("src/")

#   removeDir(testTempDir())

#   tarball.extractAll(testTempDir())

#   for path, entry in tarball.contents:
#     if entry.kind == ekNormalFile:
#       doAssert fileExists(testTempDir() / path)
#       doAssert readFile("src/" & path) == entry.contents
#     else:
#       doAssert dirExists(testTempDir() / path)

# block: # .tar
#   let tarball = Tarball()
#   tarball.open("tests/data/tarballs/basic.tar")

#   for path, entry in tarball.contents:
#     doAssert readFile("tests/data/" & path) == entry.contents

# block: # .tar.gz
#   let tarball = Tarball()
#   tarball.open("tests/data/tarballs/basic.tar.gz")

#   for path, entry in tarball.contents:
#     doAssert readFile("tests/data/" & path) == entry.contents

# block: # .tar
#   let tarball = Tarball()
#   tarball.open("tests/data/tarballs/dir.tar")

#   for path, entry in tarball.contents:
#     if entry.kind == ekNormalFile:
#       doAssert readFile("tests/data/" & splitPath(path).tail) == entry.contents

# block: # .tar.gz
#   let tarball = Tarball()
#   tarball.open("tests/data/tarballs/dir.tar.gz")

#   for path, entry in tarball.contents:
#     if entry.kind == ekNormalFile:
#       doAssert readFile("tests/data/" & splitPath(path).tail) == entry.contents

# block: # .tar
#   let fs = newFileStream("tests/data/tarballs/dir.tar")
#   defer: fs.close()

#   let tarball = Tarball()
#   tarball.open(fs) # tfDetect

#   for path, entry in tarball.contents:
#     if entry.kind == ekNormalFile:
#       doAssert readFile("tests/data/" & splitPath(path).tail) == entry.contents

# block: # .tar.gz
#   let fs = newFileStream("tests/data/tarballs/dir.tar.gz")
#   defer: fs.close()

#   let tarball = Tarball()
#   tarball.open(fs) # tfDetect

#   for path, entry in tarball.contents:
#     if entry.kind == ekNormalFile:
#       doAssert readFile("tests/data/" & splitPath(path).tail) == entry.contents

# block: # permissions
#   let tarball = Tarball()
#   tarball.open("tests/data/tarballs/permissions.tgz")

#   let tmpdir = testTempDir()
#   removeDir(tmpdir)
#   createDir(tmpdir)

#   let
#     tmpdir_a = tmpdir / "zippy"
#     tmpdir_b = tmpdir / "tar"

#   # use zippy
#   tarball.extractAll(tmpdir_a)

#   # use tar
#   createDir(tmpdir_b)
#   doAssert execShellCmd(&"tar xf tests/data/tarballs/permissions.tgz -C {tmpdir_b}") == 0
#   doAssert dirExists(tmpdir_b)

#   # compare the two
#   for path in walkDirRec(tmpdir_b, relative = true):
#     doAssert getFilePermissions(tmpdir_a / path) == getFilePermissions(tmpdir_b / path), "Permissions didn't match for " & path

# # block:
# #   let tarball = Tarball()
# #   tarball.addDir("tests/data/tarballs/longpath")

# #   doAssert tarball.contents.len == 3

# #   tarball.writeTarball("tmp/tb.tar")

# # block:
# #   removeFile("examples.tar.gz")
# #   removeFile("tmp_tarball1.tar.gz")
# #   removeDir("tmp_tarball1/")
# #   removeDir("tmp_tarball2/")
# #   createTarball("examples/", "examples.tar.gz")
# #   extractAll("examples.tar.gz", "tmp_tarball1/")

# #   for (kind, path) in walkDir("tmp_tarball1"):
# #     doAssert kind == pcFile
# #     doAssert readFile("examples/" & splitPath(path).tail) == readFile(path)

# #   createTarball("tmp_tarball1/", "tmp_tarball1.tar.gz")
# #   extractAll("tmp_tarball1.tar.gz", "tmp_tarball2/")

# #   for (kind, path) in walkDir("tmp_tarball2"):
# #     doAssert kind == pcFile
# #     doAssert readFile("tmp_tarball1/" & splitPath(path).tail) == readFile(path)

# # block:
# #   let tarball = Tarball()
# #   tarball.open("tests/data/tarballs/Nim-1.4.2.tar.gz")

# #   var i: int
# #   for path, entry in tarball.contents:
# #     inc i
# #   doAssert i == 3026

# #   removeDir("tmp/tarballs")
# #   createDir("tmp")
# #   tarball.extractAll("tmp/tarballs")

# #   for path, entry in tarball.contents:
# #     if entry.kind == ekDirectory:
# #       doAssert dirExists("tmp/tarballs" / path)
# #     else:
# #       doAssert fileExists("tmp/tarballs" / path)
