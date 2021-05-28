version       = "0.5.7"
author        = "Ryan Oldenburg"
description   = "Pure Nim implementation of deflate, zlib, gzip and zip."
license       = "MIT"

srcDir = "src"

requires "nim >= 1.0.0"

task test, "Run all tests":
  exec "nim c -r tests/test_all.nim"

task github_actions, "Github Actions tests":
  exec "nim c -d:githubActions -r tests/test_all.nim"
