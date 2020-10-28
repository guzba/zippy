# Zippy

`nimble install zippy`

Zippy is an in-progress and experimental implementation of [DEFLATE](https://tools.ietf.org/html/rfc1951) and [ZLIB](https://tools.ietf.org/html/rfc1950).

The goal of this library is to be a dependency-free Nim implementation that is as small and straightforward as possible while still focusing on performance.

Zippy works well using Nim's relatively new --gc:arc and --gc:orc as well as the default garbage collector. This library also works using both nim c and nim cpp, in addition to --cc:vcc on Windows.

I have also verified that Zippy builds with `--experimental:strictFuncs` on Nim 1.4.0.

**This library is an active project and not ready for production use. Currently only uncompress (inflating) has been implemented.**

### Performance

Benchmarks can be run comparing different Zip implementations. My benchmarking shows this library performs very well but it is not as fast as zlib itself (not a surprise). Check the performance yourself by running [tests/benchmark.nim](https://github.com/guzba/zippy/blob/master/tests/benchmark.nim).

`nim c --gc:arc -d:release -r .\tests\benchmark.nim` (1000 uncompresses, lower time is better)

**https://github.com/guzba/zippy** results:
File | Time
--- | ---:
randtest3.z | 0.0519s
rfctest3.z | 0.3295s
alice29.txt.z | 1.4704s
urls.10K.z | 7.3240s
fixed.z | 6.6955s

https://github.com/treeform/miniz results:
File | Time
--- | ---:
randtest3.z | 0.5803s
rfctest3.z |0.5801s
alice29.txt.z | 3.3442s
urls.10K.z | 16.1209s
fixed.z | 19.8003s

https://github.com/nim-lang/nimPNG results:
File | Time
--- | ---:
randtest3.z | 0.1648s
rfctest3.z | 0.5760s
alice29.txt.z | 2.2471s
urls.10K.z | 11.0067s
fixed.z | 10.0772s

https://github.com/nim-lang/zip results: (Requires zlib1.dll)
File | Time
--- | ---:
randtest3.z | 0.0061s
rfctest3.z | 0.1285s
alice29.txt.z | 0.4918s
urls.10K.z | 2.2510s
fixed.z | 2.1033s

### Testing
`nimble test`

To prevent Zippy from causing a crash or otherwise misbehaving on bad input data, a fuzzer has been run against it. You can do run the fuzzer any time by running `nim c -r tests/fuzz.nim`

### Credits

This implementation has been greatly assisted by [zlib-inflate-simple](https://github.com/toomuchvoltage/zlib-inflate-simple) which is by far the smallest and most readable implementation I've found.

# API: zippy

```nim
import zippy
```

## **func** uncompress

Uncompresses src into dst. This resizes dst as needed and starts writing at dst index 0.

```nim
func uncompress(src: seq[uint8]; dst: var seq[uint8]) {.raises: [ZippyError], tags: [].}
```

## **func** uncompress

Uncompresses src and returns the uncompressed data seq.

```nim
func uncompress(src: seq[uint8]): seq[uint8] {.inline, raises: [ZippyError], tags: [].}
```

## **template** uncompress

Helper for when preferring to work with strings.

```nim
template uncompress(src: string): string
```
