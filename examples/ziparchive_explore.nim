import zippy/ziparchives

# Open the zip archive. This only reads the records metadata,
# it does not read the entire archive into memory.
let reader = openZipArchive("tests/data/ziparchives/nim-1.6.2_x64.zip")

try:
  # Iterate over the paths in the zip archive.
  for path in reader.walkFiles:
    echo path

  # Extract a file from the archive.
  let contents = reader.extractFile("nim-1.6.2/doc/html/os.html")
  echo contents
finally:
  # Remember to close the reader when done.
  reader.close()
