import zippy

doAssert uncompress(readFile("tests/data/known_bad_nitter.json.gz")).len == 574
