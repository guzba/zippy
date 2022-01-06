import flatty, pixie

let tmp = fromFlatty(readFile("tests/data/known_bad_image.flatty"), Image)

tmp.writeFile("tmp.png")
