import algorithm, random

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
    r = if inr >= 0: inr else: a.high
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
      piv = a[l];
      while l < r:
        while a[r] >= piv and l < r:
          dec r
        if l < r:
          a[l] = a[r]
          inc l
        while a[l] <= piv and l < r:
          inc l
        if l < r:
          a[r]=a[l]
          dec r
      a[l]=piv
      b[i+1]=l+1
      e[i+1]=e[i]
      e[i]=l
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
      r = if inr >= 0: inr else: a.high.uint32
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
      r = if inr >= 0: inr else: a.high.uint16
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
      r = if inr >= 0: inr else: a.high.uint16
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

var numbers = newSeq[int](100)
for i in 0 ..< numbers.len:
  numbers[i] = rand(1000)

# echo numbers

var
  n0 = numbers
  n1 = numbers
  n2 = numbers
  n3 = numbers
  n4 = numbers
  n5 = numbers
  n6 = numbers
insertionSort(n0, numbers.high)
quickSort_1(n1, 0, numbers.high)
quickSort_2(n2, 0, numbers.high)
quickSort_3(n3, 0, numbers.high)
quickSort_4(n4, 0, numbers.high)
quickSort_5(n5, 0, numbers.high)
quickSort_6(n6, 0, numbers.high)

assert n0 == n1
assert n2 == n1
assert n3 == n1
assert n4 == n1
assert n5 == n1
assert n6 == n1

import fidget/opengl/perf

template makeUnsorted(): seq[int] =
  var unsorted = newSeq[int](600)
  for i in 0 ..< 300:
    unsorted[i] = rand(1000)
  sort(unsorted)
  for i in 0 ..< 300:
    unsorted[i + 300] = rand(500)
  unsorted

const iterations = 100000

timeIt "default sort":
  for i in 0 ..< iterations:
    var unsorted = makeUnsorted()
    sort(unsorted)

timeIt "insertionSort":
  for i in 0 ..< iterations:
    var unsorted = makeUnsorted()
    insertionSort(unsorted, unsorted.high)

timeIt "quickSort_1":
  for i in 0 ..< iterations:
    var unsorted = makeUnsorted()
    quickSort_1(unsorted, 0, unsorted.high)

timeIt "quickSort_2":
  for i in 0 ..< iterations:
    var unsorted = makeUnsorted()
    quickSort_2(unsorted, 0, unsorted.high)

# timeIt "quickSort_3":
#   for i in 0 ..< iterations:
#     var unsorted = makeUnsorted()
#     quickSort_3(unsorted, 0, unsorted.high)

timeIt "quickSort_4":
  for i in 0 ..< iterations:
    var unsorted = makeUnsorted()
    quickSort_4(unsorted, 0, unsorted.high)

timeIt "quickSort_5":
  for i in 0 ..< iterations:
    var unsorted = makeUnsorted()
    quickSort_5(unsorted, 0, unsorted.high)

timeIt "quickSort_6":
  for i in 0 ..< iterations:
    var unsorted = makeUnsorted()
    quickSort_6(unsorted, 0, unsorted.high)
