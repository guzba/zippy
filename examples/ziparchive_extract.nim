import os, zippy/ziparchives

# Extracts all of the files and directories from the zip.

createDir("tmp") # Ensure the path to the output dir exists
extractAll("tests/data/ziparchives/Nim-1.4.2.zip", "tmp/unzipped")
