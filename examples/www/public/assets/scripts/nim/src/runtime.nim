## Scriptable runtime ABI — `include` at the bottom of the entry module (e.g. `main.nim`).
##
## Define before include:
##   `onBoot`, `onInit`, `onTick`, `onShutdown` — same as nim-simple (`runtime_host.js` ABI)
##   `onLoad`, `onUnload` — reloadable content hooks (host calls `_rt_load` / `_rt_unload`)
##   `onLoad(stashed: ref YourContext)` / `onUnload(): ref YourContext`
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

when not declared(onLoad):
  proc onLoad*(stashed: RootRef): int {.rlAsync.} =
    discard stashed
    return ResultOk

when not declared(onUnload):
  proc onUnload*(): RootRef =
    nil

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

  # ref params are one JS arg (the stash object from onUnload). exportjs uses RootRef
  # so the host ABI stays untyped; emit forwards to the app's typed onLoad.
  proc rt_load*(stashed: RootRef) {.rlAsync, exportjs("_rt_load").} =
    {.emit: "return (await `onLoad`(`stashed`)) | 0;".}

  proc rt_unload*(): auto {.exportjs("_rt_unload").} =
    onUnload()

  proc rt_tick*(hostDt: cfloat): cint {.exportjs("_rt_tick").} =
    onTick(hostDt.float).cint

  proc rt_shutdown*() {.rlAsync, exportjs("_rt_shutdown").} =
    await onShutdown()
else:
  proc rt_boot*(): cint {.rlAsync, exportc: "rt_boot", cdecl, dynlib.} =
    onBoot().cint

  proc rt_init*(userData: pointer): cint {.rlAsync, exportc: "rt_init", cdecl, dynlib.} =
    onInit().cint

  proc rt_load*(stashed: pointer): cint {.rlAsync, exportc: "rt_load", cdecl, dynlib.} =
    # use the onUnload() return type so we can cast the onLoad() argument to the same type
    # e.g. onUnload() returns ref AppContext, so onLoad() argument should be ref AppContext
    type StashRef = typeof(onUnload())
    let stash: StashRef =
      if stashed.isNil: nil
      else: cast[StashRef](stashed)
    rlAwait onLoad(stash).cint

  proc rt_unload*(): pointer {.exportc: "rt_unload", cdecl, dynlib.} =
    let stash = onUnload()
    if stash.isNil:
      nil
    else:
      cast[pointer](stash)

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
  discard rlAwait rt_load(nil)

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
