import benchy, zippy/crc, zippy/internal

let data = readFile("tests/data/fireworks.jpg")

timeIt "crc32":
  discard crc32(data)

timeIt "adler32":
  discard adler32(data)
