import std/os

when declared(switch):
  switch("path", "src")
  switch("path", "../../bindings/nim")
  switch("hints", "off")

const
  thisDir = currentSourcePath().parentDir()
  librlRoot = absolutePath("../..", thisDir)
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



proc buildDesktop() =
  let outBin = outDir / "desktop" / outFile
  echo "Building Desktop Nim binary: '" & outBin & "'..."
  mkDir(outDir / "desktop")
  echo "Building dependency: librl (desktop)"
  exec "make -C " & librlRoot & " desktop -j4"
  let entry = getCurrentDir() / mainEntry
  exec "nim c -d:release" &
    " --out:" & outBin &
    " --passC:-I" & includeDir &
    " --passL:" & (libDir / "librl.a") & # to ensure we don't link to the shared lib (default linker behavior if both libs exist)
    " --passL:-lm" &
    " --passL:-lpthread" &
    " --passL:-ldl" &
    " --passL:-lX11" &
    " --passL:-lcrypto" &
    " --passL:-lz" &
    " --passL:-lssl" &
    " --passL:-lnghttp2" &
    " " & entry

proc buildWasm() =
  let outBin = outDir / "wasm" / "main.js"
  echo "Building WASM Nim binary: '" & outBin & "'..."
  mkDir(outDir / "wasm")
  echo "Building dependency: librl (wasm)"
  exec "make -C " & librlRoot & " wasm_archive -j4"
  let entry = getCurrentDir() / mainEntry
  exec "nim c -d:emscripten -d:release " & 
        " --out:" & outBin &
        " " & entry

proc selectedBuildTarget(): string =
  if paramCount() >= 2:
    result = paramStr(2)
  else:
    result = "all"

task build, "Build Nim targets: desktop, wasm, or all (default)":
  case selectedBuildTarget()
  of "desktop":
    buildDesktop()
  of "wasm":
    buildWasm()
  of "all":
    buildDesktop()
    buildWasm()
  else:
    quit "Invalid build target '" & selectedBuildTarget() &
      "'. Expected: desktop, wasm, or all.", 1
  
  echo "Build complete."


task clean, "Clean Nim build outputs":
  let cacheDir = getCurrentDir() / "cache"
  if dirExists(outDir):
    rmDir(outDir)
  if dirExists(cacheDir):
    rmDir(cacheDir)
  if dirExists(nimCacheDir):
    rmDir(nimCacheDir)
