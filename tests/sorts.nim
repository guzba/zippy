import benchy, std/algorithm, std/random

randomize()

func insertionSort(s: var seq[int], hi: int) =
  for i in 1 .. hi:
    var
      j = i - 1
      k = i
    while j >= 0 and s[j] > s[k]:
      swap(s[j + 1], s[j])
      dec j
      dec k

proc quickSort_1(s: var seq[int], lo, hi: int) =
  if lo >= hi:
    return

  var
    pivot = lo
    swapPos = lo + 1
  for i in lo + 1 .. hi:
    if s[i] < s[pivot]:
      swap(s[i], s[swapPos])
      swap(s[pivot], s[swapPos])
      inc pivot
      inc swapPos

  quickSort1(s, lo, pivot - 1)
  quickSort1(s, pivot + 1, hi)

proc quickSort_2(a: var seq[int], inl, inr: int) =
  var
    r = inr
    l = inl
  let n = r - l + 1
  if n < 2:
    return
  let p = a[l + 3 * n div 4]
  while l <= r:
    if a[l] < p:
      inc l
    elif a[r] > p:
      dec r
    else:
      swap a[l], a[r]
      inc l
      dec r
  quickSort2(a, inl, r)
  quickSort2(a, l, inr)

proc quickSort_3(a: var seq[int], lo, hi: int) =
  var
    piv, i, l, r: int
    b: array[64, int]
    e: array[64, int]

  b[0] = lo
  e[0] = hi + 1
  while i >= 0:
    l = b[i]
    r = e[i] - 1
    if l < r:
      piv = a[l]
      while l < r:
        while a[r] >= piv and l < r:
          dec r
        if l < r:
          a[l] = a[r]
          inc l
        while a[l] <= piv and l < r:
          inc l
        if l < r:
          a[r] = a[l]
          dec r
      a[l] = piv
      b[i+1] = l+1
      e[i+1] = e[i]
      e[i] = l
      inc i
    else:
      dec i

proc quickSort_4(a: var seq[int], lo, hi: int) =
  var
    stack: array[32, uint32]
    top = 0
  stack[0] = (hi.uint32 shl 16) or lo.uint32

  while top >= 0:
    var
      inr = stack[top] shr 16
      inl = stack[top] and 0xffff.uint32
    dec top
    var
      r = inr
      l = inl
    let n = r - l + 1
    if n < 2:
      continue
    let p = a[l + 3 * n div 4]
    while l <= r:
      if a[l] < p:
        inc l
      elif a[r] > p:
        dec r
      else:
        swap a[l], a[r]
        inc l
        dec r

    stack[top + 1] = (r shl 16) or inl
    stack[top + 2] = (inr shl 16) or l
    inc(top, 2)

proc quickSort_5(a: var seq[int], lo, hi: int) =
  var
    stack: array[64, uint16]
    top = 1
  stack[0] = hi.uint16
  stack[1] = lo.uint16

  while top >= 0:
    var
      inr = stack[top - 1]
      inl = stack[top]
    dec(top, 2)
    var
      r = inr
      l = inl
    let n = r - l + 1
    if n < 2:
      continue
    let p = a[l + 3 * n div 4]
    while l <= r:
      if a[l] < p:
        inc l
      elif a[r] > p:
        dec r
      else:
        swap a[l], a[r]
        inc l
        dec r

    stack[top + 1] = r
    stack[top + 2] = inl
    stack[top + 3] = inr
    stack[top + 4] = l
    inc(top, 4)

proc quickSort_6(a: var seq[int], lo, hi: int) =
  var
    stack: array[32, (uint16, uint16)]
    top = 0
  stack[0] = (lo.uint16, hi.uint16)

  while top >= 0:
    var (inl, inr) = stack[top]
    dec top
    var
      r = inr
      l = inl
    let n = r - l + 1
    if n < 2:
      continue
    let p = a[l + 3 * n div 4]
    while l <= r:
      if a[l] < p:
        inc l
      elif a[r] > p:
        dec r
      else:
        swap a[l], a[r]
        inc l
        dec r

    stack[top + 1] = (l, inr)
    stack[top + 2] = (inl, r)
    inc(top, 2)

func heapSort(a: var seq[int], hi: int) =
  template siftDown(a: var seq[int]; start, ending: int) =
    var root = start
    while root * 2 + 1 < ending:
      var child = 2 * root + 1
      if child + 1 < ending and a[child] < a[child+1]:
        inc child
      if a[root] < a[child]:
        swap a[child], a[root]
        root = child
      else:
        break

  for start in countdown((hi - 1) div 2, 0):
    siftDown(a, start, hi + 1)
  for ending in countdown(hi, 1):
    swap(a[ending], a[0])
    siftDown(a, 0, ending)

func bubbleSort(a: var seq[int], hi: int) =
  var t = true
  for n in countdown(hi - 1, 0):
    if not t: break
    t = false
    for j in 0..n:
      if a[j] <= a[j+1]: continue
      swap a[j], a[j+1]
      t = true

proc shellSort(a: var seq[int], hi: int) =
  var h = hi + 1
  while h > 0:
    h = h div 2
    for i in h ..< a.len:
      let k = a[i]
      var j = i
      while j >= h and k < a[j-h]:
        a[j] = a[j-h]
        j -= h
      a[j] = k

proc quickSort_7(s: var seq[int], hi: int) =
  var
    stack: array[32, (int, int)]
    top = 0
  stack[0] = (0, hi)

  while top >= 0:
    var (inl, inr) = stack[top]
    dec top
    var
      l = inl
      r = inr
    if l >= r:
      continue
    var
      pivot = l
      swapPos = l + 1
    for i in l + 1 .. r:
      if s[i] < s[pivot]:
        swap(s[i], s[swapPos])
        swap(s[pivot], s[swapPos])
        inc pivot
        inc swapPos
    stack[top + 1] = (pivot + 1, r)
    stack[top + 2] = (l, pivot - 1)
    inc(top, 2)

var numbers = newSeq[int](10)
for i in 0 ..< numbers.len:
  numbers[i] = rand(1000)

# echo numbers

var
  n00 = numbers
  n01 = numbers
  n02 = numbers
  n03 = numbers
  n04 = numbers
  n05 = numbers
  n06 = numbers
  n07 = numbers
  n08 = numbers
  n09 = numbers
  n10 = numbers
insertionSort(n00, numbers.high)
quickSort_1(n01, 0, numbers.high)
quickSort_2(n02, 0, numbers.high)
quickSort_3(n03, 0, numbers.high)
quickSort_4(n04, 0, numbers.high)
quickSort_5(n05, 0, numbers.high)
quickSort_6(n06, 0, numbers.high)
heapSort(n07, numbers.high)
bubbleSort(n08, numbers.high)
shellSort(n09, numbers.high)
quickSort_7(n10, numbers.high)

assert n01 == n00
assert n02 == n00
assert n03 == n00
assert n04 == n00
assert n05 == n00
assert n06 == n00
assert n07 == n00
assert n08 == n00
assert n09 == n00
assert n10 == n00

let
  first = @[
    123, 60, 1, 21, 299, 590, 11, 64, 65, 47, 810, 1310,
    2797, 4619, 12868, 5505, 5665, 4669, 3595, 3091, 3344, 2929, 2790, 2971,
    3248, 246, 963, 517, 1362, 1006, 971, 1057, 985, 726, 652, 656,
    1059, 295, 476, 1090, 884, 756, 699, 794, 176, 901, 1304, 908,
    443, 436, 498, 349, 267, 427, 5, 3, 5, 35, 2464, 9496,
    3576, 5915, 5106, 11359, 2851, 3068, 3337, 7996, 1220, 2528, 5727, 4477,
    6948, 7417, 4228, 930, 7104, 8019, 7231, 4525, 1572, 2961, 1160, 2040,
    836, 20, 100, 24, 256, 2, 2, 16, 26, 4, 4, 2,
    1, 1, 2, 4, 1, 1, 4, 2, 2, 3, 2, 1,
    1, 2, 2, 1, 2, 2, 5, 1, 1, 5, 3, 1,
    5, 2, 1, 1, 3, 4, 2, 3, 1, 1, 2, 2,
    2, 6, 2, 1, 4, 3, 2, 1, 9, 1, 1, 2,
    9, 6, 1, 5, 21, 32, 1, 1, 3, 15, 8, 3,
    3, 10, 2, 3, 10, 1, 5, 1, 15792, 6531, 3577, 2034,
    2887, 2158, 816, 1546, 2456, 1352, 499, 896, 480,
    825, 853, 1246, 338, 300, 148, 229, 90, 40, 58,
    82, 43, 31, 2, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0
  ]
  second = @[
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 6,
    6, 6, 6, 7, 8, 8, 9, 10, 10, 10, 12, 17,
    19, 21, 31, 41, 45, 57, 67, 83, 105, 124,
    147, 190, 271, 405, 502, 562, 599, 687, 863,
    919, 978, 1016, 1242, 1355, 1482, 1604, 1641,
    1689, 1780, 1809, 1893, 1956, 2063, 2149, 2380,
    2550, 2662, 2908, 3606, 4198, 4920, 5318, 5648, 5816,
    5932, 6159, 6585, 6920, 7172, 8705, 9144, 9775, 11170, 11642,
    13479, 14335, 15413, 17515, 24227, 123, 60, 1, 21, 299, 590, 11,
    64, 65, 47, 810, 1310, 2797, 4619, 12868, 5505, 5665, 4669, 3595,
    3091, 3344, 2929, 2790, 2971, 3248, 246, 963, 517, 1362,
    1006, 971, 1057, 985, 726, 652, 656, 1059, 295, 476, 1090,
    884, 756, 699, 794, 176, 901, 1304, 908, 443, 436, 498,
    349, 267, 427, 5, 3, 5, 35, 2464, 9496, 3576, 5915,
    5106, 11359, 2851, 3068, 3337, 7996, 1220, 2528,
    5727, 4477, 6948, 7417, 4228, 930, 7104, 8019, 7231,
    4525, 1572, 2961, 1160, 2040, 836, 20, 100, 24, 256,
    2, 2, 16, 26, 4, 4, 2, 1, 1, 2, 4, 1, 1,
    4, 2, 2, 3, 2, 1, 1, 2, 2, 1, 2, 2,
    5, 1, 1, 5, 3, 1, 5, 2, 1, 1, 3, 4,
    2, 3, 1, 1, 2, 2, 2, 6, 2, 1, 4, 3,
    2, 1, 9, 1, 1, 2, 9, 6, 1, 5, 21, 32,
    1, 1, 3, 15, 8, 3, 3, 10, 2, 3, 10, 1,
    5, 1, 15792, 6531, 3577, 2034, 2887,
    2158, 816, 1546, 2456, 1352, 499, 896, 480,
    825, 853, 1246, 338, 300, 148, 229, 90, 40,
    58, 82, 43, 31, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  ]
  firstHi = 190
  secondHi = 285

const iterations = 500000

# timeIt "default sort":
#   for i in 0 ..< iterations:
#     var (a, b) = (first, second)
#     sort(a)
#     sort(b)

# timeIt "insertionSort":
#   for i in 0 ..< iterations:
#     var (a, b) = (first, second)
#     insertionSort(a, firstHi)
#     insertionSort(b, secondHi)

timeIt "quickSort_1":
  for i in 0 ..< iterations:
    var (a, b) = (first, second)
    quickSort_1(a, 0, firstHi)
    quickSort_1(b, 0, secondHi)

timeIt "quickSort_2":
  for i in 0 ..< iterations:
    var (a, b) = (first, second)
    quickSort_2(a, 0, firstHi)
    quickSort_2(b, 0, secondHi)

timeIt "quickSort_3":
  for i in 0 ..< iterations:
    var (a, b) = (first, second)
    quickSort_3(a, 0, firstHi)
    quickSort_3(b, 0, secondHi)

timeIt "quickSort_4":
  for i in 0 ..< iterations:
    var (a, b) = (first, second)
    quickSort_4(a, 0, firstHi)
    quickSort_4(b, 0, secondHi)

timeIt "quickSort_5":
  for i in 0 ..< iterations:
    var (a, b) = (first, second)
    quickSort_5(a, 0, firstHi)
    quickSort_5(b, 0, secondHi)

timeIt "quickSort_6":
  for i in 0 ..< iterations:
    var (a, b) = (first, second)
    quickSort_6(a, 0, firstHi)
    quickSort_6(b, 0, secondHi)

timeIt "heapSort":
  for i in 0 ..< iterations:
    var (a, b) = (first, second)
    heapSort(a, firstHi)
    heapSort(b, secondHi)

# timeIt "bubbleSort":
#   for i in 0 ..< iterations:
#     var (a, b) = (first, second)
#     bubbleSort(a, firstHi)
#     bubbleSort(b, secondHi)

# timeIt "shellSort":
#   for i in 0 ..< iterations:
#     var (a, b) = (first, second)
#     shellSort(a, firstHi)
#     shellSort(b, secondHi)

timeIt "quickSort_7":
  for i in 0 ..< iterations:
    var (a, b) = (first, second)
    quickSort_7(a, firstHi)
    quickSort_7(b, secondHi)
