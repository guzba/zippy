const
  crcTable = block:
    var
      table: array[256, uint32]
      c: uint32
    for i in 0.uint32 ..< table.len.uint32:
      c = i
      for j in 0 ..< 8:
        if (c and 1) > 0:
          c = 0xedb88320.uint32 xor (c shr 1)
        else:
          c = (c shr 1)
      table[i] = c
    table

func crc32*(v: uint32, data: seq[uint8]): uint32 =
  result = v
  for value in data:
    result = crcTable[(result xor value.uint32) and 0xff] xor (result shr 8)

func crc32*(data: seq[uint8]): uint32 =
  crc32(0xffffffff.uint32, data) xor 0xffffffff.uint32
