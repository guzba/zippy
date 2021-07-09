import miniz, nimPNG/nimz, strformat, zip/zlib, zippy

const
  golds = [
    "randtest1.gold",
    "randtest2.gold",
    "randtest3.gold",
    "rfctest1.gold",
    "rfctest2.gold",
    "rfctest3.gold",
    "tor-list.gold",
    "zerotest1.gold",
    "zerotest2.gold",
    "zerotest3.gold",
    "empty.gold",
    "alice29.txt",
    "asyoulik.txt",
    "fireworks.jpg",
    "geo.protodata",
    "html",
    "html_x_4",
    "kppkn.gtb",
    "lcet10.txt",
    "paper-100k.pdf",
    "plrabn12.txt",
    "urls.10K",
    "gzipfiletest.txt"
  ]

block nimlang_zip: # Requires zlib1.dll
  echo "https://github.com/nim-lang/zip"
  for gold in golds:
    let
      original = readFile(&"tests/data/{gold}")
      default = zippy.compress(original, dataFormat = dfZlib)
      bestSpeed = zippy.compress(original, BestSpeed, dfZlib)
      zlibCompressed = zlib.compress(original, stream = ZLIB_STREAM)
    doAssert zlib.uncompress(default, stream = ZLIB_STREAM) == original
    doAssert zlib.uncompress(bestSpeed, stream = ZLIB_STREAM) == original
    doassert zippy.uncompress(zlibCompressed) == original
    let
      defaultRatio = (default.len.float32 / original.len.float32) * 100
      bestSpeedRatio = (bestSpeed.len.float32 / original.len.float32) * 100
      zlibRatio = (zlibCompressed.len.float32 / original.len.float32) * 100
    echo &"{gold} zlib: {zlibRatio:.1f}% default: {defaultRatio:.1f}% bestspeed: {bestSpeedRatio:.1f}%"
  echo "pass!"

block treeform_miniz:
  echo "https://github.com/treeform/miniz"
  for gold in golds:
    let original = readFile(&"tests/data/{gold}")
    if gold == "tor-list.gold" or gold == "zerotest3.gold":
      # Something bad happens here with miniz
      discard
    else:
      doAssert miniz.uncompress(
        zippy.compress(original, dataFormat = dfZlib)
      ) == original
      doAssert miniz.uncompress(
        zippy.compress(original, level = BestSpeed, dataFormat = dfZlib)
      ) == original
    doAssert zippy.uncompress(miniz.compress(original)) == original
  echo "pass!"

block jangko_nimPNG:
  echo "https://github.com/jangko/nimPNG"
  for gold in golds:
    let original = readFile(&"tests/data/{gold}")
    doAssert nimz.zlib_decompress(
      nzInflateInit(zippy.compress(original, dataFormat = dfZlib))
    ) == original
    doAssert nimz.zlib_decompress(
      nzInflateInit(zippy.compress(
        original, level = BestSpeed, dataFormat = dfZlib
      ))
    ) == original
    doAssert zippy.uncompress(
      zlib_compress(nzDeflateInit(original))
    ) == original
  echo "pass!"
