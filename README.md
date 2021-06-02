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
alice29.txt ....................... 29.130 ms     29.345 ms    ±0.125   x171
urls.10K ......................... 155.155 ms    156.018 ms    ±0.350    x33
rfctest3.gold ...................... 5.038 ms      5.104 ms    ±0.041   x977
randtest3.gold ..................... 0.750 ms      0.762 ms    ±0.008  x1000
paper-100k.pdf .................... 14.935 ms     15.072 ms    ±0.089   x332
geo.protodata ...................... 9.304 ms      9.375 ms    ±0.035   x533
gzipfiletest.txt ................... 0.124 ms      0.131 ms    ±0.003  x1000

https://github.com/nim-lang/zip compress [default]
alice29.txt ....................... 58.002 ms     58.234 ms    ±0.203    x86
urls.10K ......................... 132.830 ms    133.476 ms    ±0.469    x38
rfctest3.gold ...................... 6.513 ms      6.567 ms    ±0.045   x761
randtest3.gold ..................... 0.889 ms      0.905 ms    ±0.015  x1000
paper-100k.pdf .................... 15.015 ms     15.085 ms    ±0.046   x332
geo.protodata ...................... 8.999 ms      9.053 ms    ±0.030   x552
gzipfiletest.txt ................... 0.119 ms      0.122 ms    ±0.005  x1000

https://github.com/guzba/zippy compress [best speed]
alice29.txt ....................... 12.215 ms     12.282 ms    ±0.028   x407
urls.10K .......................... 39.742 ms     39.925 ms    ±0.165   x126
rfctest3.gold ...................... 2.941 ms      2.977 ms    ±0.019  x1000
randtest3.gold ..................... 0.287 ms      0.296 ms    ±0.009  x1000
paper-100k.pdf ..................... 8.432 ms      8.502 ms    ±0.069   x588
geo.protodata ...................... 5.850 ms      5.888 ms    ±0.015   x849
gzipfiletest.txt ................... 0.059 ms      0.064 ms    ±0.004  x1000

https://github.com/nim-lang/zip compress [best speed]
alice29.txt ....................... 12.760 ms     12.849 ms    ±0.052   x389
urls.10K .......................... 53.205 ms     53.383 ms    ±0.112    x94
rfctest3.gold ...................... 2.174 ms      2.198 ms    ±0.019  x1000
randtest3.gold ..................... 0.813 ms      0.829 ms    ±0.015  x1000
paper-100k.pdf .................... 12.807 ms     12.860 ms    ±0.033   x389
geo.protodata ...................... 3.490 ms      3.524 ms    ±0.026  x1000
gzipfiletest.txt ................... 0.093 ms      0.095 ms    ±0.003  x1000

https://github.com/guzba/zippy compress [best compression]
alice29.txt ....................... 35.601 ms     35.810 ms    ±0.097   x140
urls.10K ......................... 225.956 ms    226.853 ms    ±0.710    x23
rfctest3.gold ..................... 10.082 ms     10.141 ms    ±0.037   x493
randtest3.gold ..................... 0.750 ms      0.759 ms    ±0.006  x1000
paper-100k.pdf .................... 15.335 ms     15.404 ms    ±0.043   x325
geo.protodata ...................... 9.948 ms      9.993 ms    ±0.030   x500
gzipfiletest.txt ................... 0.123 ms      0.131 ms    ±0.004  x1000

https://github.com/nim-lang/zip compress [best compression]
alice29.txt ....................... 85.742 ms     85.883 ms    ±0.194    x59
urls.10K ......................... 251.885 ms    252.070 ms    ±0.095    x20
rfctest3.gold ..................... 21.737 ms     21.788 ms    ±0.035   x230
randtest3.gold ..................... 0.886 ms      0.902 ms    ±0.016  x1000
paper-100k.pdf .................... 16.752 ms     16.848 ms    ±0.080   x297
geo.protodata ..................... 12.247 ms     12.303 ms    ±0.041   x407
gzipfiletest.txt ................... 0.119 ms      0.122 ms    ±0.003  x1000
```

### Uncompress

Each file is uncompressed 10 times per run.

```
https://github.com/guzba/zippy uncompress
alice29.txt.z ...................... 3.590 ms      3.613 ms    ±0.012  x1000
urls.10K.z ........................ 17.099 ms     17.171 ms    ±0.027   x292
rfctest3.z ......................... 0.777 ms      0.817 ms    ±0.018  x1000
randtest3.z ........................ 0.064 ms      0.068 ms    ±0.006  x1000
paper-100k.pdf.z ................... 2.874 ms      2.897 ms    ±0.012  x1000
geo.protodata.z .................... 1.244 ms      1.282 ms    ±0.015  x1000

https://github.com/nim-lang/zip uncompress
alice29.txt.z ...................... 3.533 ms      3.575 ms    ±0.015  x1000
urls.10K.z ........................ 14.996 ms     15.057 ms    ±0.027   x332
rfctest3.z ......................... 0.451 ms      0.458 ms    ±0.008  x1000
randtest3.z ........................ 0.065 ms      0.067 ms    ±0.001  x1000
paper-100k.pdf.z ................... 2.207 ms      2.216 ms    ±0.006  x1000
geo.protodata.z .................... 0.896 ms      0.937 ms    ±0.044  x1000
```

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
