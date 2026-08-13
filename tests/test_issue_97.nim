import std/os, std/strutils, zippy/tarballs, zippy/ziparchives

# https://github.com/guzba/zippy/issues/97
# A directory whose name contains a period (e.g. `/etc/cron.d`) must not be
# mistaken for a file and rejected: addDir used the filename extension instead
# of checking the filesystem.

proc containsFile(dir, name, contents: string): bool =
  for path in walkDirRec(dir):
    if path.extractFilename == name and readFile(path) == contents:
      return true
  false

block:
  let dir = getTempDir() / "zippy_dotted.d"
  removeDir(dir)
  createDir(dir)
  writeFile(dir / "a.txt", "hello")

  # tarball
  let tarPath = getTempDir() / "zippy_dotted.tar.gz"
  createTarball(dir, tarPath) # must not raise
  doAssert fileExists(tarPath)
  let tarOut = getTempDir() / "zippy_dotted_tar_out"
  removeDir(tarOut)
  tarballs.extractAll(tarPath, tarOut)
  doAssert containsFile(tarOut, "a.txt", "hello")

  # zip
  let zipPath = getTempDir() / "zippy_dotted.zip"
  createZipArchive(dir, zipPath) # must not raise
  doAssert fileExists(zipPath)
  let zipOut = getTempDir() / "zippy_dotted_zip_out"
  removeDir(zipOut)
  ziparchives.extractAll(zipPath, zipOut)
  doAssert containsFile(zipOut, "a.txt", "hello")

  removeDir(dir)
  removeFile(tarPath)
  removeFile(zipPath)
  removeDir(tarOut)
  removeDir(zipOut)

# A real file (or a nonexistent path) is still rejected.
block:
  let file = getTempDir() / "zippy_not_a_dir.txt"
  writeFile(file, "x")
  doAssertRaises ZippyError:
    createTarball(file, getTempDir() / "zippy_not_a_dir.tar.gz")
  removeFile(file)
