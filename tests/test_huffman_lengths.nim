import std/bitops, zippy

# Every byte value equally often, between copies with geometric lengths, puts
# more than 255 symbols at one Huffman code length (overflowed a uint8 count).

const lengths = [5, 6, 7, 8, 9, 10, 11, 13, 15]

var data: string
for k in 1 .. 1000:
  data.add char((k * (2 * (k shr 8) + 1)) and 255)
  if data.len > 7:
    let start = data.len - 7
    for i in 0 ..< lengths[min(countTrailingZeroBits(k), 8)]:
      data.add data[start + i]

for level in [6, 9]:
  doAssert uncompress(compress(data, level)) == data
