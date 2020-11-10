import zippy

# Example showing how to store data that is compressed at compile time.

# This is convenient for keeping a file in human editable form (text, json)
# while still having it compressed when included in an executable.

const
  storedCompressed = block:
    compress(readFile("tests/data/gzipfiletest.txt"))

echo uncompress(storedCompressed)
