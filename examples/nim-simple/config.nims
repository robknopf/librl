import std/os except getCurrentDir, paramCount, paramStr, dirExists

when declared(switch):
  import std/[strutils, unicode]
  import os except paramCount, paramStr, getCurrentDir

  # helper function to echo colored text
  type Color = enum
    blue, red, green, yellow, white, gray, defaultColor
  proc echo_colored*(msg: string, color: Color) =
    var color_val = "0"
    case color:
    of Color.red:
      color_val = "31"
    of Color.green:
      color_val = "32"
    of Color.yellow:
      color_val = "33"
    of Color.blue:
      color_val = "34"
    of Color.white:
      color_val = "37"
    of Color.gray:
      color_val = "90"
    of Color.defaultColor:
      color_val = "0"

    let esc = chr(27)
    echo $esc & "[" & color_val & "m" & msg & $esc & "[0m"

  proc info(msg:string) =
    echo_colored("> " & msg, Color.gray)

  proc warn(msg:string) =
    echo_colored("> " & msg, Color.yellow)

  proc success(msg:string) =
    echo_colored("> " & msg, Color.green)

  proc error(msg:string) =
    echo_colored("> " & msg, Color.red)

  # helper function to get the current time in seconds, since epoch and systime is not available in nimscript
  proc nowSeconds(): float =
    parseFloat(gorge("date +%s.%N").strip())

  # helper to get all the define flags that were passed in on the command line
  # useful if you need to pass them on to another exec shell
  proc getDefineFlags(): string =
    var defs: seq[string]
    for i in 1..paramCount():
      let p = paramStr(i)
      if p.startsWith("-d:") or p.startsWith("--define:"):
        defs.add(p
          .replace("--define:", "-d:")
        )
    result = defs.join(" ")

  proc hasDefineFlag(name: string): bool =
    for i in 1..paramCount():
      let p = paramStr(i)
      if p == "-d:" & name or p == "--define:" & name or
         p == "-d:" & name & "=1" or p == "--define:" & name & "=1" or
         p == "-d:" & name & "=true" or p == "--define:" & name & "=true":
        return true
    result = false

  proc defineEnabled(name: string; defaultValue: bool): bool =
    if hasDefineFlag("no_" & name):
      return false
    if hasDefineFlag(name):
      return true
    result = defaultValue

  type BuildType = enum
    debug, release

  var  
    buildType: BuildType = BuildType.release # default to release

    
  proc setBuildType() =
    if hasDefineFlag("debug"):
      buildType = BuildType.debug
    else:
      buildType = BuildType.release  

const
  thisDir = currentSourcePath().parentDir()
  librlRoot = absolutePath("../..", thisDir)
  includeDir = librlRoot / "include"
  bindingsDir = librlRoot / "bindings" / "nim"
  libDir = librlRoot / "lib"
  outDir = thisDir / "out"
  outFile = "main"
  srcDir = thisDir / "src"
  mainEntry = srcDir / "main.nim"
  nimCacheBaseDir = ".nimcache"
  ## Reloadable web bundle (script_watcher watches this tree only).
  scriptOutDir = absolutePath("../www/public/assets/scripts/nim", thisDir)

switch("path", srcDir)
switch("path", bindingsDir)
switch("hints", "off")

when defined(emscripten):
  switch("nimcache", nimCacheBaseDir / "wasm")
when defined(js):
  switch("nimcache", nimCacheBaseDir / "js")
else:
  switch("nimcache", nimCacheBaseDir / "desktop")


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
#if buildType == BuildType.debug:
#  switch("define", "debug")
#else:
#  switch("define", "release")


proc getBuildModeFlags(): string =
  if buildType == BuildType.debug or hasDefineFlag("debug"):
    result = "-d:debug"
    #if defined(js):
    result = result & " --sourceMap"
    result = result & " --stackTrace:on"
    result = result & " --lineTrace:on"
    result = result & " --debugger:native"
  else:
    result = "-d:release"

  echo "BuildModeFlags: " & result

proc getOptimizationFlags(): string =
  if buildType == BuildType.release:
    result = "--passL:-O2"
  else:
    result = "--passL:-O0"


proc patchJSSourceMap(jsFilePath: string) =
  if buildType == BuildType.release:
    return

  info "Patching source map for: " & jsFilePath
  let jsContent = readFile(jsFilePath)
  if not jsContent.contains("//# sourceMappingURL="):
    info "No sourceMappingURL in JS file: " & jsFilePath
    return

  let jsName = jsFilePath.splitFile().name
  let relativeMapPath = jsName & ".js.map"
  let fixedJsContent = jsContent.replace(
    "//# sourceMappingURL=" & jsFilePath & ".map",
    "//# sourceMappingURL=" & relativeMapPath)
  if fixedJsContent != jsContent:
    writeFile(jsFilePath, fixedJsContent)

  let mapPath = jsFilePath.splitFile().dir / relativeMapPath
  try:
    let mapContent = readFile(mapPath)
    ## Nim emits absolute paths under the repo root. Rewrite them to URL paths so
    ## browser debuggers resolve sources through the testbed HTTP mounts (same
    ## relative layout as projectRoot: /examples/..., /bindings/..., etc.).
    ## Paths outside projectRoot (e.g. ~/.choosenim/...) are left unchanged.
    let projectRoot = librlRoot
    let patchedMapContent = mapContent.replace(projectRoot & "/", "/")
    if patchedMapContent != mapContent:
      writeFile(mapPath, patchedMapContent)
  except:
    warn "Could not patch source map: " & mapPath

proc buildDesktop() =
  let outBin = outDir / "desktop" / outFile
  echo "Building Desktop Nim binary: '" & outBin & "'..."
  mkDir(outDir / "desktop")
  echo "Building dependency: librl (desktop)"
  exec "make -C " & librlRoot & " desktop -j4"
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
    " --hotCodeReloading:on" & 
    #" -d:nimDebugDlOpen" &
    " --mm:refc" & 
    " --threads:off" &
    " " & mainEntry



proc buildWasm() =
  let outBin = outDir / "wasm" / (mainEntry.splitFile().name & ".js")
  echo "Building WASM Nim binary: '" & outBin & "'..."
  mkDir(outDir / "wasm")
  echo "Building dependency: librl (wasm)"
  exec "make -C " & librlRoot & " wasm_archive -j4"
  exec "nim c -d:emscripten " & 
        " --out:" & outBin &
        " " & getOptimizationFlags() &
        " " & getBuildModeFlags() &
        " " & mainEntry

proc buildJs() =
  let outBin = outDir / "js" / (mainEntry.splitFile().name & ".js")
  echo "Building JS Nim binary: '" & outBin & "'..."
  mkDir(outDir / "js")
  exec "nim js" &
    " --out:" & outBin &
    " " & getOptimizationFlags() &
    " " & getBuildModeFlags() &
    " " & mainEntry

proc buildScript() =
  let outBin = scriptOutDir / (outFile & ".js")
  echo "Building reloadable JS bundle: '" & outBin & "'..."
  mkDir(scriptOutDir)
  let entry = mainEntry
  exec "nim js" &
    " --out:" & outBin &
    " " & getOptimizationFlags() &
    " " & getBuildModeFlags() &
    " " & entry
  patchJSSourceMap(outBin)

proc selectedBuildTarget(): string =
  if paramCount() >= 2:
    # build target should be the last argument
    result = paramStr(paramCount())
  else:
    result = "help"
    

proc showHelp() =
  echo "Usage: nim build [flags] target"
  echo "Targets: desktop, wasm, js, script, help, or all"

task build, "Build Nim targets: desktop, wasm, js, script, help, or all":
  setBuildType()
  echo "Provided arguments: " & commandLineParams().join(", ")
  echo "Build target: " & selectedBuildTarget()
  case selectedBuildTarget()
  of "help":
    showHelp()
    quit "", 0
  of "desktop":
    buildDesktop()
  of "wasm":
    buildWasm()
  of "js":
    buildJs()
  of "script":
    buildScript()
  of "all":
    buildDesktop()
    buildWasm()
    buildJs()
    buildScript()
  else:
    showHelp()
    quit "Invalid build target '" & selectedBuildTarget() &
      "'. Expected: desktop, wasm, js, script, help, or all.", 1
  
  echo "Build complete."


task clean, "Clean Nim build outputs":
  if dirExists(outDir):
    rmDir(outDir)
  let localFSRootDir = thisDir / "cache"
  if dirExists(localFSRootDir):
    rmDir(localFSRootDir)
  if dirExists(nimCacheBaseDir):
    rmDir(nimCacheBaseDir)
