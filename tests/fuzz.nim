import std/random, std/strformat, zippy

randomize()

const files = [
  "randtest1.gz",
  "randtest2.gz",
  "randtest3.gz",
  "rfctest1.gz",
  "rfctest2.gz",
  "rfctest3.gz",
  "zerotest1.gz",
  "zerotest2.gz",
]

for i in 0 ..< 10_000:
  let file = files[rand(files.len - 1)]
  var compressed = readFile(&"tests/data/{file}")
  let
    pos = rand(compressed.len - 1)
    value = rand(255).char
  compressed[pos] = value
  echo &"{i} {file} {pos} {value.uint8}"
  try:
    doAssert uncompress(compressed).len > 0
  except ZippyError:
    discard

  compressed = compressed[0 ..< pos]
  try:
    doAssert uncompress(compressed).len > 0
  except ZippyError:
    discard
