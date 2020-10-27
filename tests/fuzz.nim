import random, strformat, zippy

randomize()

const files = [
  "randtest1.z",
  "randtest2.z",
  "randtest3.z",
  "rfctest1.z",
  "rfctest2.z",
  "rfctest3.z",
  "zerotest1.z",
  "zerotest2.z",
  "zerotest3.z",
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
    assert uncompress(compressed).len > 0
  except ZippyError:
    discard
