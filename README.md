# Zippy

![Github Actions](https://github.com/guzba/zippy/workflows/Github%20Actions/badge.svg)

`nimble install zippy`

Zippy is an implementation of [DEFLATE](https://tools.ietf.org/html/rfc1951), [ZLIB](https://tools.ietf.org/html/rfc1950) and [GZIP](https://tools.ietf.org/html/rfc1952) data compression formats. Zippy can also create and open [Tarballs](https://en.wikipedia.org/wiki/Tar_(computing)) (.tar, .tar.gz, .tgz, .taz) and [ZIP archives](https://en.wikipedia.org/wiki/Zip_(file_format)).

The goal of this library is to be a pure Nim implementation that is small, performant and dependency-free.

Zippy can also be used at compile time. This is great for baking assets into executables in compressed form. [Check out an example here](https://github.com/guzba/zippy/blob/master/examples/compiletime.nim).

To ensure Zippy is compatible with other implementations, `tests/validate.nim` can be run. This script verifies that data compressed by Zippy can be uncompressed by other implementations (and that other implementations can uncompress data compressed by Zippy).

This library works well using Nim's relatively new `--gc:arc` and `--gc:orc` as well as the default garbage collector. This library also works using both `nim c` and `nim cpp`, in addition to `--cc:vcc` on Windows.

I have also verified that Zippy builds with `--experimental:strictFuncs` on Nim 1.4.0.

## Examples

Simple examples using Zippy can be found in the [examples/](https://github.com/guzba/zippy/blob/master/examples) folder.

* [HTTP client gzip](https://github.com/guzba/zippy/blob/master/examples/http_client.nim)
* [HTTP server gzip](https://github.com/guzba/zippy/blob/master/examples/http_server.nim)
* Compress a dir into a [tarball](https://github.com/guzba/zippy/blob/master/examples/tarball_create.nim) or [zip archive](https://github.com/guzba/zippy/blob/master/examples/ziparchive_create.nim)
* Extract from a [tarball](https://github.com/guzba/zippy/blob/master/examples/tarball_extract.nim) or [zip archive](https://github.com/guzba/zippy/blob/master/examples/ziparchive_extract.nim)
* Compose a [tarball](https://github.com/guzba/zippy/blob/master/examples/tarball_compose.nim) or [zip archive](https://github.com/guzba/zippy/blob/master/examples/ziparchive_compose.nim) in code

## Performance

Benchmarks can be run comparing different deflate implementations. My benchmarking shows this library performs very well, a bit faster than zlib in some cases and a bit slower in others. Check the performance yourself by running [tests/benchmark.nim](https://github.com/guzba/zippy/blob/master/tests/benchmark.nim).

`nim c -d:release -r .\tests\benchmark.nim`

The times below are measured on a Ryzen 5 5600X.

### Compress

Each file is compressed 10 times per run.

```
https://github.com/guzba/zippy compress [default]
name ............................... min time      avg time    std dv   runs
alice29.txt ....................... 26.283 ms     26.455 ms    ±0.171   x189
urls.10K ......................... 149.912 ms    150.698 ms    ±0.442    x34
rfctest3.gold ...................... 4.282 ms      4.309 ms    ±0.021  x1000
randtest3.gold ..................... 0.640 ms      0.647 ms    ±0.004  x1000
paper-100k.pdf .................... 12.240 ms     12.378 ms    ±0.054   x404
geo.protodata ...................... 7.920 ms      7.960 ms    ±0.020   x628
gzipfiletest.txt ................... 0.114 ms      0.116 ms    ±0.001  x1000
https://github.com/nim-lang/zip compress [default]
alice29.txt ....................... 57.920 ms     58.002 ms    ±0.098    x87
urls.10K ......................... 132.537 ms    132.725 ms    ±0.167    x38
rfctest3.gold ...................... 6.517 ms      6.583 ms    ±0.062   x758
randtest3.gold ..................... 0.887 ms      0.900 ms    ±0.011  x1000
paper-100k.pdf .................... 15.001 ms     15.095 ms    ±0.053   x331
geo.protodata ...................... 9.001 ms      9.076 ms    ±0.051   x550
gzipfiletest.txt ................... 0.119 ms      0.123 ms    ±0.005  x1000

https://github.com/guzba/zippy compress [best speed]
alice29.txt ........................ 8.081 ms      8.126 ms    ±0.027   x615
urls.10K .......................... 27.473 ms     27.668 ms    ±0.179   x181
rfctest3.gold ...................... 2.046 ms      2.067 ms    ±0.010  x1000
randtest3.gold ..................... 0.177 ms      0.179 ms    ±0.002  x1000
paper-100k.pdf ..................... 5.474 ms      5.530 ms    ±0.018   x903
geo.protodata ...................... 4.281 ms      4.315 ms    ±0.023  x1000
gzipfiletest.txt ................... 0.053 ms      0.054 ms    ±0.000  x1000
https://github.com/nim-lang/zip compress [best speed]
alice29.txt ....................... 12.773 ms     12.862 ms    ±0.107   x389
urls.10K .......................... 53.200 ms     53.331 ms    ±0.117    x94
rfctest3.gold ...................... 2.178 ms      2.196 ms    ±0.013  x1000
randtest3.gold ..................... 0.810 ms      0.830 ms    ±0.017  x1000
paper-100k.pdf .................... 12.811 ms     12.879 ms    ±0.070   x388
geo.protodata ...................... 3.491 ms      3.522 ms    ±0.023  x1000
gzipfiletest.txt ................... 0.093 ms      0.095 ms    ±0.003  x1000

https://github.com/guzba/zippy compress [best compression]
alice29.txt ....................... 32.892 ms     32.972 ms    ±0.117   x152
urls.10K ......................... 224.219 ms    226.611 ms    ±2.096    x23
rfctest3.gold ...................... 9.547 ms      9.727 ms    ±0.189   x513
randtest3.gold ..................... 0.624 ms      0.636 ms    ±0.007  x1000
paper-100k.pdf .................... 12.618 ms     12.785 ms    ±0.110   x390
geo.protodata ...................... 8.643 ms      8.722 ms    ±0.105   x572
gzipfiletest.txt ................... 0.115 ms      0.116 ms    ±0.001  x1000
https://github.com/nim-lang/zip compress [best compression]
alice29.txt ....................... 85.740 ms     86.351 ms    ±0.625    x58
urls.10K ......................... 252.118 ms    252.508 ms    ±0.277    x20
rfctest3.gold ..................... 21.734 ms     21.816 ms    ±0.091   x229
randtest3.gold ..................... 0.887 ms      0.901 ms    ±0.014  x1000
paper-100k.pdf .................... 16.753 ms     16.819 ms    ±0.042   x297
geo.protodata ..................... 12.249 ms     12.324 ms    ±0.064   x406
gzipfiletest.txt ................... 0.120 ms      0.124 ms    ±0.006  x1000
```

### Uncompress

Each file is uncompressed 10 times per run.

```
https://github.com/guzba/zippy uncompress
alice29.txt.z ...................... 3.407 ms      3.438 ms    ±0.019  x1000
urls.10K.z ........................ 15.872 ms     15.994 ms    ±0.139   x313
rfctest3.z ......................... 0.723 ms      0.740 ms    ±0.014  x1000
randtest3.z ........................ 0.067 ms      0.068 ms    ±0.000  x1000
paper-100k.pdf.z ................... 2.669 ms      2.679 ms    ±0.006  x1000
geo.protodata.z .................... 1.188 ms      1.214 ms    ±0.030  x1000
https://github.com/nim-lang/zip uncompress
alice29.txt.z ...................... 3.524 ms      3.561 ms    ±0.016  x1000
urls.10K.z ........................ 15.038 ms     15.086 ms    ±0.030   x332
rfctest3.z ......................... 0.450 ms      0.454 ms    ±0.005  x1000
randtest3.z ........................ 0.064 ms      0.065 ms    ±0.001  x1000
paper-100k.pdf.z ................... 2.206 ms      2.214 ms    ±0.011  x1000
geo.protodata.z .................... 0.900 ms      0.928 ms    ±0.035  x1000
```

## Testing

`nimble test`

To prevent Zippy from causing a crash or otherwise misbehaving on bad input data, a fuzzer has been run against it. You can do run the fuzzer any time by running `nim c -r tests/fuzz.nim` and `nim c -r tests/stress.nim`

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

## **type** ZippyError

Raised if an operation fails.

```nim
ZippyError = object of ValueError
```

# API: zippy/tarballs

```nim
import zippy/tarballs
```

## **type** EntryKind

```nim
EntryKind = enum
 ekNormalFile = 48, ekDirectory = 53
```

## **type** TarballEntry


```nim
TarballEntry = object
 kind*: EntryKind
 contents*: string
 lastModified*: times.Time
```

## **type** Tarball


```nim
Tarball = ref object
 contents*: OrderedTable[string, TarballEntry]
```

## **proc** addDir

Recursively adds all of the files and directories inside dir to tarball.

```nim
proc addDir(tarball: Tarball; dir: string) {.raises: [ZippyError, OSError, IOError], tags: [ReadDirEffect, ReadIOEffect].}
```

## **proc** clear


```nim
proc clear(tarball: Tarball)
```

## **proc** open

Opens the tarball file located at path and reads its contents into tarball.contents (clears any existing tarball.contents entries). Supports .tar, .tar.gz, .taz and .tgz file extensions.

```nim
proc open(tarball: Tarball; path: string) {.raises: [IOError, ZippyError, ZippyError], tags: [ReadIOEffect].}
```

## **proc** open

Opens the tarball from a stream and reads its contents into tarball.contents (clears any existing tarball.contents entries).

```nim
proc open(tarball: Tarball; stream: Stream) {.raises: [IOError, ZippyError, OSError], tags: [ReadIOEffect].}

## **proc** writeTarball

Writes tarball.contents to a tarball file at path. Uses the path's file extension to determine the tarball format. Supports .tar, .tar.gz, .taz and .tgz file extensions.

```nim
proc writeTarball(tarball: Tarball; path: string) {.raises: [ZippyError, IOError], tags: [WriteIOEffect].}
```

## **proc** extractAll

Extracts the files stored in tarball to the destination directory. The path to the destination directory must exist. The destination directory itself must not exist (it is not overwitten).

```nim
proc extractAll(tarball: Tarball; dest: string) {.raises: [ZippyError, OSError, IOError], tags: [ReadDirEffect, ReadEnvEffect, ReadIOEffect, WriteDirEffect, WriteIOEffect].}
```

## **proc** extractAll

Extracts the files in the tarball located at tarPath into the destination directory. Supports .tar, .tar.gz, .taz and .tgz file extensions.

```nim
proc extractAll(tarPath, dest: string) {.raises: [IOError, ZippyError, OSError], tags: [
 ReadIOEffect, ReadDirEffect, ReadEnvEffect, WriteDirEffect, WriteIOEffect].}
```

## **proc** createTarball

Creates a tarball containing all of the files and directories inside source and writes the tarball file to dest. Uses the dest path's file extension to determine the tarball format. Supports .tar, .tar.gz, .taz and .tgz file extensions.

```nim
proc createTarball(source, dest: string) {.raises: [ZippyError, OSError, IOError], tags: [ReadDirEffect, ReadIOEffect, WriteIOEffect].}
```

# API: zippy/ziparchives

```nim
import zippy/ziparchives
```

## **type** EntryKind


```nim
EntryKind = enum
 ekFile, ekDirectory
```

## **type** ArchiveEntry


```nim
ArchiveEntry = object
 kind*: EntryKind
 contents*: string
```

## **type** ZipArchive


```nim
ZipArchive = ref object
 contents*: OrderedTable[string, ArchiveEntry]
```

## **proc** addDir

Recursively adds all of the files and directories inside dir to archive.

```nim
proc addDir(archive: ZipArchive; dir: string) {.raises: [ZippyError, OSError, IOError], tags: [ReadDirEffect, ReadIOEffect].}
```

## **proc** clear


```nim
proc clear(archive: ZipArchive)
```

## **proc** open

Opens the zip archive file located at path and reads its contents into archive.contents (clears any existing archive.contents entries).

```nim
proc open(archive: ZipArchive; path: string) {.raises: [IOError, ZippyError, ZippyError], tags: [ReadIOEffect].}
```

## **proc** open

Opens the zip archive from a stream and reads its contents into archive.contents (clears any existing archive.contents entries).

```nim
proc open(archive: ZipArchive; stream: Stream) {.raises: [IOError, ZippyError, OSError], tags: [ReadIOEffect].}
```

## **proc** writeZipArchive

Writes archive.contents to a zip file at path.

```nim
proc writeZipArchive(archive: ZipArchive; path: string) {.raises: [ZippyError, ZippyError, IOError], tags: [WriteIOEffect].}
```

## **proc** extractAll

Extracts the files stored in archive to the destination directory. The path to the destination directory must exist. The destination directory itself must not exist (it is not overwitten).

```nim
proc extractAll(archive: ZipArchive; dest: string) {.raises: [ZippyError, OSError, IOError], tags: [ReadDirEffect, ReadEnvEffect, ReadIOEffect, WriteDirEffect, WriteIOEffect].}
```

## **proc** extractAll

Extracts the files in the archive located at zipPath into the destination directory.

```nim
proc extractAll(zipPath, dest: string) {.raises: [IOError, ZippyError, OSError], tags: [
 ReadIOEffect, ReadDirEffect, ReadEnvEffect, WriteDirEffect, WriteIOEffect].}
```

## **proc** createZipArchive

Creates an archive containing all of the files and directories inside source and writes the zip file to dest.

```nim
proc createZipArchive(source, dest: string) {.raises: [ZippyError, OSError, IOError], tags: [ReadDirEffect, ReadIOEffect, WriteIOEffect].}
```
