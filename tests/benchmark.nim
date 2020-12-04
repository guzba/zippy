import benchy, strformat, zip/zlib, zippy

import miniz, nimPNG/nimz

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
  iterations = 10

echo "https://github.com/guzba/zippy compress [default]"
for gold in golds:
  timeIt gold:
    let uncompressed = readFile(&"tests/data/{gold}")
    for i in 0 ..< iterations:
      keep zippy.compress(uncompressed, dataFormat = dfZlib)

echo "https://github.com/nim-lang/zip compress [default]" # Requires zlib1.dll
for gold in golds:
  timeIt gold:
    let uncompressed = readFile(&"tests/data/{gold}")
    for i in 0 ..< iterations:
      keep zlib.compress(uncompressed, stream = ZLIB_STREAM)

# echo "https://github.com/treeform/miniz compress [default]"
# for gold in golds:
#   timeIt gold:
#     let uncompressed = readFile(&"tests/data/{gold}")
#     for i in 0 ..< iterations:
#       keep miniz.compress(uncompressed)

# echo "https://github.com/jangko/nimPNG compress [default]"
# for gold in golds:
#   timeIt gold:
#     let uncompressed = readFile(&"tests/data/{gold}")
#     for i in 0 ..< iterations:
#       keep zlib_compress(nzDeflateInit(uncompressed))

echo "https://github.com/guzba/zippy compress [best speed]"
for gold in golds:
  timeIt gold:
    let uncompressed = readFile(&"tests/data/{gold}")
    for i in 0 ..< iterations:
      keep zippy.compress(uncompressed, BestSpeed, dataFormat = dfZlib)

echo "https://github.com/nim-lang/zip compress [best speed]" # Requires zlib1.dll
for gold in golds:
  timeIt gold:
    let uncompressed = readFile(&"tests/data/{gold}")
    for i in 0 ..< iterations:
      keep zlib.compress(uncompressed, Z_BEST_SPEED, ZLIB_STREAM)

echo "https://github.com/guzba/zippy compress [best compression]"
for gold in golds:
  timeIt gold:
    let uncompressed = readFile(&"tests/data/{gold}")
    for i in 0 ..< iterations:
      keep zippy.compress(uncompressed, BestCompression, dataFormat = dfZlib)

echo "https://github.com/nim-lang/zip compress [best compression]" # Requires zlib1.dll
for gold in golds:
  timeIt gold:
    let uncompressed = readFile(&"tests/data/{gold}")
    for i in 0 ..< iterations:
      keep zlib.compress(uncompressed, Z_BEST_COMPRESSION, ZLIB_STREAM)

echo "https://github.com/guzba/zippy uncompress"
for z in zs:
  timeIt z:
    let compressed = readFile(&"tests/data/{z}")
    for i in 0 ..< iterations:
      keep zippy.uncompress(compressed)

echo "https://github.com/nim-lang/zip uncompress" # Requires zlib1.dll
for z in zs:
  timeIt z:
    let compressed = readFile(&"tests/data/{z}")
    for i in 0 ..< iterations:
      keep zlib.uncompress(compressed, stream = ZLIB_STREAM)

# echo "https://github.com/treeform/miniz uncompress"
# for z in zs:
#   timeIt z:
#     let compressed = readFile(&"tests/data/{z}")
#     for i in 0 ..< iterations:
#       keep miniz.uncompress(compressed)

# echo "https://github.com/jangko/nimPNG uncompress"
# for z in zs:
#   timeIt z:
#     let compressed = readFile(&"tests/data/{z}")
#     for i in 0 ..< iterations:
#       keep zlib_decompress(nzInflateInit(compressed))
