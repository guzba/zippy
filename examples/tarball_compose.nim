import tables, zippy/tarballs

# Compose a tarball by manually adding entries and then write it out.

let tarball = Tarball()
tarball.contents["file.txt"] = TarballEntry(
  contents: "text file contents"
)
tarball.contents["fireworks.jpg"] = TarballEntry(
  contents: readFile("tests/data/fireworks.jpg")
)
tarball.writeTarball("composed.tar.gz")
