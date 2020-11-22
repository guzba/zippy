import std/monotimes, strformat, zip/zlib, zippy

# import miniz, nimPNG/nimz

const
  zs = [
    "alice29.txt.z",
    "urls.10K.z",
    "rfctest3.z",
    "randtest3.z",
    "paper-100k.pdf.z",
    "geo.protodata.z"
  ]
  golds = [
    "alice29.txt",
    "urls.10K",
    "rfctest3.gold",
    "randtest3.gold",
    "paper-100k.pdf",
    "geo.protodata",
    "gzipfiletest.txt"
  ]
  iterations = 1000

block guzba_zippy_compress:
  echo "https://github.com/guzba/zippy compress [default]"
  for gold in golds:
    let
      uncompressed = readFile(&"tests/data/{gold}")
      start = getMonoTime().ticks
    var c: int
    for i in 0 ..< iterations:
      let compressed = zippy.compress(uncompressed, dataFormat = dfZlib)
      inc(c, compressed.len)
    let
      delta = float64(getMonoTime().ticks - start) / 1000000000.0
      reduction = 100 - (c / (uncompressed.len * iterations)) * 100
    echo &"  {gold}: {delta:.4f}s {(reduction):0.2f}%"

block nimlang_zip_compress: # Requires zlib1.dll
  echo "https://github.com/nim-lang/zip compress [default]"
  for gold in golds:
    let
      uncompressed = readFile(&"tests/data/{gold}")
      start = getMonoTime().ticks
    var c: int
    for i in 0 ..< iterations:
      let compressed = zlib.compress(uncompressed, stream = ZLIB_STREAM)
      inc(c, compressed.len)
    let
      delta = float64(getMonoTime().ticks - start) / 1000000000.0
      reduction = 100 - (c / (uncompressed.len * iterations)) * 100
    echo &"  {gold}: {delta:.4f}s {(reduction):0.2f}%"

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
#     let
#       delta = float64(getMonoTime().ticks - start) / 1000000000.0
#       reduction = 100 - (c / (uncompressed.len * iterations)) * 100
#     echo &"  {gold}: {delta:.4f}s {(reduction):0.2f}%"

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
#     let
#       delta = float64(getMonoTime().ticks - start) / 1000000000.0
#       reduction = 100 - (c / (uncompressed.len * iterations)) * 100
#     echo &"  {gold}: {delta:.4f}s {reduction:0.2f}%"

block guzba_zippy_compress:
  echo "https://github.com/guzba/zippy compress [best speed]"
  for gold in golds:
    let
      uncompressed = readFile(&"tests/data/{gold}")
      start = getMonoTime().ticks
    var c: int
    for i in 0 ..< iterations:
      let compressed = zippy.compress(uncompressed, BestSpeed, dfZlib)
      inc(c, compressed.len)
    let
      delta = float64(getMonoTime().ticks - start) / 1000000000.0
      reduction = 100 - (c / (uncompressed.len * iterations)) * 100
    echo &"  {gold}: {delta:.4f}s {(reduction):0.2f}%"

block nimlang_zip_compress: # Requires zlib1.dll
  echo "https://github.com/nim-lang/zip compress [best speed]"
  for gold in golds:
    let
      uncompressed = readFile(&"tests/data/{gold}")
      start = getMonoTime().ticks
    var c: int
    for i in 0 ..< iterations:
      let compressed = zlib.compress(uncompressed, Z_BEST_SPEED, ZLIB_STREAM)
      inc(c, compressed.len)
    let
      delta = float64(getMonoTime().ticks - start) / 1000000000.0
      reduction = 100 - (c / (uncompressed.len * iterations)) * 100
    echo &"  {gold}: {delta:.4f}s {(reduction):0.2f}%"

block guzba_zippy_compress:
  echo "https://github.com/guzba/zippy compress [best compression]"
  for gold in golds:
    let
      uncompressed = readFile(&"tests/data/{gold}")
      start = getMonoTime().ticks
    var c: int
    for i in 0 ..< iterations:
      let compressed = zippy.compress(uncompressed, BestCompression, dfZlib)
      inc(c, compressed.len)
    let
      delta = float64(getMonoTime().ticks - start) / 1000000000.0
      reduction = 100 - (c / (uncompressed.len * iterations)) * 100
    echo &"  {gold}: {delta:.4f}s {(reduction):0.2f}%"

block nimlang_zip_compress: # Requires zlib1.dll
  echo "https://github.com/nim-lang/zip compress [best compression]"
  for gold in golds:
    let
      uncompressed = readFile(&"tests/data/{gold}")
      start = getMonoTime().ticks
    var c: int
    for i in 0 ..< iterations:
      let compressed = zlib.compress(
        uncompressed, Z_BEST_COMPRESSION, ZLIB_STREAM
      )
      inc(c, compressed.len)
    let
      delta = float64(getMonoTime().ticks - start) / 1000000000.0
      reduction = 100 - (c / (uncompressed.len * iterations)) * 100
    echo &"  {gold}: {delta:.4f}s {(reduction):0.2f}%"

block guzba_zippy_uncompress:
  echo "https://github.com/guzba/zippy uncompress"
  for z in zs:
    let
      compressed = readFile(&"tests/data/{z}")
      start = getMonoTime().ticks
    var c: int
    for i in 0 ..< iterations:
      let uncompressed = zippy.uncompress(compressed)
      inc(c, uncompressed.len)
    let delta = float64(getMonoTime().ticks - start) / 1000000000.0
    echo &"  {z}: {delta:.4f}s [{c}]"

block nimlang_zip_uncompress: # Requires zlib1.dll
  echo "https://github.com/nim-lang/zip uncompress"
  for z in zs:
    let
      compressed = readFile(&"tests/data/{z}")
      start = getMonoTime().ticks
    var c: int
    for i in 0 ..< iterations:
      let uncompressed = zlib.uncompress(compressed, stream = ZLIB_STREAM)
      inc(c, uncompressed.len)
    let delta = float64(getMonoTime().ticks - start) / 1000000000.0
    echo &"  {z}: {delta:.4f}s [{c}]"

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
