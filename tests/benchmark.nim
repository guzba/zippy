import fidget/opengl/perf, strformat, zippy

# let file = "alice29.txt.z"
let file = "urls.10K.z"
# let file = "test.z"
# let file = "randtest3.z"

proc t() =
  let compressed = readFile(&"tests/data/{file}")
  let uncompressed = zippy.uncompress(compressed)
  # echo uncompressed.len
  # echo cast[string](uncompressed)
  # let compressed = compress(original, level=11)
  # writeFile(&"tests/data/{file}.z", compressed)

timeIt "test":
  for i in 0 ..< 100:
    t()
