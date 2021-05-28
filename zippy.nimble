version       = "0.5.7"
author        = "Ryan Oldenburg"
description   = "Pure Nim implementation of deflate, zlib, gzip and zip."
license       = "MIT"

srcDir = "src"

requires "nim >= 1.0.0"

### Helper functions
proc test(env, path: string) =
  # Compilation language is controlled by TEST_LANG
  var lang = "c"
  if existsEnv"TEST_LANG":
    lang = getEnv"TEST_LANG"

  if not dirExists "build":
    mkDir "build"

  exec "nim " & lang & " " & env &
    " -r --hints:off --warnings:off " & path

task test, "Run all tests":
  test "-d:debug", "tests/test_all"
  test "-d:release", "tests/test_all"
  test "--threads:on -d:release", "tests/test_all"
  test "-d:release --gc:orc", "tests/test_all"
  test "-d:release --gc:arc", "tests/test_all"

task testvcc, "Run all tests with vcc compiler":
  test "--cc:vcc -d:debug", "tests/test_all"
  test "--cc:vcc -d:release", "tests/test_all"
  test "--cc:vcc --threads:on -d:release", "tests/test_all"
