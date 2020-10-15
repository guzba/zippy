type
  Node* = ref object
    symbol*: uint16
    left*, right*: Node

func insert*(root: Node, code: uint16, length: uint8, symbol: uint16) =
  var node = root
  for i in countdown(length - 1, 0):
    let b = code and (1.uint16 shl i)
    if b != 0:
      if node.right == nil:
        node.right = Node()
      node = node.right
    else:
      if node.left == nil:
        node.left = Node()
      node = node.left
  node.symbol = symbol
