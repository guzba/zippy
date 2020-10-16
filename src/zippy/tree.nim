type
  Node* = ref object
    symbol*: uint16
    kids*: array[2, Node] # left = [0], right = [1]
    stop*: bool

func insert*(root: Node, code: uint16, length: uint8, symbol: uint16) =
  var node = root
  for i in countdown(length - 1, 0):
    let b = ((code and (1.uint16 shl i)) != 0).uint8
    if node.kids[b] == nil:
      node.kids[b] = Node()
    node = node.kids[b]
    node.stop = false
  node.stop = true
  node.symbol = symbol
