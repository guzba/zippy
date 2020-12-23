import tables, zippy/ziparchives

# Compose a zip archive by manually adding entries and then write it out.

let archive = ZipArchive()
archive.contents["file.txt"] = ArchiveEntry(
  contents: "text file contents"
)
archive.contents["fireworks.jpg"] = ArchiveEntry(
  contents: readFile("tests/data/fireworks.jpg")
)
archive.writeZipArchive("composed.zip")
