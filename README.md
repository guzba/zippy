# Zippy

`nimble install zippy`

Zippy is an implementation of [DEFLATE](https://tools.ietf.org/html/rfc1951), [ZLIB](https://tools.ietf.org/html/rfc1950), [GZIP](https://tools.ietf.org/html/rfc1952) and [ZIP](https://en.wikipedia.org/wiki/Zip_(file_format)).

The goal of this library is to be a pure Nim implementation that is small, performant and dependency-free.

To ensure Zippy is compatible with other Zip implementations, `tests/validate.nim` can be run. This script verifies that data compressed by Zippy can be uncompressed by other implementations (and that other implementations can uncompress data compressed by Zippy).

Zippy works well using Nim's relatively new --gc:arc and --gc:orc as well as the default garbage collector. This library also works using both nim c and nim cpp, in addition to --cc:vcc on Windows.

I have also verified that Zippy builds with `--experimental:strictFuncs` on Nim 1.4.0.

**NOTE: This library is in active development. It is tested and should work well, but the API is not yet stable.**

## Examples

Simple examples using Zippy can be found in the [examples/](https://github.com/guzba/zippy/blob/master/examples) folder. This includes an [HTTP client](https://github.com/guzba/zippy/blob/master/examples/http_client.nim) and [HTTP server](https://github.com/guzba/zippy/blob/master/examples/http_server.nim) example for handing gzip'ed requests and responses.

## Performance

Benchmarks can be run comparing different deflate implementations. My benchmarking shows this library performs very well but it is not quite as fast as zlib itself (not a surprise). Check the performance yourself by running [tests/benchmark.nim](https://github.com/guzba/zippy/blob/master/tests/benchmark.nim).

`nim c -d:release -r .\tests\benchmark.nim`

### Compress

Each file is compressed 1000 times.

**https://github.com/guzba/zippy** compress results:
File | Time | % Size Reduction
--- | --- | ---:
rfctest3 | 1.1809s | 70.91%
alice29 | 6.3391s | 62.33%
urls.10K | 20.1999s | 67.01%
randtest3 | 0.1285s | 0%

https://github.com/nim-lang/zip compress results: (Requires zlib1.dll)
File | Time | % Size Reduction
--- | --- | ---:
rfctest3 | 0.8147s | 71.74%
alice29.txt | 7.0150s | 64.23%
urls.10K | 16.6361s | 68.29%
randtest3 | 0.1545s | 0%

### Uncompress

Each file is uncompressed 1000 times.

**https://github.com/guzba/zippy** uncompress results:
File | Time
--- | ---:
rfctest3 | 0.2936s
alice29 | 1.3988s
urls.10K | 7.3736s
randtest3 | 0.0398s

https://github.com/nim-lang/zip uncompress results: (Requires zlib1.dll)
File | Time
--- | ---:
rfctest3 | 0.1148s
alice29 | 0.4929s
urls.10K | 2.2334s
randtest3 | 0.0053s


## Testing
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
