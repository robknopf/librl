import std/os

when declared(switch):
  switch("path", "src")
  switch("path", "../../bindings/nim")
  switch("hints", "off")

const
  librlRoot = absolutePath("../..", getCurrentDir())
  includeDir = librlRoot / "include"
  libDir = librlRoot / "lib"
  outDir = getCurrentDir() / "out"
  mainEntry = "src/main.nim"
  outFile = "main"
  nimCacheDir = ".nimcache"

when defined(emscripten):
  switch("nimcache", nimCacheDir / "wasm")
else:
  switch("nimcache", nimCacheDir / "desktop")


when defined(emscripten):
  switch("os", "linux")
  switch("cpu", "wasm32")
  switch("cc", "clang")
  switch("mm", "arc")

  when defined(windows):
    switch("clang.exe", "emcc.bat")
    switch("clang.linkerexe", "emcc.bat")
  else:
    switch("clang.exe", "emcc")
    switch("clang.linkerexe", "emcc")

  switch("exceptions", "goto")
  switch("define", "noSignalHandler")
  switch("threads", "off")
  switch("define", "useMalloc")

  switch("passC", "-I" & includeDir)
  switch("passC", "-DPLATFORM_WEB")
  switch("passC", "-Wno-incompatible-function-pointer-types")

  switch("passL", libDir / "librl.wasm.a")
  switch("passL", "-s USE_GLFW=3")
  switch("passL", "-s FETCH=1")
  switch("passL", "-s MIN_WEBGL_VERSION=2")
  switch("passL", "-s MAX_WEBGL_VERSION=2")
  switch("passL", "-s ALLOW_MEMORY_GROWTH=1")
  switch("passL", "-s INITIAL_MEMORY=67108864")
  switch("passL", "-lidbfs.js")
  switch("passL", "-s WASM=1")
  switch("passL", "-s MODULARIZE=1")
  switch("passL", "-s EXPORT_ES6=1")

  switch("passL", "-O2")
  switch("define", "release")

  switch("out", outDir / "wasm" / "main.js")

task build, "Build desktop Nim binary":
  mkDir(outDir)
  let entry = getCurrentDir() / mainEntry
  let outBin = outDir / outFile
  exec "nim c" &
    " --out:" & outBin &
    " --passC:-I" & includeDir &
    " --passL:-L" & libDir &
    " --passL:-lrl" &
    " --passL:-lcurl" &
    " --passL:-lm" &
    " --passL:-lpthread" &
    " --passL:-ldl" &
    " --passL:-lX11" &
    " " & entry

task build_wasm, "Build WASM Nim binary via Emscripten":
  mkDir(outDir / "wasm")
  let entry = getCurrentDir() / mainEntry
  exec "nim c -d:emscripten -d:release " & entry

task clean, "Clean Nim build outputs":
  let cacheDir = getCurrentDir() / "cache"
  if dirExists(outDir):
    rmDir(outDir)
  if dirExists(cacheDir):
    rmDir(cacheDir)
  if dirExists(nimCacheDir):
    rmDir(nimCacheDir)
