import std/random, std/times, zip/zlib, zippy

# Generate random blobs of data containing runs of random lengths. Ensure
# we can always compress this blob and that uncompressing the compressed
# data matches the original blob.

let seed = epochTime().int
var r = initRand(seed)

for i in 0 ..< 10000:
  echo "Test ", i, " (seed ", seed, ")"

  var
    data: string
    length = r.rand(100000)
    i: int
  data.setLen(length)
  while i < length:
    let
      v = r.rand(255).char
      runLength = min(r.rand(255), length - i)
    for j in 0 ..< runLength:
      data[i + j] = v
    inc(i, runLength)

  var shuffled = data # Copy
  r.shuffle(shuffled)

  template fuzz() =
    let pos = r.rand(compressed.len - 1)
    try:
      let value = r.rand(255).char
      compressed[pos] = value
      doAssert zippy.uncompress(compressed).len > 0
    except ZippyError:
      discard

    compressed = compressed[0 ..< pos]
    try:
      doAssert zippy.uncompress(compressed).len > 0
    except ZippyError:
      discard

  for level in [1, -1]: # BestSpeed and Default
    block: # data
      var
        compressed = zippy.compress(data)
        uncompressed = zippy.uncompress(compressed)
      doAssert uncompressed == data
      doAssert zlib.uncompress(compressed, stream = GZIP_STREAM) == data
      fuzz()
    block: # shuffled
      var
        compressed = zippy.compress(shuffled)
        uncompressed = zippy.uncompress(compressed)
      doAssert uncompressed == shuffled
      doAssert zlib.uncompress(compressed, stream = GZIP_STREAM) == shuffled
      fuzz()
