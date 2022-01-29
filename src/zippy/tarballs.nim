import common, std/memfiles, tarballs_v1

export common, tarballs_v1

proc extractAll*(
  tarPath, dest: string
) {.raises: [IOError, OSError, ZippyError].} =
  var memFile = memfiles.open(tarPath)
  try:
    echo memFile.size
  finally:
    memFile.close()
