import strformat, zippy

const
  test1Path = "tests/data/rfctest1.gold"
  test1 = block:
    let
      original = readFile(test1Path)
      compressed = compress(original, dfGzip)
      uncompressed = uncompress(compressed)
    doAssert uncompressed == original
    compressed

  test2Seq = @[0.uint8, 8, 8, 8, 3, 8, 3, 3, 1, 1]
  test2 = block:
    let
      compressed = compress(test2Seq, dfGzip)
      uncompressed = uncompress(compressed)
    doAssert uncompressed == test2Seq
    compressed

doAssert uncompress(test1) == readFile(test1Path)
doAssert uncompress(test2) == test2Seq
