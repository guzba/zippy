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

### Compress

Each file is compressed 1000 times.

#### Default compression

**https://github.com/guzba/zippy** results:
File | Time | Size Reduction
--- | --- | ---:
alice29.txt | 3.6429 | 63.32%
urls.10K | 19.2834s | 67.49%
rfctest3.gold | 0.6695s | 70.73%
randtest3.gold | 0.1003s | 0%
paper-100k.pdf | 1.8863s | 19.94%
geo.protodata | 1.2560s | 86.91%

https://github.com/nim-lang/zip results: (Requires zlib1.dll)
File | Time | Size Reduction
--- | --- | ---:
alice29.txt | 6.8607s | 64.23%
urls.10K | 16.3552s | 68.29%
rfctest3.gold | 0.8023s | 71.74%
randtest3.gold | 0.1168s | 0%
paper-100k.pdf | 1.8572s | 20.59%
geo.protodata | 1.0627s | 87.24%

#### Fastest compression

**https://github.com/guzba/zippy** results:
File | Time | Size Reduction
--- | --- | ---:
alice29.txt | 1.5564s | 55.32%
urls.10K | 5.0763s | 61.70%
rfctest3.gold | 0.4265s | 66.31%
randtest3.gold | 0.0382s | 0%
paper-100k.pdf | 1.0761s | 18.44%
geo.protodata | 0.8267s | 80.42%

https://github.com/nim-lang/zip results: (Requires zlib1.dll)
File | Time | Size Reduction
--- | --- | ---:
alice29.txt | 1.6872s | 57.17%
urls.10K | 7.0526s | 63.93%
rfctest3.gold | 0.3170s | 67.53%
randtest3.gold | 0.1127s | 0%
paper-100k.pdf | 1.6518s | 20.22%
geo.protodata | 0.4873s | 84.12%

#### Best compression

**https://github.com/guzba/zippy** results:
File | Time | Size Reduction
--- | --- | ---:
alice29.txt | 4.4691s | 63.75%
urls.10K | 28.0097s | 68.14%
rfctest3.gold | 1.3381s | 70.92%
randtest3.gold | 0.1005s | 0%
paper-100k.pdf | 2.0691s | 20.07%
geo.protodata | 1.4902s | 87.07%

https://github.com/nim-lang/zip results: (Requires zlib1.dll)
File | Time | Size Reduction
--- | --- | ---:
alice29.txt | 9.8849s | 64.38%
urls.10K | 30.3654s | 68.82%
rfctest3.gold | 2.5958s | 71.77%
randtest3.gold | 0.1170s | 0%
paper-100k.pdf | 2.0540s | 20.64%
geo.protodata | 1.4190s | 87.37%

### Uncompress

Each file is uncompressed 1000 times:

**https://github.com/guzba/zippy** results:
File | Time
--- | ---:
alice29.txt | 0.4710s
urls.10K | 2.1916s
rfctest3.gold | 0.1137s
randtest3.gold | 0.093s
paper-100k.pdf | 0.4265s
geo.protodata | 0.1775s

https://github.com/nim-lang/zip results: (Requires zlib1.dll)
File | Time
--- | ---:
alice29.txt | 0.4793s
urls.10K | 1.9790s
rfctest3.gold | 0.1169s
randtest3.gold | 0.0090s
paper-100k.pdf | 0.3123s
geo.protodata | 0.1762s

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
