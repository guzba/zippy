version       = "0.5.7"
author        = "Ryan Oldenburg"
description   = "Pure Nim implementation of deflate, zlib, gzip and zip."
license       = "MIT"

srcDir = "src"

requires "nim >= 1.0.0"

proc test(flags: string) =
  exec "nim c " & flags & " -r tests/test_all.nim"

task test, "Run all tests":
  test("")
  test("--gc:orc")

task github_actions, "GitHub Actions tests":
  test("-d:githubActions")
  test("--gc:orc -d:githubActions")
