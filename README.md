# Zippy

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

#### Default compression

**https://github.com/guzba/zippy** results:
file | min | avg | std dv | runs | % red
--- | --- | --- | --- | --- | ---:
alice29.txt | 29.684 ms | 29.942 ms | ±0.188 | x167 | 63.32%
urls.10K | 161.095 ms | 161.969 ms | ±0.449 | x31 | 67.49%
rfctest3.gold | 5.056 ms | 5.132 ms | ±0.079 | x973 | 70.73%
randtest3.gold | 0.776 ms | 0.789 ms | ±0.015 | x1000 | 0%
paper-100k.pdf | 14.967 ms | 15.123 ms | ±0.109 | x331 | 19.94%
geo.protodata | 9.493 ms | 9.581 ms | ±0.068 | x522 | 86.91%


https://github.com/nim-lang/zip results: (Requires zlib1.dll)
file | min | avg | std dv | runs | % red
--- | --- | --- | --- | --- | ---:
alice29.txt | 58.013 ms | 58.213 ms | ±0.177 | x86 | 64.23%
urls.10K | 132.910 ms | 133.379 ms | ±0.380 | x38 | 68.29%
rfctest3.gold | 6.525 ms | 6.589 ms | ±0.060 | x757 | 71.74%
randtest3.gold | 0.887 ms | 0.903 ms | ±0.015 | x1000 | 0%
paper-100k.pdf | 15.020 ms | 15.113 ms | ±0.058 | x331 | 20.59%
geo.protodata | 8.996 ms | 9.094 ms | ±0.065 | x549 | 87.24%

#### Fastest compression

**https://github.com/guzba/zippy** results:
file | min | avg | std dv | runs | % red
--- | --- | --- | --- | --- | ---:
alice29.txt | 12.190 ms | 12.320 ms | ±0.153 | x405 | 55.32%
urls.10K | 39.377 ms | 39.591 ms | ±0.131 | x127 | 61.70%
rfctest3.gold | 2.956 ms | 2.986 ms | ±0.022 | x1000 | 66.31%
randtest3.gold | 0.268 ms | 0.277 ms | ±0.009 | x1000 | 0%
paper-100k.pdf | 8.262 ms | 8.332 ms | ±0.049 | x600 | 18.44%
geo.protodata | 5.891 ms | 5.924 ms | ±0.016 | x844 | 80.42%

https://github.com/nim-lang/zip results: (Requires zlib1.dll)
file | min | avg | std dv | runs | % red
--- | --- | --- | --- | --- | ---:
alice29.txt | 12.797 ms | 13.024 ms | ±0.198 | x384 | 57.17%
urls.10K | 53.304 ms | 53.515 ms | ±0.122 | x94 | 63.93%
rfctest3.gold | 2.179 ms | 2.220 ms | ±0.029 | x1000 | 67.53%
randtest3.gold | 0.813 ms | 0.831 ms | ±0.016 | x1000 | 0%
paper-100k.pdf | 12.806 ms | 12.878 ms | ±0.056 | x388 | 20.22%
geo.protodata | 3.494 ms | 3.531 ms | ±0.024 | x1000 | 84.12%

#### Best compression

**https://github.com/guzba/zippy** results:
file | min | avg | std dv | runs | % red
--- | --- | --- | --- | --- | ---:
alice29.txt | 36.647 ms | 36.911 ms | ±0.149 | x136 | 63.75%
urls.10K | 235.869 ms | 237.799 ms | ±0.431 | x22 | 68.14%
rfctest3.gold | 10.528 ms | 10.766 ms | ±0.121 | x465 | 70.92%
randtest3.gold | 0.778 ms | 0.789 ms | ±0.008 | x1000 | 0%
paper-100k.pdf | 15.948 ms | 16.085 ms | ±0.078 | x311 | 20.07%
geo.protodata | 10.824 ms | 10.890 ms | ±0.046 | x459 | 87.07%

https://github.com/nim-lang/zip results: (Requires zlib1.dll)
file | min | avg | std dv | runs | % red
--- | --- | --- | --- | --- | ---:
alice29.txt | 86.051 ms | 86.287 ms | ±0.216 | x58 | 64.38%
urls.10K | 253.127 ms | 253.952 ms | ±0.724 | x20 | 68.82%
rfctest3.gold | 21.753 ms | 22.018 ms | ±0.168 | x227 | 71.77%
randtest3.gold | 0.887 ms | 0.902 ms | ±0.014 | x1000 | 0%
paper-100k.pdf | 16.749 ms | 16.838 ms | ±0.056 | x297 | 20.64%
geo.protodata | 12.252 ms | 12.346 ms | ±0.066 | x405 | 87.37%

### Uncompress

Each file is uncompressed 10 times per run.

**https://github.com/guzba/zippy** results:
file | min | avg | std dv | runs
--- | --- | --- | --- | ---:
alice29.txt.z | 3.570 ms | 3.595 ms | ±0.018 | x1000
urls.10K.z | 17.324 ms | 17.392 ms | ±0.057 | x288
rfctest3.z | 0.777 ms | 0.794 ms | ±0.011 | x1000
randtest3.z | 0.067 ms | 0.070 ms | ±0.006 | x1000
paper-100k.pdf.z | 2.908 ms | 2.937 ms | ±0.034 | x1000
geo.protodata.z | 1.268 ms | 1.299 ms | ±0.016 | x1000

https://github.com/nim-lang/zip results: (Requires zlib1.dll)
file | min | avg | std dv | runs
--- | --- | --- | --- | ---:
alice29.txt.z | 3.530 ms | 3.572 ms | ±0.016 | x1000
urls.10K.z | 15.029 ms | 15.093 ms | ±0.053 | x331
rfctest3.z | 0.452 ms | 0.481 ms | ±0.037 | x1000
randtest3.z | 0.065 ms | 0.072 ms | ±0.011 | x1000
paper-100k.pdf.z | 2.208 ms | 2.221 ms | ±0.009 | x1000
geo.protodata.z | 0.897 ms | 0.918 ms | ±0.016 | x1000

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

## **proc** open

Opens the tarball file located at path and reads its contents into tarball.contents (clears any existing tarball.contents entries). Supports .tar, .tar.gz, .taz and .tgz file extensions.

```nim
proc open(tarball: Tarball; path: string) {.raises: [IOError, ZippyError, ZippyError], tags: [ReadIOEffect].}
```

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

## **proc** open

Opens the zip archive file located at path and reads its contents into archive.contents (clears any existing archive.contents entries).

```nim
proc open(archive: ZipArchive; path: string) {.raises: [IOError, ZippyError, ZippyError], tags: [ReadIOEffect].}
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
