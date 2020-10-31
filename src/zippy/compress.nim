import zippyerror, common, deques

const
  blockSize = 65535
  windowSize = 32768

type
  Node {.acyclic.} = ref object
    symbol: uint16
    weight: uint16
    kids: array[2, Node] # left = [0], right = [1]

# {.push checks: off.}

func `<`(a, b: Node): bool = a.weight < b.weight

func quicksort(s: var seq[Node], inl, inr: int) =
  var
    r = inr
    l = inl
  let n = r - l + 1
  if n < 2:
    return
  let p = s[l + 3 * n div 4]
  while l <= r:
    if s[l] < p:
      inc l
      continue
    if s[r] > p:
      dec r
      continue
    if l <= r:
      swap(s[l], s[r])
      inc l
      dec r
  quicksort(s, inl, r)
  quicksort(s, l, inr)

template quicksort(s: var seq[Node]) =
  quicksort(s, 0, s.high)

# template failCompress() =
#   raise newException(
#     ZippyError, "Unexpected error while compressing"
#   )

func mt(frequencies: seq[uint16], minCodes, maxBitLen: int): Node =
  var
    numCodes = frequencies.len
    nodes = newSeq[Node]()
  for i, freq in frequencies:
    if numCodes > minCodes and freq == 0:
      dec numCodes
      continue
    let n = Node()
    n.symbol = i.uint16
    n.weight = freq
    nodes.add(n)

  quicksort(nodes)

  var q1, q2: Deque[Node]
  for n in nodes:
    q1.addLast(n)

  while q1.len + q2.len > 1:
    var kids: array[2, Node]
    for i in 0 .. 1:
      if q1.len > 0 and q2.len > 0:
        if q1.peekFirst.weight >= q2.peekFirst.weight:
          kids[i] = q1.popFirst()
        else:
          kids[i] = q2.popFirst()
      elif q1.len > 0:
        kids[i] = q1.popFirst()
      else:
        kids[i] = q2.popFirst()
    let internal = Node()
    internal.kids = kids
    internal.weight = kids[0].weight + kids[1].weight
    q2.addLast(internal)
  q2.popFirst()

func compress*(src: seq[uint8], dst: var seq[uint8]) =
  ## Uncompresses src into dst. This resizes dst as needed and starts writing
  ## at dst index 0.

  # const
  #   cm = 8.uint8
  #   cinfo = 7.uint8
  #   cmf = (cinfo shl 4) or cm
  #   fcheck = (31 - (cmf.uint32 * 256) mod 31).uint8

  # dst.add(cmf)
  # dst.add(fcheck)

  # debugEcho dst

  # No lz77 for now, just Huffman compressed
  let encoded = src

  var
    freqLitLen = newSeq[uint16](286)
    freqDist = newSeq[uint16](30)

  for symbol in encoded:
    inc freqLitLen[symbol]

  # freqLitLen[256] = 1 # Alway 1 end-of-block symbol

  let root = mt(freqLitLen, 257, 15)
  # debugEcho "[", root.kids[0] == nil, ", ", root.kids[1] == nil, "]"

  var
    i, depth: int

  func walk(n: Node, d: int) =
    if n != nil:
      inc i
    else:
      return
    depth = max(depth, d)
    walk(n.kids[0], d + 1)
    walk(n.kids[1], d + 1)

  walk(root, 0)

  debugEcho "depth ", i, " ", depth, " ", root.weight

func compress*(src: seq[uint8]): seq[uint8] {.inline.} =
  ## Uncompresses src and returns the compressed data seq.
  compress(src, result)

template compress*(src: string): string =
  ## Helper for when preferring to work with strings.
  cast[string](compress(cast[seq[uint8]](src)))

# {.pop.}
