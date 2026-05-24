## Scriptable runtime ABI — `include` at the bottom of the entry module (e.g. `main.nim`).
##
## Define before include:
##   `onBoot`, `onInit`, `onTick`, `onShutdown` — same as nim-simple (`runtime_host.js` ABI)
##   `onLoad`, `onUnload` — scriptable reload hooks (called by `scriptable_runtime.js`)
##
## Async procs should use `{.rlAsync.}` so they are async on JS and sync on native.

import esmexports
when not declared(rlAsync):
  import rl_async

when not declared(onBoot):
  import rl
  import rl_log
  when not declared(ResultOk):  
    const ResultOk = 0
    const ResultError = -1
    const ResultQuit = 1
  proc onBoot(): int {.rlAsync.} =
    #echo "onBoot not declared"
    #return -1
    # provide a rl centric default boot implementation
    let rc = rlAwait rl_boot(RLBootConfig(
      canvasId: "renderCanvas",
    ))
    if rc != RL_BOOT_OK:
      rl_log.error("Default onBoot failed with error: " & $rc)
      return ResultError
    rl_logger_set_level(RL_LOGGER_LEVEL_WARN.cint)
    return ResultOk

when not declared(onInit):
  proc onInit(): int {.rlAsync.} =
    echo "onInit not declared"
    return ResultError

when not declared(onTick):
  proc onTick(dt: float): int =
    echo "onTick not declared"
    return ResultError

when not declared(onShutdown):
  proc onShutdown() {.rlAsync.} =
    echo "onShutdown not declared"
    return

when defined(js):
  proc rt_boot*(): Future[cint] {.rlAsync, exportjs("_rt_boot").} =
    return (await onBoot()).cint

  proc rt_init*(userData: pointer): Future[cint] {.rlAsync, exportjs("_rt_init").} =
    return (await onInit()).cint

  proc rt_tick*(hostDt: cfloat): cint {.exportjs("_rt_tick").} =
    onTick(hostDt.float).cint

  proc rt_shutdown*() {.rlAsync, exportjs("_rt_shutdown").} =
    await onShutdown()
else:
  proc rt_boot*(): cint {.rlAsync, exportc: "rt_boot", cdecl, dynlib.} =
    onBoot().cint

  proc rt_init*(userData: pointer): cint {.rlAsync, exportc: "rt_init", cdecl, dynlib.} =
    onInit().cint

  proc rt_tick*(hostDt: cfloat): cint {.exportc: "rt_tick", cdecl, dynlib.} =
    onTick(hostDt.float).cint

  proc rt_shutdown*() {.rlAsync, exportc: "rt_shutdown", cdecl, dynlib.} =
    onShutdown()

when isMainModule and not defined(emscripten) and not defined(js):
  import std/times
  let bootResult = rlAwait rt_boot()
  if bootResult != ResultOk :
    quit(ResultError)
  let initResult = rlAwait rt_init(nil)
  if initResult != ResultOk:
    rlAwait rt_shutdown()
    quit(initResult)

  var lastTime = epochTime()
  while true:
    let currentTime = epochTime()
    let deltaTime = currentTime - lastTime
    lastTime = currentTime

    let tickResult = rt_tick(deltaTime.cfloat)
    if tickResult != ResultOk:
      rlAwait rt_shutdown()
      quit(tickResult)

emitEsmDefaultExport()
