{. warning[UnusedImport]:off .}

import
  test_codec,
  test_compiletime,
  test_levels,
  test_tarballs

when not defined(windows):
  # this failed on windows
  # with Error: unhandled exception: Access is denied.
  # ...Appdata\Local\Temp\...
  import
    test_ziparchives
