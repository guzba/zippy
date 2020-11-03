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
    "empty.gold"
  ]

block nimlang_zip: # Requires zlib1.dll
  echo "https://github.com/nim-lang/zip"
  for gold in golds:
    let original = readFile(&"tests/data/{gold}")
    doAssert zlib.uncompress(
      zippy.compress(original), stream = ZLIB_STREAM
    ) == original
    doassert zippy.uncompress(
      zlib.compress(original, stream = ZLIB_STREAM)
    ) == original
  echo "pass!"

block treeform_miniz:
  echo "https://github.com/treeform/miniz"
  for gold in golds:
    let original = readFile(&"tests/data/{gold}")
    # doAssert miniz.uncompress(zippy.compress(original)) == original
    doAssert zippy.uncompress(miniz.compress(original)) == original
  echo "pass!"

block jangko_nimPNG:
  echo "https://github.com/jangko/nimPNG"
  for gold in golds:
    let original = readFile(&"tests/data/{gold}")
    doAssert nimz.zlib_decompress(
      nzInflateInit(zippy.compress(original))
    ) == original
  echo "pass!"
