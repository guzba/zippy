import fidget/opengl/perf, strformat, zippy

proc t() =
  # let file = "alice29.txt.z"
  let file = "urls.10K.z"
  # let file = "test.z"
  let compressed = readFile(&"tests/data/{file}")
  let uncompressed = uncompress(compressed)
  echo uncompressed.len
  # echo cast[string](uncompressed)
  # let compressed = compress(original, level=11)
  # writeFile(&"tests/data/{file}.z", compressed)

timeIt "test":
  for i in 0 ..< 25:
    t()
