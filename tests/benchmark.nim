import miniz, nimPNG/nimz, std/monotimes, strformat, zip/zlib, zippy

const
  zs = [
    "randtest3.z",
    "rfctest3.z",
    "alice29.txt.z",
    "urls.10K.z",
    "fixed.z"
  ]
  golds = [
    "rfctest1.gold",
  ]
  iterations = 10000

# block guzba_zippy_uncompress:
#   echo "https://github.com/guzba/zippy uncompress"
#   for z in zs:
#     let
#       compressed = readFile(&"tests/data/{z}")
#       start = getMonoTime().ticks
#     var c: int
#     for i in 0 ..< iterations:
#       let uncompressed = zippy.uncompress(compressed)
#       inc(c, uncompressed.len)
#     let delta = float64(getMonoTime().ticks - start) / 1000000000.0
#     echo &"  {z}: {delta:.4f}s [{c}]"

block guzba_zippy_compress:
  echo "https://github.com/guzba/zippy compress"
  for gold in golds:
    let
      uncompressed = readFile(&"tests/data/{gold}")
      start = getMonoTime().ticks
    var c: int
    for i in 0 ..< iterations:
      let compressed = zippy.compress(uncompressed)
      inc(c, compressed.len)
    let delta = float64(getMonoTime().ticks - start) / 1000000000.0
    echo &"  {gold}: {delta:.4f}s [{c}]"

# block treeform_miniz_uncompress:
#   echo "https://github.com/treeform/miniz uncompress"
#   for z in zs:
#     let
#       compressed = readFile(&"tests/data/{z}")
#       start = getMonoTime().ticks
#     var c: int
#     for i in 0 ..< iterations:
#       let uncompressed = miniz.uncompress(compressed)
#       inc(c, uncompressed.len)
#     let delta = float64(getMonoTime().ticks - start) / 1000000000.0
#     echo &"  {z}: {delta:.4f}s [{c}]"

# block treeform_miniz_compress:
#   echo "https://github.com/treeform/miniz compress"
#   for gold in golds:
#     let
#       uncompressed = readFile(&"tests/data/{gold}")
#       start = getMonoTime().ticks
#     var c: int
#     for i in 0 ..< iterations:
#       let compressed = miniz.compress(uncompressed, 1)
#       inc(c, compressed.len)
#     let delta = float64(getMonoTime().ticks - start) / 1000000000.0
#     echo &"  {gold}: {delta:.4f}s [{c}]"

# block nimlang_zip_uncompress: # Requires zlib1.dll
#   echo "https://github.com/nim-lang/zip uncompress"
#   for z in zs:
#     let
#       compressed = readFile(&"tests/data/{z}")
#       start = getMonoTime().ticks
#     var c: int
#     for i in 0 ..< iterations:
#       let uncompressed = zlib.uncompress(compressed, stream = ZLIB_STREAM)
#       inc(c, uncompressed.len)
#     let delta = float64(getMonoTime().ticks - start) / 1000000000.0
#     echo &"  {z}: {delta:.4f}s [{c}]"

# block jangko_nimPNG_uncompress:
#   echo "https://github.com/jangko/nimPNG uncompress"
#   for z in zs:
#     let
#       compressed = readFile(&"tests/data/{z}")
#       start = getMonoTime().ticks
#     var c: int
#     for i in 0 ..< iterations:
#       let uncompressed = zlib_decompress(nzInflateInit(compressed))
#       inc(c, uncompressed.len)
#     let delta = float64(getMonoTime().ticks - start) / 1000000000.0
#     echo &"  {z}: {delta:.4f}s [{c}]"

# block jangko_nimPNG_compress:
#   echo "https://github.com/jangko/nimPNG compress"
#   for gold in golds:
#     let
#       uncompressed = readFile(&"tests/data/{gold}")
#       start = getMonoTime().ticks
#     var c: int
#     for i in 0 ..< iterations:
#       let compressed = zlib_compress(nzDeflateInit(uncompressed))
#       inc(c, compressed.len)
#     let delta = float64(getMonoTime().ticks - start) / 1000000000.0
#     echo &"  {gold}: {delta:.4f}s [{c}]"
