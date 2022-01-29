import tarballs_v1

export tarballs_v1

proc extractAll*(
  tarPath, dest: string
) {.raises: [IOError, OSError, ZippyError].} =
  discard
