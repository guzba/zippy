# Zippy

`nimble install zippy`

Zippy is an implementation of [DEFLATE](https://tools.ietf.org/html/rfc1951), [ZLIB](https://tools.ietf.org/html/rfc1950), [GZIP](https://tools.ietf.org/html/rfc1952) and [ZIP archives](https://en.wikipedia.org/wiki/Zip_(file_format)) (in-progress).

The goal of this library is to be a pure Nim implementation that is small, performant and dependency-free.

Zippy can also be used at compile time. This is great for baking assets into executables in compressed form. [Check out an example here](https://github.com/guzba/zippy/blob/master/examples/compiletime.nim).

To ensure Zippy is compatible with other implementations, `tests/validate.nim` can be run. This script verifies that data compressed by Zippy can be uncompressed by other implementations (and that other implementations can uncompress data compressed by Zippy).

This library works well using Nim's relatively new `--gc:arc` and `--gc:orc` as well as the default garbage collector. This library also works using both `nim c` and `nim cpp`, in addition to `--cc:vcc` on Windows.

I have also verified that Zippy builds with `--experimental:strictFuncs` on Nim 1.4.0.

## Examples

Simple examples using Zippy can be found in the [examples/](https://github.com/guzba/zippy/blob/master/examples) folder. This includes an [HTTP client](https://github.com/guzba/zippy/blob/master/examples/http_client.nim) and [HTTP server](https://github.com/guzba/zippy/blob/master/examples/http_server.nim) example for handing gzip'ed requests and responses.

## Performance

Benchmarks can be run comparing different deflate implementations. My benchmarking shows this library performs very well but it is not quite as fast as zlib at uncompressing just yet (not a surprise). Check the performance yourself by running [tests/benchmark.nim](https://github.com/guzba/zippy/blob/master/tests/benchmark.nim).

`nim c -d:release -r .\tests\benchmark.nim`

### Compress

Each file is compressed 1000 times.

#### Default compression

**https://github.com/guzba/zippy** results:
File | Time | Size Reduction
--- | --- | ---:
alice29.txt | 3.7798s | 63.32%
urls.10K | 19.7357s | 67.49%
rfctest3.gold | 0.6802s | 70.73%
randtest3.gold | 0.1073s | 0%
paper-100k.pdf | 1.9175s | 19.94%
geo.protodata | 1.2939s | 86.91%

https://github.com/nim-lang/zip results: (Requires zlib1.dll)
File | Time | Size Reduction
--- | --- | ---:
alice29.txt | 6.8945s | 64.23%
urls.10K | 16.3272s | 68.29%
rfctest3.gold | 0.8147s | 71.74%
randtest3.gold | 0.1545s | 0%
paper-100k.pdf | 1.8938s | 20.59%
geo.protodata | 1.0743s | 87.24%

#### Fastest compression

**https://github.com/guzba/zippy** results:
File | Time | Size Reduction
--- | --- | ---:
alice29.txt | 1.5847s | 55.32%
urls.10K | 5.2101s | 61.70%
rfctest3.gold | 0.4295s | 66.31%
randtest3.gold | 0.0382s | 0%
paper-100k.pdf | 1.0918s | 18.44%
geo.protodata | 0.8353s | 80.42%

https://github.com/nim-lang/zip results: (Requires zlib1.dll)
File | Time | Size Reduction
--- | --- | ---:
alice29.txt | 1.7779s | 57.17%
urls.10K | 7.3260s | 63.93%
rfctest3.gold | 0.3270s | 67.53%
randtest3.gold | 0.1189s | 0%
paper-100k.pdf | 1.6632s | 20.22%
geo.protodata | 0.4888s | 84.12%

#### Best compression

**https://github.com/guzba/zippy** results:
File | Time | Size Reduction
--- | --- | ---:
alice29.txt | 4.5985s | 63.75%
urls.10K | 28.5602s | 68.14%
rfctest3.gold | 1.3401s | 70.92%
randtest3.gold | 0.1257s | 0%
paper-100k.pdf | 2.1010s | 20.07%
geo.protodata | 1.5293s | 87.07%

https://github.com/nim-lang/zip results: (Requires zlib1.dll)
File | Time | Size Reduction
--- | --- | ---:
alice29.txt | 9.9339s | 64.38%
urls.10K | 30.5398s | 68.82%
rfctest3.gold | 2.6180s | 71.77%
randtest3.gold | 0.1169s | 0%
paper-100k.pdf | 2.0639s | 20.64%
geo.protodata | 1.4266s | 87.37%

### Uncompress

Each file is uncompressed 1000 times:

**https://github.com/guzba/zippy** results:
File | Time
--- | ---:
alice29.txt | 0.5163s
urls.10K | 2.5521s
rfctest3.gold | 0.1240s
randtest3.gold | 0.0128s
paper-100k.pdf | 0.4829s
geo.protodata | 0.1940s

https://github.com/nim-lang/zip results: (Requires zlib1.dll)
File | Time
--- | ---:
alice29.txt | 0.4806s
urls.10K | 1.9870s
rfctest3.gold | 0.1285s
randtest3.gold | 0.0053s
paper-100k.pdf | 0.3139s
geo.protodata | 0.1957s

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
