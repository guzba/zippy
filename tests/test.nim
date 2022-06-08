import std/strformat, zippy

const
  gzs = [
    "randtest1.gz",
    "randtest2.gz",
    "randtest3.gz",
    "rfctest1.gz",
    "rfctest2.gz",
    "rfctest3.gz",
    # "tor-list.gz",
    "zerotest1.gz",
    "zerotest2.gz",
    # "zerotest3.gz",
  ]
  golds = [
    "randtest1.gold",
    "randtest2.gold",
    "randtest3.gold",
    "rfctest1.gold",
    "rfctest2.gold",
    "rfctest3.gold",
    # "tor-list.gold",
    "zerotest1.gold",
    "zerotest2.gold",
    # "zerotest3.gold",
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

for i, gz in gzs:
  let
    compressed = readFile(&"tests/data/{gz}")
    gold = readFile(&"tests/data/{golds[i]}")
  echo &"{gz} compressed: {compressed.len} gold: {gold.len}"
  doAssert uncompress(compressed) == gold

block fixed:
  let
    compressed = readFile("tests/data/fixed.z")
    gold = readFile("tests/data/urls.10K")
  echo &"fixed.z compressed: {compressed.len} gold: {gold.len}"
  doAssert uncompress(compressed) == gold

block gzip:
  let
    compressed = readFile("tests/data/gzipfiletest.txt.gz")
    gold = readFile("tests/data/gzipfiletest.txt")
  echo &"gzipfiletest.txt compressed: {compressed.len} gold: {gold.len}"
  doAssert uncompress(compressed) == gold

for dataFormat in [dfDeflate, dfZlib, dfGzip]:
  for gold in golds:
    let
      original = readFile(&"tests/data/{gold}")
      compressed = compress(original, dataFormat = dataFormat)
      uncompressed = uncompress(
        compressed,
        if dataFormat == dfDeflate: dfDeflate else: dfDetect
      )
    echo &"{dataFormat} {gold} original: {original.len} compressed: {compressed.len}"
    doAssert original == uncompressed

  block all_uint8:
    var original: seq[uint8]
    for i in 0.uint8 .. high(uint8):
      original.add(i)
    let
      compressed = compress(original, dataFormat = dataFormat)
      uncompressed = uncompress(
        compressed,
        if dataFormat == dfDeflate: dfDeflate else: dfDetect
      )
    echo &"{dataFormat} all_uint8 original: {original.len} compressed: {compressed.len}"
    doAssert original == uncompressed
