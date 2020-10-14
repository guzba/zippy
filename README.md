# Zippy

`nimble install zippy`

Zippy is an in-progress and experimental implementation of [DEFLATE](https://tools.ietf.org/html/rfc1951) and [ZLIB](https://tools.ietf.org/html/rfc1950).

The goal of this library is to be a dependency-free Nim implementation that is as small and straightforward as possible while still focusing on performance.

**This library is an active project and not ready for production use.**

### Testing
`nimble test`

### Credits

This implementation has been greatly assisted by [zlib-inflate-simple](https://github.com/toomuchvoltage/zlib-inflate-simple) which is by far the smallest and most readable implemenation I've found.

# API: zippy

```nim
import zippy
```

## **func** uncompress

Uncompresses src into dst. This resizes dst as needed and starts writing at dst index 0.

```nim
func uncompress(src: seq[uint8]; dst: var seq[uint8]) {.raises: [ZippyException], tags: [].}
```

## **func** uncompress

Uncompresses src and returns the uncompressed data seq.

```nim
func uncompress(src: seq[uint8]): seq[uint8] {.inline, raises: [ZippyException], tags: [].}
```
