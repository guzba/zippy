import zippy, strformat

const files = [
  "alice29.txt.z", "urls.10K.z"
]

for file in files:
  let
    compressed = readFile(&"tests/data/{file}")
    uncompressed = uncompress(compressed)
  assert uncompressed.len > 0
