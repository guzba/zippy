# Zippy

`nimble install zippy`

Zippy is an implementation of [DEFLATE](https://tools.ietf.org/html/rfc1951), [ZLIB](https://tools.ietf.org/html/rfc1950), [GZIP](https://tools.ietf.org/html/rfc1952) and [ZIP archives](https://en.wikipedia.org/wiki/Zip_(file_format)) (in-progress).

The goal of this library is to be a pure Nim implementation that is small, performant and dependency-free.

Zippy can also be used at compile time. This is great for baking assets into executables in compressed form. [Check out an example here](https://github.com/guzba/zippy/blob/master/examples/compiletime.nim).

To ensure Zippy is compatible with other implementations, `tests/validate.nim` can be run. This script verifies that data compressed by Zippy can be uncompressed by other implementations (and that other implementations can uncompress data compressed by Zippy).

This library also works using both nim c and nim cpp, in addition to --cc:vcc on Windows.

I have also verified that Zippy builds with `--experimental:strictFuncs` on Nim 1.4.0.

**NOTE: This library is in active development. It is tested and should work well, but the API is not yet stable.**

## Examples

Simple examples using Zippy can be found in the [examples/](https://github.com/guzba/zippy/blob/master/examples) folder. This includes an [HTTP client](https://github.com/guzba/zippy/blob/master/examples/http_client.nim) and [HTTP server](https://github.com/guzba/zippy/blob/master/examples/http_server.nim) example for handing gzip'ed requests and responses.

## Performance

Benchmarks can be run comparing different deflate implementations. My benchmarking shows this library performs very well but it is not quite as fast as zlib at uncompressing just yet (not a surprise). Check the performance yourself by running [tests/benchmark.nim](https://github.com/guzba/zippy/blob/master/tests/benchmark.nim).

`nim c -d:release -r .\tests\benchmark.nim`

### Compress

Each file is compressed 1000 times.

#### Default compression

**https://github.com/guzba/zippy** results:
File | Time | % Size Reduction
--- | --- | ---:
alice29.txt | 4.3357s | 62.53%
urls.10K | 15.8984s | 67.57%
rfctest3.gold | 0.9038s | 70.96%
randtest3.gold | 0.1568s | 0%

https://github.com/nim-lang/zip results: (Requires zlib1.dll)
File | Time | % Size Reduction
--- | --- | ---:
alice29.txt | 7.0150s | 64.23%
urls.10K | 16.6361s | 68.29%
rfctest3.gold | 0.8147s | 71.74%
randtest3.gold | 0.1545s | 0%

#### Fastest compression

**https://github.com/guzba/zippy** results:
File | Time | % Size Reduction
--- | --- | ---:
alice29.txt | 1.6575s | 55.32%
urls.10K | 5.4517s | 61.70%
rfctest3.gold | 0.5362s | 66.31%
randtest3.gold | 0.0646s | 0%

https://github.com/nim-lang/zip results: (Requires zlib1.dll)
File | Time | % Size Reduction
--- | --- | ---:
alice29.txt | 1.7779s | 57.17%
urls.10K | 7.3260s | 63.93%
rfctest3.gold | 0.3270s | 67.53%
randtest3.gold | 0.1189s | 0%

#### Best compression

**https://github.com/guzba/zippy** results:

(In-progress)

https://github.com/nim-lang/zip results: (Requires zlib1.dll)
File | Time | % Size Reduction
--- | --- | ---:
alice29.txt | 10.0080s | 64.38%
urls.10K | 30.6367s | 68.82%
rfctest3.gold | 2.6664s | 71.77%
randtest3.gold | 0.1557s | 0%

### Uncompress

Each file is uncompressed 1000 times:

**https://github.com/guzba/zippy** results:
File | Time
--- | ---:
alice29.txt | 0.9706s
urls.10K | 4.7821s
rfctest3.gold | 0.2142s
randtest3.gold | 0.0378s

https://github.com/nim-lang/zip results: (Requires zlib1.dll)
File | Time
--- | ---:
alice29.txt | 0.4929s
urls.10K | 2.2334s
rfctest3.gold | 0.1148s
randtest3.gold | 0.0053s


## Testing
`nimble test`

To prevent Zippy from causing a crash or otherwise misbehaving on bad input data, a fuzzer has been run against it. You can do run the fuzzer any time by running `nim c -r tests/fuzz.nim`

# API: zippy

```nim
import zippy
```

## **const** NoCompression


```nim
NoCompression = 0
```

## **const** BestSpeed


```nim
BestSpeed = 1
```

## **const** BestCompression


```nim
BestCompression = 9
```

## **const** DefaultCompression


```nim
DefaultCompression = -1
```

## **const** HuffmanOnly


```nim
HuffmanOnly = -2
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
func compress(src: seq[uint8]; level = DefaultCompression; dataFormat = dfGzip): seq[
 uint8] {.raises: [ZippyError].}
```

## **template** compress

Helper for when preferring to work with strings.

```nim
template compress(src: string; level = DefaultCompression; dataFormat = dfGzip): string
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
