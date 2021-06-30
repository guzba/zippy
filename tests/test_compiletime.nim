import zippy

const
  testPath = "tests/data/gzipfiletest.txt"

  testDefault = block:
    let
      original = readFile(testPath)
      compressed = compress(original)
      uncompressed = uncompress(compressed)
    doAssert uncompressed == original
    compressed

  testBestSpeed = block:
    let
      original = readFile(testPath)
      compressed = compress(original, BestSpeed)
      uncompressed = uncompress(compressed)
    doAssert uncompressed == original
    compressed

  # test2Seq = @[0.uint8, 8, 8, 8, 3, 8, 3, 3, 1, 1]
  # test2 = block:
  #   let
  #     compressed = compress(test2Seq)
  #     uncompressed = uncompress(compressed)
  #   doAssert uncompressed == test2Seq
  #   compressed

let original = readFile(testPath)
doAssert uncompress(testDefault) == original
doAssert uncompress(testBestSpeed) == original
# doAssert uncompress(test2) == test2Seq
