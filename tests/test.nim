import strformat, zippy

const compressed = [
  "randtest1.z",
  "randtest2.z",
  "randtest3.z",
  "rfctest1.z",
  "rfctest2.z",
  "rfctest3.z",
  "tor-list.z",
  "zerotest1.z",
  "zerotest2.z",
  "zerotest3.z",
]

const gold = [
  "randtest1.gold",
  "randtest2.gold",
  "randtest3.gold",
  "rfctest1.gold",
  "rfctest2.gold",
  "rfctest3.gold",
  "tor-list.gold",
  "zerotest1.gold",
  "zerotest2.gold",
  "zerotest3.gold",
]

for i, file in compressed:
  echo file
  let
    z = readFile(&"tests/data/{file}")
    gold = readFile(&"tests/data/{gold[i]}")
  assert uncompress(z) == gold
