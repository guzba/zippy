import zippy/tarballs, tables

# Compose a tarball by manually adding entries and then write it out.

let tarball = Tarball()
tarball.contents["file.txt"] = TarballEntry(
  kind: NormalFile,
  contents: "text file contents"
)
tarball.contents["fireworks.jpg"] = TarballEntry(
  kind: NormalFile,
  contents: readFile("tests/data/fireworks.jpg")
)
tarball.writeTarball("composed.tar.gz")
