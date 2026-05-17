## Runtime ABI footer — `include` this at the bottom of your entry module (e.g. `testjs.nim`).
##
## Define before include: `onBoot`, `onInit`, `onTick`, `onShutdown`.
## `onBoot` and `onInit` should carry `{.rlAsync.}` so they are transparently
## async on the JS target and sync on native.
##
## LSP: analyze the entry file (`testjs.nim`), not this file alone.

import esmexports
when not declared(rlAsync):
  import rl_async

when not declared(onBoot):
  proc onBoot(): int {.rlAsync.} =
    echo "onBoot not declared"
    return -1
when not declared(onInit):
  proc onInit(): int {.rlAsync.} =
    echo "onInit not declared"
    return -1
when not declared(onTick):
  proc onTick(dt: float): int =
    echo "onTick not declared"
    return -1
when not declared(onShutdown):
  proc onShutdown() {.rlAsync.} =
    echo "onShutdown not declared"

when defined(js):
  proc rt_boot*(): Future[cint] {.async, exportc: "rt_boot", exportjs("_rt_boot").} =
    return (await onBoot()).cint

  proc rt_init*(userData: pointer): Future[cint] {.async, exportjs("_rt_init").} =
    return (await onInit()).cint

  proc rt_tick*(hostDt: cfloat): cint {.exportjs("_rt_tick").} =
    onTick(hostDt.float).cint

  proc rt_shutdown*() {.async, exportjs("_rt_shutdown").} =
    await onShutdown()
else:
  proc rt_boot*(): cint {.exportc: "rt_boot", cdecl, dynlib.} =
    onBoot().cint

  proc rt_init*(userData: pointer): cint {.exportc: "rt_init", cdecl, dynlib.} =
    onInit().cint

  proc rt_tick*(hostDt: cfloat): cint {.exportc: "rt_tick", cdecl, dynlib.} =
    onTick(hostDt.float).cint

  proc rt_shutdown*() {.exportc: "rt_shutdown", cdecl, dynlib.} =
    onShutdown()

when isMainModule and not defined(emscripten) and not defined(js):
  import std/times
  if rt_boot() != 0:
    quit(1)
  if rt_init(nil) != 0:
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

emitEsmDefaultExport()
