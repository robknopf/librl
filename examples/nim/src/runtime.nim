## Runtime ABI footer — `include` this at the bottom of your entry module (e.g. `testjs.nim`).
##
## Define before include: `onBoot`, `onInit`, `onTick`, `onShutdown`.
##
## LSP: analyze the entry file (`testjs.nim`), not this file alone.


import esmexports

# give the lsp some stubs, and force them to exist somewhere
# since this file is a footer, those functions would already have been declared/implemented
when not declared(onBoot):
  proc onBoot(): int = 
    echo "onBoot not declared"
    return -1
when not declared(onInit):
  proc onInit(): int = 
    echo "onInit not declared"
    return -1
when not declared(onTick):
  proc onTick(dt: float): int = 
    echo "onTick not declared"
    return -1
when not declared(onShutdown):
  proc onShutdown() = 
    echo "onShutdown not declared"
    discard

when defined(js):
  proc rt_boot*(): cint {. exportc: "rt_boot", exportjs("_rt_boot").} =
    onBoot().cint

  proc rt_init*(): cint {.exportjs("_rt_init").} =
    onInit().cint

  proc rt_tick*(hostDt: cfloat): cint {.exportjs("_rt_tick").} =
    onTick(hostDt.float).cint

  proc rt_shutdown*() {.exportjs("_rt_shutdown").} =
    onShutdown()
else:
  proc rt_boot*(): cint {.exportc: "rt_boot", cdecl, dynlib.} =
    onBoot().cint

  proc rt_init*(): cint {.exportc: "rt_init", cdecl, dynlib.} =
    onInit().cint

  proc rt_tick*(hostDt: cfloat): cint {.exportc: "rt_tick", cdecl, dynlib.} =
    onTick(hostDt.float).cint

  proc rt_shutdown*() {.exportc: "rt_shutdown", cdecl, dynlib.} =
    onShutdown()

when isMainModule and not defined(emscripten) and not defined(js):
  import std/times
  if rt_boot() != 0:
    quit(1)
  if rt_init() != 0:
    rt_shutdown()
    quit(1)

  var lastTime = epochTime()
  while true:
    let currentTime = epochTime()
    let deltaTime = currentTime - lastTime
    lastTime = currentTime

    let rc = rt_tick(deltaTime.cfloat)
    if rc != 0:
      rt_shutdown()
      quit(rc)


emitEsmExports()
