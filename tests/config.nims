--path:"../src"

when defined(emscripten):
  --nimcache:tmp
  --os:linux
  --cpu:wasm32
  --cc:clang
  when defined(windows):
    --clang.exe:emcc.bat
    --clang.linkerexe:emcc.bat
    --clang.cpp.exe:emcc.bat
    --clang.cpp.linkerexe:emcc.bat
  else:
    --clang.exe:emcc
    --clang.linkerexe:emcc
    --clang.cpp.exe:emcc
    --clang.cpp.linkerexe:emcc
  --listCmd
  --gc:arc
  --exceptions:goto
  --define:noSignalHandler
  --debugger:native
  --define:release

  mkdir("emscripten")

  switch("passL", "-o emscripten/zippy.html --preload-file tests/data")
