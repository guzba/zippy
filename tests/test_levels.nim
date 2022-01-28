import std/strformat, zippy

const
  golds = [
    "randtest1.gold",
    "rfctest1.gold",
    "zerotest1.gold",
    "empty.gold",
    "alice29.txt",
    "asyoulik.txt",
    "fireworks.jpg",
    "geo.protodata",
    "html",
    "kppkn.gtb",
    "paper-100k.pdf"
  ]

for level in -2 .. 9:
  for gold in golds:
    let
      original = readFile(&"tests/data/{gold}")
      compressed = compress(original, level)
      uncompressed = uncompress(compressed)
    echo &"Level {level} {gold} original: {original.len} compressed: {compressed.len}"
    doAssert original == uncompressed
