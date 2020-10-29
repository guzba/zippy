import miniz, nimPNG/nimz, std/monotimes, strformat, zip/zlib, zippy

const
  files = [
    "randtest3.z",
    "rfctest3.z",
    "alice29.txt.z",
    "urls.10K.z",
    "fixed.z"
  ]
  iterations = 1000

block guzba_zippy:
  echo "https://github.com/guzba/zippy"
  for file in files:
    let
      compressed = readFile(&"tests/data/{file}")
      start = getMonoTime().ticks
    var c: int
    for i in 0 ..< iterations:
      let uncompressed = zippy.uncompress(compressed)
      inc(c, uncompressed.len)
    let delta = float64(getMonoTime().ticks - start) / 1000000000.0
    echo &"  {file}: {delta:.4f}s [{c}]"

block treeform_miniz:
  echo "https://github.com/treeform/miniz"
  for file in files:
    let
      compressed = readFile(&"tests/data/{file}")
      start = getMonoTime().ticks
    var c: int
    for i in 0 ..< iterations:
      let uncompressed = miniz.uncompress(compressed)
      inc(c, uncompressed.len)
    let delta = float64(getMonoTime().ticks - start) / 1000000000.0
    echo &"  {file}: {delta:.4f}s [{c}]"

block nimlang_zip: # Requires zlib1.dll
  echo "https://github.com/nim-lang/zip"
  for file in files:
    let
      compressed = readFile(&"tests/data/{file}")
      start = getMonoTime().ticks
    var c: int
    for i in 0 ..< iterations:
      let uncompressed = zlib.uncompress(compressed, stream = ZLIB_STREAM)
      inc(c, uncompressed.len)
    let delta = float64(getMonoTime().ticks - start) / 1000000000.0
    echo &"  {file}: {delta:.4f}s [{c}]"

block jangko_nimPNG:
  echo "https://github.com/jangko/nimPNG"
  for file in files:
    let
      compressed = readFile(&"tests/data/{file}")
      start = getMonoTime().ticks
    var c: int
    for i in 0 ..< iterations:
      let uncompressed = zlib_decompress(nzInflateInit(compressed))
      inc(c, uncompressed.len)
    let delta = float64(getMonoTime().ticks - start) / 1000000000.0
    echo &"  {file}: {delta:.4f}s [{c}]"
