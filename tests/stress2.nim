import std/random, std/times, zip/zlib, zippy

let gold = readFile("tests/data/rfctest3.gold")

let seed = epochTime().int
var r = initRand(seed)

for i in 0 ..< 10000:
  echo "Test ", i, " (seed ", seed, ")"
  let m = r.rand(100)

  var data = gold
  for i in 0 ..< m:
    data &= gold

  for level in [1, -1]: # BestSpeed and Default
    var
      compressed = zlib.compress(data, level = level, stream = GZIP_STREAM)
      uncompressed = zippy.uncompress(compressed)
    doAssert uncompressed == data
