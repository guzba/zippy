import zippy/ziparchives

proc test_case() =
  var archive = open_zip_archive("inner_test.zip")
  defer: archive.close()
    
  for fname in archive.walk_files:
    let bytes = archive.extract_file(fname)
    var inner_archive = open_zip_archive_bytes(bytes)
    defer: inner_archive.close()
    
    for ifname in inner_archive.walk_files:
      let ifbytes = inner_archive.extract_file(ifname)
      writeFile(ifname, ifbytes)

test_case()