import zippy/tarballs, os

# Extracts all of the files and directories in the tarball into output/dir.

createDir("output") # Ensure the path to the output dir exists
extractTarball("tests/data/tarballs/Nim-1.4.2.tar.gz", "output/dir")
