import os, zippy/tarballs

# Extracts all of the files and directories in the tarball into output/dir.

createDir("output") # Ensure the path to the output dir exists
extractAll("tests/data/tarballs/Nim-1.4.2.tar.gz", "output/dir")
