# Zippy

`nimble install zippy`

Zippy is an implementation of [DEFLATE](https://tools.ietf.org/html/rfc1951), [ZLIB](https://tools.ietf.org/html/rfc1950), [GZIP](https://tools.ietf.org/html/rfc1952) and [ZIP](https://en.wikipedia.org/wiki/Zip_(file_format)).

The goal of this library is to be a pure Nim implementation that is small, performant and dependency-free.

To ensure Zippy is compatible with other Zip implementations, `tests/validate.nim` can be run. This script verifies that data compressed by Zippy can be uncompressed by other implementations (and that other implementations can uncompress data compressed by Zippy).

Zippy works well using Nim's relatively new --gc:arc and --gc:orc as well as the default garbage collector. This library also works using both nim c and nim cpp, in addition to --cc:vcc on Windows.

I have also verified that Zippy builds with `--experimental:strictFuncs` on Nim 1.4.0.

### Performance

Benchmarks can be run comparing different deflate implementations. My benchmarking shows this library performs very well but it is not as fast as zlib itself (not a surprise). Check the performance yourself by running [tests/benchmark.nim](https://github.com/guzba/zippy/blob/master/tests/benchmark.nim).

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

# API: zippy

```nim
import zippy
```

## **type** CompressedDataFormat

Supported compressed data formats

```nim
CompressedDataFormat = enum
 dfDetect, dfZlib, dfGzip, dfDeflate
```

## **func** compress

Compresses src and returns the compressed data.

```nim
func compress(src: seq[uint8]; dataFormat = dfGzip): seq[uint8] {.raises: [ZippyError].}
```

## **template** compress

Helper for when preferring to work with strings.

```nim
template compress(src: string; dataFormat = dfGzip): string
```

## **func** uncompress

Uncompresses src and returns the uncompressed data seq.

```nim
func uncompress(src: seq[uint8]; dataFormat = dfDetect): seq[uint8] {.raises: [ZippyError].}
```

## **template** uncompress

Helper for when preferring to work with strings.

```nim
template uncompress(src: string; dataFormat = dfDetect): string
```
