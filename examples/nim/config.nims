import std/os

  # So, we put a fake guard (when declared(task)) so the linter doesn't complain.

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

task build, "Build desktop Nim test binary":
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

task clean, "Clean Nim build outputs":
  let cacheDir = getCurrentDir() / "cache"
  if dirExists(outDir):
    rmDir(outDir)
  if dirExists(cacheDir):
    rmDir(cacheDir)
