import os, zippy/tarballs

# Extracts all of the files and directories from the tarball.

createDir("tmp") # Ensure the path to the output dir exists
extractAll("tests/data/tarballs/Nim-1.4.2.tar.gz", "tmp/untarred")
