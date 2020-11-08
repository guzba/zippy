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
    "urls.10K"
  ]

block nimlang_zip: # Requires zlib1.dll
  echo "https://github.com/nim-lang/zip"
  for gold in golds:
    let original = readFile(&"tests/data/{gold}")
    doAssert zlib.uncompress(
      zippy.compress(original, dfZlib), stream = ZLIB_STREAM
    ) == original
    doassert zippy.uncompress(
      zlib.compress(original, stream = ZLIB_STREAM)
    ) == original
  echo "pass!"

block treeform_miniz:
  echo "https://github.com/treeform/miniz"
  for gold in golds:
    let original = readFile(&"tests/data/{gold}")
    if gold == "tor-list.gold" or gold == "zerotest3.gold":
      # Something bad happens here with miniz
      discard
    else:
      doAssert miniz.uncompress(zippy.compress(original, dfZlib)) == original
    doAssert zippy.uncompress(miniz.compress(original)) == original
  echo "pass!"

block jangko_nimPNG:
  echo "https://github.com/jangko/nimPNG"
  for gold in golds:
    let original = readFile(&"tests/data/{gold}")
    doAssert nimz.zlib_decompress(
      nzInflateInit(zippy.compress(original, dfZlib))
    ) == original
    doAssert zippy.uncompress(
      zlib_compress(nzDeflateInit(original))
    ) == original
  echo "pass!"
