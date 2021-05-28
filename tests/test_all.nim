import test, test_compiletime, test_levels, test_tarballs

when not defined(windows) or not defined(githubActions):
  # This failed on Windows + Github Actions due to Temp dir access denied.
  import test_ziparchives
