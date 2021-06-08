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
alice29.txt ....................... 29.101 ms     29.338 ms    ±0.266   x171
urls.10K ......................... 157.513 ms    159.976 ms    ±1.744    x32
rfctest3.gold ...................... 4.721 ms      4.757 ms    ±0.014  x1000
randtest3.gold ..................... 0.667 ms      0.672 ms    ±0.004  x1000
paper-100k.pdf .................... 14.197 ms     14.342 ms    ±0.044   x349
geo.protodata ...................... 8.341 ms      8.371 ms    ±0.017   x597
gzipfiletest.txt ................... 0.119 ms      0.121 ms    ±0.001  x1000
https://github.com/nim-lang/zip compress [default]
alice29.txt ....................... 57.894 ms     57.978 ms    ±0.075    x87
urls.10K ......................... 132.426 ms    132.706 ms    ±0.269    x38
rfctest3.gold ...................... 6.513 ms      6.560 ms    ±0.038   x761
randtest3.gold ..................... 0.890 ms      0.905 ms    ±0.011  x1000
paper-100k.pdf .................... 15.000 ms     15.076 ms    ±0.059   x332
geo.protodata ...................... 8.994 ms      9.052 ms    ±0.036   x552
gzipfiletest.txt ................... 0.119 ms      0.121 ms    ±0.003  x1000

https://github.com/guzba/zippy compress [best speed]
alice29.txt ....................... 11.782 ms     11.867 ms    ±0.050   x422
urls.10K .......................... 37.809 ms     37.927 ms    ±0.096   x132
rfctest3.gold ...................... 2.639 ms      2.672 ms    ±0.009  x1000
randtest3.gold ..................... 0.231 ms      0.233 ms    ±0.001  x1000
paper-100k.pdf ..................... 7.660 ms      7.768 ms    ±0.055   x643
geo.protodata ...................... 5.122 ms      5.177 ms    ±0.016   x966
gzipfiletest.txt ................... 0.058 ms      0.060 ms    ±0.002  x1000
https://github.com/nim-lang/zip compress [best speed]
alice29.txt ....................... 12.765 ms     12.842 ms    ±0.059   x389
urls.10K .......................... 53.202 ms     53.425 ms    ±0.130    x94
rfctest3.gold ...................... 2.176 ms      2.198 ms    ±0.018  x1000
randtest3.gold ..................... 0.814 ms      0.829 ms    ±0.015  x1000
paper-100k.pdf .................... 12.806 ms     12.862 ms    ±0.041   x389
geo.protodata ...................... 3.486 ms      3.519 ms    ±0.030  x1000
gzipfiletest.txt ................... 0.092 ms      0.094 ms    ±0.003  x1000

https://github.com/guzba/zippy compress [best compression]
alice29.txt ....................... 35.847 ms     35.949 ms    ±0.082   x139
urls.10K ......................... 232.589 ms    232.866 ms    ±0.252    x22
rfctest3.gold ..................... 10.049 ms     10.121 ms    ±0.035   x494
randtest3.gold ..................... 0.667 ms      0.671 ms    ±0.005  x1000
paper-100k.pdf .................... 14.570 ms     14.719 ms    ±0.062   x340
geo.protodata ...................... 9.045 ms      9.076 ms    ±0.018   x551
gzipfiletest.txt ................... 0.119 ms      0.121 ms    ±0.002  x1000
https://github.com/nim-lang/zip compress [best compression]
alice29.txt ....................... 85.729 ms     85.906 ms    ±0.166    x59
urls.10K ......................... 251.942 ms    252.312 ms    ±0.392    x20
rfctest3.gold ..................... 21.735 ms     21.782 ms    ±0.033   x230
randtest3.gold ..................... 0.887 ms      0.896 ms    ±0.008  x1000
paper-100k.pdf .................... 16.748 ms     16.885 ms    ±0.105   x296
geo.protodata ..................... 12.244 ms     12.303 ms    ±0.044   x406
gzipfiletest.txt ................... 0.119 ms      0.125 ms    ±0.009  x1000
```

### Uncompress

Each file is uncompressed 10 times per run.

```
https://github.com/guzba/zippy uncompress
alice29.txt.z ...................... 3.618 ms      3.640 ms    ±0.023  x1000
urls.10K.z ........................ 16.452 ms     16.490 ms    ±0.026   x304
rfctest3.z ......................... 0.765 ms      0.786 ms    ±0.008  x1000
randtest3.z ........................ 0.133 ms      0.134 ms    ±0.002  x1000
paper-100k.pdf.z ................... 3.090 ms      3.104 ms    ±0.010  x1000
geo.protodata.z .................... 1.224 ms      1.255 ms    ±0.011  x1000
https://github.com/nim-lang/zip uncompress
alice29.txt.z ...................... 3.523 ms      3.559 ms    ±0.014  x1000
urls.10K.z ........................ 14.985 ms     15.013 ms    ±0.016   x333
rfctest3.z ......................... 0.449 ms      0.455 ms    ±0.005  x1000
randtest3.z ........................ 0.064 ms      0.065 ms    ±0.000  x1000
paper-100k.pdf.z ................... 2.204 ms      2.210 ms    ±0.005  x1000
geo.protodata.z .................... 0.907 ms      0.933 ms    ±0.017  x1000
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
