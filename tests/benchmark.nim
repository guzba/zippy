import fidget/opengl/perf, strformat, zippy

const compressed = [
  "randtest1.z",
  "randtest2.z",
  "randtest3.z",
  "rfctest1.z",
  "rfctest2.z",
  "rfctest3.z",
  "zerotest1.z",
  "zerotest2.z",
  "zerotest3.z",
  "alice29.txt.z",
  "urls.10K.z",
  "fixed.z"
]

timeIt "zippy":
  for file in compressed:
    let data = readFile(&"tests/data/{file}")
    for i in 0 ..< 100:
      discard zippy.uncompress(data)
