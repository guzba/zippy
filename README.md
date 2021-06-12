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
alice29.txt ....................... 27.584 ms     27.656 ms    ±0.079   x181
urls.10K ......................... 152.866 ms    153.447 ms    ±0.484    x33
rfctest3.gold ...................... 4.532 ms      4.578 ms    ±0.011  x1000
randtest3.gold ..................... 0.662 ms      0.666 ms    ±0.005  x1000
paper-100k.pdf .................... 14.489 ms     14.588 ms    ±0.055   x343
geo.protodata ...................... 8.168 ms      8.195 ms    ±0.013   x610
gzipfiletest.txt ................... 0.121 ms      0.122 ms    ±0.001  x1000
https://github.com/nim-lang/zip compress [default]
alice29.txt ....................... 57.905 ms     57.961 ms    ±0.058    x87
urls.10K ......................... 132.379 ms    132.498 ms    ±0.080    x38
rfctest3.gold ...................... 6.515 ms      6.567 ms    ±0.050   x760
randtest3.gold ..................... 0.884 ms      0.899 ms    ±0.013  x1000
paper-100k.pdf .................... 14.991 ms     15.064 ms    ±0.042   x332
geo.protodata ...................... 8.991 ms      9.062 ms    ±0.052   x551
gzipfiletest.txt ................... 0.124 ms      0.140 ms    ±0.006  x1000

https://github.com/guzba/zippy compress [best speed]
alice29.txt ........................ 9.864 ms      9.936 ms    ±0.035   x503
urls.10K .......................... 33.948 ms     34.078 ms    ±0.103   x147
rfctest3.gold ...................... 2.357 ms      2.392 ms    ±0.011  x1000
randtest3.gold ..................... 0.230 ms      0.232 ms    ±0.002  x1000
paper-100k.pdf ..................... 7.990 ms      8.044 ms    ±0.046   x621
geo.protodata ...................... 4.866 ms      4.897 ms    ±0.017  x1000
gzipfiletest.txt ................... 0.059 ms      0.060 ms    ±0.001  x1000
https://github.com/nim-lang/zip compress [best speed]
alice29.txt ....................... 12.741 ms     12.805 ms    ±0.031   x391
urls.10K .......................... 53.232 ms     53.350 ms    ±0.082    x94
rfctest3.gold ...................... 2.179 ms      2.204 ms    ±0.018  x1000
randtest3.gold ..................... 0.812 ms      0.828 ms    ±0.015  x1000
paper-100k.pdf .................... 12.803 ms     12.881 ms    ±0.054   x388
geo.protodata ...................... 3.488 ms      3.525 ms    ±0.019  x1000
gzipfiletest.txt ................... 0.092 ms      0.097 ms    ±0.007  x1000

https://github.com/guzba/zippy compress [best compression]
alice29.txt ....................... 34.461 ms     34.594 ms    ±0.076   x145
urls.10K ......................... 227.751 ms    228.222 ms    ±0.252    x22
rfctest3.gold ...................... 9.576 ms      9.839 ms    ±0.073   x509
randtest3.gold ..................... 0.665 ms      0.668 ms    ±0.004  x1000
paper-100k.pdf .................... 14.854 ms     14.953 ms    ±0.061   x335
geo.protodata ...................... 8.860 ms      8.895 ms    ±0.025   x562
gzipfiletest.txt ................... 0.121 ms      0.122 ms    ±0.002  x1000
https://github.com/nim-lang/zip compress [best compression]
alice29.txt ....................... 85.653 ms     85.750 ms    ±0.075    x59
urls.10K ......................... 251.762 ms    252.114 ms    ±0.355    x20
rfctest3.gold ..................... 21.730 ms     21.789 ms    ±0.035   x230
randtest3.gold ..................... 0.887 ms      0.899 ms    ±0.013  x1000
paper-100k.pdf .................... 16.742 ms     16.845 ms    ±0.069   x297
geo.protodata ..................... 12.245 ms     12.318 ms    ±0.037   x406
gzipfiletest.txt ................... 0.126 ms      0.141 ms    ±0.006  x1000
```

### Uncompress

Each file is uncompressed 10 times per run.

```
https://github.com/guzba/zippy uncompress
alice29.txt.z ...................... 3.607 ms      3.616 ms    ±0.006  x1000
urls.10K.z ........................ 16.355 ms     16.400 ms    ±0.036   x305
rfctest3.z ......................... 0.787 ms      0.796 ms    ±0.004  x1000
randtest3.z ........................ 0.134 ms      0.135 ms    ±0.001  x1000
paper-100k.pdf.z ................... 3.028 ms      3.045 ms    ±0.027  x1000
geo.protodata.z .................... 1.245 ms      1.259 ms    ±0.007  x1000
https://github.com/nim-lang/zip uncompress
alice29.txt.z ...................... 3.526 ms      3.566 ms    ±0.020  x1000
urls.10K.z ........................ 14.976 ms     15.031 ms    ±0.044   x333
rfctest3.z ......................... 0.449 ms      0.455 ms    ±0.005  x1000
randtest3.z ........................ 0.064 ms      0.065 ms    ±0.000  x1000
paper-100k.pdf.z ................... 2.208 ms      2.214 ms    ±0.004  x1000
geo.protodata.z .................... 0.904 ms      0.926 ms    ±0.016  x1000
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
