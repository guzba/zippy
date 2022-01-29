# Zippy

![Github Actions](https://github.com/guzba/zippy/workflows/Github%20Actions/badge.svg)

`nimble install zippy`

Zippy is an implementation of [DEFLATE](https://tools.ietf.org/html/rfc1951), [ZLIB](https://tools.ietf.org/html/rfc1950) and [GZIP](https://tools.ietf.org/html/rfc1952) data compression formats.

Zippy can also open [ZIP archives](https://en.wikipedia.org/wiki/Zip_(file_format)) (.zip) and [Tarballs](https://en.wikipedia.org/wiki/Tar_(computing)) (.tar, .tar.gz, .tgz, .taz).

The goal of this library is to be a pure Nim implementation that is small, performant and dependency-free.

To ensure Zippy is compatible with other implementations, `tests/validate.nim` can be run. This script verifies that data compressed by Zippy can be uncompressed by other implementations (and that other implementations can uncompress data compressed by Zippy).

This library works well using Nim's `--gc:arc` and `--gc:orc` as well as the default garbage collector. This library also works using both `nim c` and `nim cpp`, in addition to `--cc:vcc` on Windows.

## Documentation

https://nimdocs.com/guzba/zippy/zippy.html

## Examples

Simple examples using Zippy can be found in the [examples/](https://github.com/guzba/zippy/blob/master/examples) folder.

* [HTTP client gzip](https://github.com/guzba/zippy/blob/master/examples/http_client.nim)
* [HTTP server gzip](https://github.com/guzba/zippy/blob/master/examples/http_server.nim)
* Extract from a [zip archive](https://github.com/guzba/zippy/blob/master/examples/ziparchive_extract.nim) or [tarball](https://github.com/guzba/zippy/blob/master/examples/tarball_extract.nim)

## Performance

Benchmarks can be run comparing different deflate implementations. My benchmarking shows this library performs very well, a bit faster than zlib in some cases and a bit slower in others. Check the performance yourself by running [tests/benchmark.nim](https://github.com/guzba/zippy/blob/master/tests/benchmark.nim).

`nim c --gc:arc -d:release -r .\tests\benchmark.nim`

The times below are measured on a Ryzen 5 5600X.

### Compress

```
https://github.com/guzba/zippy compress [best speed]
alice29.txt ........................ 0.646 ms      0.651 ms    ±0.006  x1000
urls.10K ........................... 1.956 ms      1.966 ms    ±0.013  x1000
rfctest3.gold ...................... 0.119 ms      0.121 ms    ±0.002  x1000
randtest3.gold ..................... 0.007 ms      0.008 ms    ±0.001  x1000
paper-100k.pdf ..................... 0.240 ms      0.243 ms    ±0.002  x1000
geo.protodata ...................... 0.189 ms      0.192 ms    ±0.003  x1000
gzipfiletest.txt ................... 0.002 ms      0.002 ms    ±0.000  x1000
tor-list.gold ..................... 27.618 ms     27.756 ms    ±0.134   x180
https://github.com/nim-lang/zip compress [best speed]
alice29.txt ........................ 1.233 ms      1.244 ms    ±0.009  x1000
urls.10K ........................... 5.135 ms      5.169 ms    ±0.025   x966
rfctest3.gold ...................... 0.204 ms      0.208 ms    ±0.005  x1000
randtest3.gold ..................... 0.075 ms      0.077 ms    ±0.002  x1000
paper-100k.pdf ..................... 1.248 ms      1.258 ms    ±0.008  x1000
geo.protodata ...................... 0.314 ms      0.317 ms    ±0.003  x1000
gzipfiletest.txt ................... 0.006 ms      0.006 ms    ±0.001  x1000
tor-list.gold .................... 177.602 ms    178.482 ms    ±0.547    x29

https://github.com/guzba/zippy compress [default]
name ............................... min time      avg time    std dv   runs
alice29.txt ........................ 2.332 ms      2.392 ms    ±0.042  x1000
urls.10K .......................... 13.271 ms     13.366 ms    ±0.126   x373
rfctest3.gold ...................... 0.334 ms      0.337 ms    ±0.003  x1000
randtest3.gold ..................... 0.048 ms      0.048 ms    ±0.001  x1000
paper-100k.pdf ..................... 0.824 ms      0.841 ms    ±0.011  x1000
geo.protodata ...................... 0.549 ms      0.553 ms    ±0.004  x1000
gzipfiletest.txt ................... 0.008 ms      0.009 ms    ±0.001  x1000
tor-list.gold .................... 419.855 ms    422.444 ms    ±1.826    x12
https://github.com/nim-lang/zip compress [default]
alice29.txt ........................ 5.721 ms      5.738 ms    ±0.016   x870
urls.10K .......................... 13.021 ms     13.081 ms    ±0.050   x382
rfctest3.gold ...................... 0.637 ms      0.645 ms    ±0.010  x1000
randtest3.gold ..................... 0.088 ms      0.112 ms    ±0.009  x1000
paper-100k.pdf ..................... 1.470 ms      1.502 ms    ±0.019  x1000
geo.protodata ...................... 0.866 ms      0.880 ms    ±0.012  x1000
gzipfiletest.txt ................... 0.009 ms      0.009 ms    ±0.001  x1000
tor-list.gold .................... 243.360 ms    244.181 ms    ±0.699    x21
```

### Uncompress

```
https://github.com/guzba/zippy uncompress
alice29.txt.z ...................... 0.299 ms      0.301 ms    ±0.003  x1000
urls.10K.z ......................... 1.398 ms      1.410 ms    ±0.006  x1000
rfctest3.z ......................... 0.058 ms      0.060 ms    ±0.002  x1000
randtest3.z ........................ 0.003 ms      0.004 ms    ±0.000  x1000
paper-100k.pdf.z ................... 0.247 ms      0.249 ms    ±0.001  x1000
geo.protodata.z .................... 0.102 ms      0.102 ms    ±0.001  x1000
tor-list.z ........................ 32.046 ms     32.348 ms    ±0.261   x155
https://github.com/nim-lang/zip uncompress
alice29.txt.z ...................... 0.354 ms      0.358 ms    ±0.003  x1000
urls.10K.z ......................... 1.522 ms      1.532 ms    ±0.005  x1000
rfctest3.z ......................... 0.042 ms      0.043 ms    ±0.001  x1000
randtest3.z ........................ 0.004 ms      0.004 ms    ±0.000  x1000
paper-100k.pdf.z ................... 0.217 ms      0.219 ms    ±0.003  x1000
geo.protodata.z .................... 0.088 ms      0.093 ms    ±0.004  x1000
tor-list.z ........................ 31.428 ms     31.688 ms    ±0.179   x158
```

## Testing

`nimble test`

To prevent Zippy from causing a crash or otherwise misbehaving on bad input data, a fuzzer has been run against it. You can do run the fuzzer any time by running `nim c -r tests/fuzz.nim` and `nim c -r tests/stress.nim`
