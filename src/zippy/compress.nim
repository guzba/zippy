import zippyerror

# {.push checks: off.}

template failCompress() =
  raise newException(
    ZippyError, "Unexpected error while compressing"
  )

func compress*(src: seq[uint8], dst: var seq[uint8]) =
  ## Uncompresses src into dst. This resizes dst as needed and starts writing
  ## at dst index 0.
  discard

func compress*(src: seq[uint8]): seq[uint8] {.inline.} =
  ## Uncompresses src and returns the compressed data seq.
  compress(src, result)

template compress*(src: string): string =
  ## Helper for when preferring to work with strings.
  cast[string](compress(cast[seq[uint8]](src)))

# {.pop.}
