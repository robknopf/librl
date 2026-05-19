import std/os except getCurrentDir, paramCount, paramStr, dirExists

when declared(switch):
  proc hasDefineFlag(name: string): bool =
    for i in 1..paramCount():
      let p = paramStr(i)
      if p == "-d:" & name or p == "--define:" & name or
         p == "-d:" & name & "=1" or p == "--define:" & name & "=1" or
         p == "-d:" & name & "=true" or p == "--define:" & name & "=true":
        return true
    result = false

  type BuildType = enum
    debug, release

  let buildType = if hasDefineFlag("debug"): BuildType.debug else: BuildType.release

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
when defined(js):
  switch("nimcache", nimCacheDir / "js")
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
  switch("passL", "-s EXPORTED_RUNTIME_METHODS='[\"ccall\",\"cwrap\"]'")
  switch("passL", "-s EXPORTED_FUNCTIONS='[\"_main\",\"_rt_boot\",\"_rt_init\",\"_rt_tick\",\"_rt_shutdown\"]'")
  switch("passL", "-s JSPI=1")
  # Same rt_* surface as EXPORTED_FUNCTIONS / nimrltest InjectWasmExports: any of these
  # may transitively call JSPI suspend (rl_init, loader sync import, fetch, etc.).
  switch("passL", "-s JSPI_EXPORTS='[\"rt_boot\",\"rt_init\",\"rt_tick\",\"rt_shutdown\"]'")
  switch("passL", "-fwasm-exceptions")

# Default to release unless debug is explicitly requested via -d:debug
if buildType == BuildType.debug:
  switch("define", "debug")
else:
  switch("define", "release")


proc getBuildModeFlags(): string =
  if buildType == BuildType.release:
    result = "-d:release"
  else:
    result = "-d:debug"
    if defined(js):
      result = result & " --sourcemaps"

proc getOptimizationFlags(): string =
  if buildType == BuildType.release:
    result = "--passL:-O2"
  else:
    result = "--passL:-O0"

proc buildDesktop() =
  let outBin = outDir / "desktop" / outFile
  echo "Building Desktop Nim binary: '" & outBin & "'..."
  mkDir(outDir / "desktop")
  echo "Building dependency: librl (desktop)"
  exec "make -C " & librlRoot & " desktop -j4"
  let entry = getCurrentDir() / mainEntry
  exec "nim c " &  
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
    " " & getBuildModeFlags() &
    " " & getOptimizationFlags() &
    " " & entry



proc buildWasm() =
  let outBin = outDir / "wasm" / (mainEntry.splitFile().name & ".js")
  echo "Building WASM Nim binary: '" & outBin & "'..."
  mkDir(outDir / "wasm")
  echo "Building dependency: librl (wasm)"
  exec "make -C " & librlRoot & " wasm_archive -j4"
  let entry = getCurrentDir() / mainEntry
  exec "nim c -d:emscripten " & 
        " --out:" & outBin &
        " " & getOptimizationFlags() &
        " " & getBuildModeFlags() &
        " " & entry

proc buildJs() =
  let outBin = outDir / "js" / (mainEntry.splitFile().name & ".js")
  echo "Building JS Nim binary: '" & outBin & "'..."
  mkDir(outDir / "js")
  let entry = getCurrentDir() / mainEntry
  exec "nim js" &
    " --out:" & outBin &
    " " & getOptimizationFlags() &
    " " & getBuildModeFlags() &
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
  of "js":
    buildJs()
  of "all":
    buildDesktop()
    buildWasm()
    buildJs()
  else:
    quit "Invalid build target '" & selectedBuildTarget() &
      "'. Expected: desktop, wasm, js, or all.", 1
  
  echo "Build complete."


task clean, "Clean Nim build outputs":
  let cacheDir = getCurrentDir() / "cache"
  if dirExists(outDir):
    rmDir(outDir)
  if dirExists(cacheDir):
    rmDir(cacheDir)
  if dirExists(nimCacheDir):
    rmDir(nimCacheDir)
