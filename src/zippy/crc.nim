import internal

## See https://create.stephan-brumme.com/crc32/

const crcTables = block:
  var
    tables: array[8, array[256, uint32]]
    c: uint32
  for i in 0.uint32 ..< 256:
    c = i
    for j in 0 ..< 8:
      c = (c shr 1) xor ((c and 1) * 0xedb88320.uint32)
    tables[0][i] = c
  for i in 0 ..< 256:
    tables[1][i] = (tables[0][i] shr 8) xor tables[0][tables[0][i] and 255]
    tables[2][i] = (tables[1][i] shr 8) xor tables[0][tables[1][i] and 255]
    tables[3][i] = (tables[2][i] shr 8) xor tables[0][tables[2][i] and 255]
    tables[4][i] = (tables[3][i] shr 8) xor tables[0][tables[3][i] and 255]
    tables[5][i] = (tables[4][i] shr 8) xor tables[0][tables[4][i] and 255]
    tables[6][i] = (tables[5][i] shr 8) xor tables[0][tables[5][i] and 255]
    tables[7][i] = (tables[6][i] shr 8) xor tables[0][tables[6][i] and 255]
  tables

func crc32*(v: uint32, data: seq[uint8] | string): uint32 =
  result = v

  var pos: int
  while data.len - pos >= 8:
    let
      one = read32(data, pos) xor result
      two = read32(data, pos + 4)
    result =
      crcTables[7][(one shr 0) and 255] xor
      crcTables[6][(one shr 8) and 255] xor
      crcTables[5][(one shr 16) and 255] xor
      crcTables[4][one shr 24] xor
      crcTables[3][(two shr 0) and 255] xor
      crcTables[2][(two shr 8) and 255] xor
      crcTables[1][(two shr 16) and 255] xor
      crcTables[0][two shr 24]
    pos += 8

  while pos < data.len:
    result = crcTables[0][(result xor cast[uint8](data[pos])) and 255] xor (result shr 8)
    inc pos

func crc32*(data: seq[uint8] | string): uint32 {.inline.} =
  not crc32(0xffffffff.uint32, data)
