import benchy, zippy/crc, zippy/common

let data = cast[seq[uint8]](readFile("tests/data/fireworks.jpg"))

timeIt "crc32":
  discard crc32(data)

timeIt "adler32":
  discard adler32(data)
