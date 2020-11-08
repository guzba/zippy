import strformat, zippy

const
  zs = [
    "randtest1.z",
    "randtest2.z",
    "randtest3.z",
    "rfctest1.z",
    "rfctest2.z",
    "rfctest3.z",
    "tor-list.z",
    "zerotest1.z",
    "zerotest2.z",
    "zerotest3.z",
  ]
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

for i, z in zs:
  let
    compressed = readFile(&"tests/data/{z}")
    gold = readFile(&"tests/data/{golds[i]}")
  echo &"{z} compressed: {compressed.len} gold: {gold.len}"
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
      compressed = compress(original, dataFormat)
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
      compressed = compress(original, dataFormat)
      uncompressed = uncompress(
        compressed,
        if dataFormat == dfDeflate: dfDeflate else: dfDetect
      )
    echo &"{dataFormat} all_uint8 original: {original.len} compressed: {compressed.len}"
    doAssert original == uncompressed
