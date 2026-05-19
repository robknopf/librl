## Native (desktop / emscripten-wasm) binding.
## Included by rl.nim when not defined(js).  Do not import directly.

include ../gen/rl_version

type
  RLHandle* = uint32
  RLWindowFlags* = cuint
  Vec2* {.importc: "vec2_t", header: "rl.h", bycopy.} = object
    x*: cfloat
    y*: cfloat
  Vec3* {.importc: "vec3_t", header: "rl.h", bycopy.} = object
    x*: cfloat
    y*: cfloat
    z*: cfloat
  RLPickResult* {.importc: "rl_pick_result_t", header: "rl_pick.h", bycopy.} = object
    hit*: bool
    distance*: cfloat
    point*: Vec3
    normal*: Vec3
  RLMouseState* {.importc: "rl_mouse_state_t", header: "rl.h", bycopy.} = object
    x*: cint
    y*: cint
    wheel*: cint
    left*: cint
    right*: cint
    middle*: cint
  RLKeyboardState* {.importc: "rl_keyboard_state_t", header: "rl.h", bycopy.} = object
    max_num_keys*: cint
    keys*: array[512, cint]
    pressed_key*: cint
    pressed_char*: cint
    num_pressed_keys*: cint
    pressed_keys*: array[32, cint]
    num_pressed_chars*: cint
    pressed_chars*: array[32, cint]
  RLEventListenerFn* = proc(payload: pointer, userData: pointer) {.cdecl.}
  RLFileioCallbackFn* = proc(path: cstring, userData: pointer) {.cdecl.}
  RLFileioClosureCallback* = proc(path: string) {.closure.}
  RLInitConfigC {.importc: "rl_init_config_t", header: "rl_config.h", bycopy.} = object
    window_width: cint
    window_height: cint
    window_title: cstring
    window_flags: RLWindowFlags
    asset_host: cstring
    fileio_base_dir: cstring
  RLFileioClosureTask = ref object
    onSuccess: RLFileioClosureCallback
    onFailure: RLFileioClosureCallback

var rlFileioClosureTasks: seq[RLFileioClosureTask] = @[]

var
  RL_COLOR_DEFAULT* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_LIGHTGRAY* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_GRAY* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_DARKGRAY* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_YELLOW* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_GOLD* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_ORANGE* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_PINK* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_RED* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_MAROON* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_GREEN* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_LIME* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_DARKGREEN* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_SKYBLUE* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_BLUE* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_DARKBLUE* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_PURPLE* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_VIOLET* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_DARKPURPLE* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_BEIGE* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_BROWN* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_DARKBROWN* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_WHITE* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_BLACK* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_BLANK* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_MAGENTA* {.importc, header: "rl_color.h".}: RLHandle
  RL_COLOR_RAYWHITE* {.importc, header: "rl_color.h".}: RLHandle

const
  RL_INIT_OK* = 0
  RL_INIT_ERR_UNKNOWN* = -1
  RL_INIT_ERR_ALREADY_INITIALIZED* = -2
  RL_INIT_ERR_LOADER* = -3
  RL_INIT_ERR_ASSET_HOST* = -4
  RL_INIT_ERR_WINDOW* = -5
  RL_TICK_RUNNING* = 0
  RL_TICK_WAITING* = 1
  RL_TICK_FAILED* = -1
  RL_CAMERA_PERSPECTIVE* = 0
  RL_CAMERA_ORTHOGRAPHIC* = 1
  RL_FLAG_WINDOW_RESIZABLE* = 4.RLWindowFlags
  RL_FLAG_MSAA_4X_HINT* = 32.RLWindowFlags
  RL_BUTTON_UP* = 0
  RL_BUTTON_PRESSED* = 1
  RL_BUTTON_DOWN* = 2
  RL_BUTTON_RELEASED* = 3
  RL_LOGGER_LEVEL_TRACE* = 0
  RL_LOGGER_LEVEL_DEBUG* = 1
  RL_LOGGER_LEVEL_INFO* = 2
  RL_LOGGER_LEVEL_WARN* = 3
  RL_LOGGER_LEVEL_ERROR* = 4
  RL_LOGGER_LEVEL_FATAL* = 5
  RL_FILEIO_ADD_TASK_OK* = 0
  RL_FILEIO_ADD_TASK_ERR_INVALID* = -1
  RL_FILEIO_ADD_TASK_ERR_QUEUE_FULL* = -2
proc rl_init_raw(config: ptr RLInitConfigC): cint {.importc: "rl_init", cdecl, header: "rl.h".}
proc rl_init_async_raw(config: ptr RLInitConfigC): cint {.importc: "rl_init_async", cdecl, header: "rl.h".}
proc rl_init_values_raw(windowWidth: cint, windowHeight: cint, windowTitle: cstring,
                        windowFlags: RLWindowFlags, assetHost: cstring,
                        fileioBaseDir: cstring): cint {.importc: "rl_init_values", cdecl, header: "rl.h".}
proc rl_init_values_async_raw(windowWidth: cint, windowHeight: cint, windowTitle: cstring,
                              windowFlags: RLWindowFlags, assetHost: cstring,
                              fileioBaseDir: cstring): cint {.importc: "rl_init_values_async", cdecl, header: "rl.h".}
proc rl_deinit*() {.importc, cdecl, header: "rl.h".}
proc rl_set_asset_host*(assetHost: cstring): cint {.importc, cdecl, header: "rl.h".}
proc rl_get_asset_host*(): cstring {.importc, cdecl, header: "rl.h".}
proc rl_fileio_init*(baseDir: cstring): cint {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_init_async*(baseDir: cstring): cint {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_deinit*() {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_is_initialized*(): bool {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_set_asset_host*(assetHost: cstring): cint {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_get_asset_host*(): cstring {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_get_base_dir*(): cstring {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_ping_asset_host*(assetHost: cstring): cfloat {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_is_ready*(): bool {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_flush*(): cint {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_deinit_async*(): RLHandle {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_write*(path: cstring, data: ptr byte, size: csize_t): cint {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_mkdir*(path: cstring): cint {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_rmdir*(path: cstring): cint {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_restore_async*(): RLHandle {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_ensure_async*(localPath: cstring, src: cstring): RLHandle {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_ensure*(localPath: cstring, src: cstring): cint {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_ensure_group_async_raw(filenames: ptr cstring, filenameCount: csize_t): RLHandle {.importc: "rl_fileio_ensure_group_async", cdecl, header: "rl_fileio.h".}

proc rl_fileio_ensure_group_async*(filenames: openArray[string]): RLHandle =
  if filenames.len == 0:
    return 0.RLHandle
  var cstrs = newSeq[cstring](filenames.len)
  for i, s in filenames:
    cstrs[i] = s.cstring
  return rl_fileio_ensure_group_async_raw(addr cstrs[0], cstrs.len.csize_t)

proc rl_fileio_poll_task*(task: RLHandle): bool {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_finish_c(task: RLHandle): cint {.importc: "rl_fileio_finish_task", cdecl, header: "rl_fileio.h".}
proc rl_fileio_get_task_path*(task: RLHandle): cstring {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_free_task*(task: RLHandle) {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_add_task_raw*(task: RLHandle,
                         onSuccess: RLFileioCallbackFn, onFailure: RLFileioCallbackFn,
                         userData: pointer): cint {.importc: "rl_fileio_add_task", cdecl, header: "rl_fileio.h".}
proc rl_fileio_tick*() {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_exists*(filename: cstring): bool {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_remove*(filename: cstring): cint {.importc, cdecl, header: "rl_fileio.h".}
proc rl_fileio_clear*(): cint {.importc, cdecl, header: "rl_fileio.h".}

proc rl_fileio_add_task*(task: RLHandle,
                         onSuccess: RLFileioCallbackFn, onFailure: RLFileioCallbackFn,
                         userData: pointer): int =
  rl_fileio_add_task_raw(task, onSuccess, onFailure, userData).int

proc rl_fileio_release_closure_task(task: RLFileioClosureTask) =
  if task.isNil:
    return
  for idx in 0 ..< rlFileioClosureTasks.len:
    if rlFileioClosureTasks[idx] == task:
      rlFileioClosureTasks.delete(idx)
      break

proc rl_fileio_add_task_success_trampoline(path: cstring, userData: pointer) {.cdecl.} =
  let task = cast[RLFileioClosureTask](userData)
  rl_fileio_release_closure_task(task)
  if not task.isNil and task.onSuccess != nil:
    task.onSuccess($path)

proc rl_fileio_add_task_failure_trampoline(path: cstring, userData: pointer) {.cdecl.} =
  let task = cast[RLFileioClosureTask](userData)
  rl_fileio_release_closure_task(task)
  if not task.isNil and task.onFailure != nil:
    task.onFailure($path)

proc rl_fileio_add_task*(task: RLHandle,
                         onSuccess: RLFileioClosureCallback = nil,
                         onFailure: RLFileioClosureCallback = nil): int =
  if onSuccess.isNil and onFailure.isNil:
    return rl_fileio_add_task_raw(task, nil, nil, nil).int
  let closureTask = RLFileioClosureTask(
    onSuccess: onSuccess,
    onFailure: onFailure
  )
  rlFileioClosureTasks.add(closureTask)
  result = rl_fileio_add_task_raw(
    task,
    rl_fileio_add_task_success_trampoline,
    rl_fileio_add_task_failure_trampoline,
    cast[pointer](closureTask)
  ).int
  if result != RL_FILEIO_ADD_TASK_OK and onFailure.isNil:
    rl_fileio_release_closure_task(closureTask)

proc rl_init_async*(): int {.inline.} =
  rl_init_async_raw(nil).int

proc rl_init_values*(windowWidth, windowHeight: int, windowTitle: string,
                     windowFlags: RLWindowFlags = 0.RLWindowFlags,
                     assetHost: string = "", fileioBaseDir: string = ""): int {.inline.} =
  rl_init_values_raw(windowWidth.cint, windowHeight.cint, windowTitle.cstring, windowFlags,
                     assetHost.cstring, fileioBaseDir.cstring).int

proc rl_init_values_async*(windowWidth, windowHeight: int, windowTitle: string,
                           windowFlags: RLWindowFlags = 0.RLWindowFlags,
                           assetHost: string = "", fileioBaseDir: string = ""): int {.inline.} =
  rl_init_values_async_raw(windowWidth.cint, windowHeight.cint, windowTitle.cstring, windowFlags,
                           assetHost.cstring, fileioBaseDir.cstring).int

proc rl_set_asset_host*(assetHost: string): int {.inline.} =
  rl_set_asset_host(assetHost.cstring).int

proc rl_fileio_init*(baseDir: string): int {.inline.} =
  rl_fileio_init(baseDir.cstring).int

proc rl_fileio_init*(): int {.inline.} =
  rl_fileio_init(nil).int

proc rl_fileio_init_async*(baseDir: string): int {.inline.} =
  rl_fileio_init_async(baseDir.cstring).int

proc rl_fileio_init_async*(): int {.inline.} =
  rl_fileio_init_async(nil).int

proc rl_fileio_set_asset_host*(assetHost: string): int {.inline.} =
  rl_fileio_set_asset_host(assetHost.cstring).int

proc rl_fileio_ping_asset_host*(assetHost: string): float {.inline.} =
  rl_fileio_ping_asset_host(assetHost.cstring).float

proc rl_fileio_ensure_async*(localPath: string, src: string = ""): RLHandle {.inline.} =
  let srcPtr = if src.len == 0: nil else: src.cstring
  rl_fileio_ensure_async(localPath.cstring, srcPtr)

proc rl_fileio_exists*(filename: string): bool {.inline.} =
  rl_fileio_exists(filename.cstring)

proc rl_fileio_remove*(filename: string): int {.inline.} =
  rl_fileio_remove(filename.cstring).int

proc rl_fileio_ensure*(localPath: string, src: string = ""): int {.inline.} =
  let srcPtr = if src.len == 0: nil else: src.cstring
  rl_fileio_ensure(localPath.cstring, srcPtr).int

proc fileioPingAssetHost*(assetHost = ""): float =
  let host = if assetHost.len == 0: nil else: assetHost.cstring
  rl_fileio_ping_asset_host(host).float

type
  RLTaskGroupTaskCallback*[T] = proc(path: string, ctx: var T) {.closure.}
  RLTaskGroupCallback*[T] = proc(group: RLTaskGroup[T], ctx: var T) {.closure.}
  RLTaskGroupEntry[T] = object
    task: RLHandle
    path: string
    done: bool
    rc: int
    onSuccess: RLTaskGroupTaskCallback[T]
    onError: RLTaskGroupTaskCallback[T]
  RLTaskGroup*[T] = ref object
    entries: seq[RLTaskGroupEntry[T]]
    callbackContext: ptr T
    onCompleteCallback: RLTaskGroupCallback[T]
    onErrorCallback: RLTaskGroupCallback[T]
    terminalCallbackInvoked: bool
    failedCount*: int
    completedCount*: int

proc fileioCreateTaskGroup*[T](
  ctx: ptr T,
  onComplete: RLTaskGroupCallback[T] = nil,
  onError: RLTaskGroupCallback[T] = nil
): RLTaskGroup[T] =
  new(result)
  result.entries = @[]
  result.callbackContext = ctx
  result.onCompleteCallback = onComplete
  result.onErrorCallback = onError
  result.terminalCallbackInvoked = false
  result.failedCount = 0
  result.completedCount = 0

proc addTask*[T](
  group: RLTaskGroup[T],
  task: RLHandle,
  onSuccess: RLTaskGroupTaskCallback[T] = nil,
  onError: RLTaskGroupTaskCallback[T] = nil
) =
  if group.isNil or task == 0:
    return
  group.entries.add(RLTaskGroupEntry[T](
    task: task,
    path: $rl_fileio_get_task_path(task),
    done: false,
    rc: 1,
    onSuccess: onSuccess,
    onError: onError
  ))

proc addImportTask*[T](
  group: RLTaskGroup[T],
  path: string,
  onSuccess: RLTaskGroupTaskCallback[T] = nil,
  onError: RLTaskGroupTaskCallback[T] = nil
) =
  if group.isNil:
    return
  group.addTask(rl_fileio_ensure_async(path, ""), onSuccess, onError)

proc addImportTasks*[T](group: RLTaskGroup[T], paths: openArray[string]) =
  for path in paths:
    group.addImportTask(path)

proc remainingTasks*[T](group: RLTaskGroup[T]): int =
  if group.isNil:
    return 0
  return group.entries.len - group.completedCount

proc isDone*[T](group: RLTaskGroup[T]): bool =
  return group.remainingTasks() == 0

proc hasFailures*[T](group: RLTaskGroup[T]): bool =
  if group.isNil:
    return false
  return group.failedCount > 0

proc tick*[T](group: RLTaskGroup[T]): bool =
  if group.isNil:
    return false
  rl_fileio_tick()
  for idx in 0 ..< group.entries.len:
    if group.entries[idx].done:
      continue
    if not rl_fileio_poll_task(group.entries[idx].task):
      continue
    group.entries[idx].rc = rl_fileio_finish_c(group.entries[idx].task).int
    rl_fileio_free_task(group.entries[idx].task)
    group.entries[idx].done = true
    group.completedCount.inc
    if group.entries[idx].rc != 0:
      group.failedCount.inc
      if group.entries[idx].onError != nil and not group.callbackContext.isNil:
        group.entries[idx].onError(group.entries[idx].path, group.callbackContext[])
    elif group.entries[idx].onSuccess != nil and not group.callbackContext.isNil:
      group.entries[idx].onSuccess(group.entries[idx].path, group.callbackContext[])
  return group.remainingTasks() > 0

proc process*[T](group: RLTaskGroup[T]): int =
  if group.isNil:
    return 0
  discard group.tick()
  if not group.terminalCallbackInvoked and group.remainingTasks() == 0 and not group.callbackContext.isNil:
    group.terminalCallbackInvoked = true
    if group.hasFailures():
      if group.onErrorCallback != nil:
        group.onErrorCallback(group, group.callbackContext[])
    elif group.onCompleteCallback != nil:
      group.onCompleteCallback(group, group.callbackContext[])
  return group.remainingTasks()

proc failedPaths*[T](group: RLTaskGroup[T]): seq[string] =
  result = @[]
  if group.isNil:
    return
  for entry in group.entries:
    if entry.done and entry.rc != 0:
      result.add(entry.path)

proc rl_logger_set_level*(level: cint) {.importc, cdecl, header: "rl_logger.h".}
proc rl_logger_message*(level: cint, format: cstring) {.importc, cdecl, varargs, header: "rl_logger.h".}
proc rl_logger_message_source*(level: cint, sourceFile: cstring, sourceLine: cint,
                               format: cstring) {.importc, cdecl, varargs, header: "rl_logger.h".}
proc rl_event_on*(eventName: cstring, listener: RLEventListenerFn, userData: pointer): cint {.importc, cdecl, header: "rl_event.h".}
proc rl_event_once*(eventName: cstring, listener: RLEventListenerFn, userData: pointer): cint {.importc, cdecl, header: "rl_event.h".}
proc rl_event_off*(eventName: cstring, listener: RLEventListenerFn, userData: pointer): cint {.importc, cdecl, header: "rl_event.h".}
proc rl_event_off_all*(eventName: cstring): cint {.importc, cdecl, header: "rl_event.h".}
proc rl_event_emit*(eventName: cstring, payload: pointer): cint {.importc, cdecl, header: "rl_event.h".}
proc rl_event_listener_count*(eventName: cstring): cint {.importc, cdecl, header: "rl_event.h".}
proc rl_scratch_refresh*() {.importc, cdecl, header: "rl.h".}
proc rl_tick_c(): cint {.importc: "rl_tick", cdecl, header: "rl.h".}
proc rl_get_time_raw*(): cdouble {.importc: "rl_get_time", cdecl, header: "rl.h".}
proc rl_get_delta_time_raw*(): cfloat {.importc: "rl_get_delta_time", cdecl, header: "rl.h".}
proc rl_window_set_title*(title: cstring) {.importc, cdecl, header: "rl_window.h".}
proc rl_window_set_size*(width: cint, height: cint) {.importc, cdecl, header: "rl_window.h".}
proc rl_window_close_requested*(): bool {.importc, cdecl, header: "rl_window.h".}
proc rl_window_get_monitor_count*(): cint {.importc, cdecl, header: "rl.h".}
proc rl_window_get_current_monitor*(): cint {.importc, cdecl, header: "rl.h".}
proc rl_window_set_monitor*(monitor: cint) {.importc, cdecl, header: "rl.h".}
proc rl_window_get_monitor_width*(monitor: cint): cint {.importc, cdecl, header: "rl.h".}
proc rl_window_get_monitor_height*(monitor: cint): cint {.importc, cdecl, header: "rl.h".}
proc rl_window_get_screen_size*(): Vec2 {.importc, cdecl, header: "rl.h".}
proc rl_window_get_monitor_position*(monitor: cint): Vec2 {.importc, cdecl, header: "rl.h".}
proc rl_window_get_position*(): Vec2 {.importc, cdecl, header: "rl.h".}
proc rl_window_set_position*(x: cint, y: cint) {.importc, cdecl, header: "rl_window.h".}
proc rl_input_poll_events*() {.importc, cdecl, header: "rl.h".}
proc rl_input_get_mouse_position*(): Vec2 {.importc, cdecl, header: "rl.h".}
proc rl_input_get_mouse_wheel*(): cint {.importc, cdecl, header: "rl.h".}
proc rl_input_get_mouse_button*(button: cint): cint {.importc, cdecl, header: "rl.h".}
proc rl_input_get_mouse_state*(): RLMouseState {.importc, cdecl, header: "rl.h".}
proc rl_input_get_keyboard_state*(): RLKeyboardState {.importc, cdecl, header: "rl.h".}
proc rl_render_begin*() {.importc, cdecl, header: "rl.h".}
proc rl_render_end*() {.importc, cdecl, header: "rl.h".}
proc rl_is_initialized*(): bool {.importc, cdecl, header: "rl.h".}
proc rl_get_platform*(): cstring {.importc, cdecl, header: "rl.h".}
proc rl_version_major_c*(): cint {.importc: "rl_version_major", cdecl, header: "rl_version.h".}
proc rl_version_minor_c*(): cint {.importc: "rl_version_minor", cdecl, header: "rl_version.h".}
proc rl_version_patch_c*(): cint {.importc: "rl_version_patch", cdecl, header: "rl_version.h".}
proc rl_version_label_c*(): cstring {.importc: "rl_version_label", cdecl, header: "rl_version.h".}
proc rl_version_number_c*(): uint32 {.importc: "rl_version_number", cdecl, header: "rl_version.h".}
proc rl_version_string_c*(): cstring {.importc: "rl_version_string", cdecl, header: "rl_version.h".}
proc rl_version_major*(): int {.inline.} = rl_version_major_c().int
proc rl_version_minor*(): int {.inline.} = rl_version_minor_c().int
proc rl_version_patch*(): int {.inline.} = rl_version_patch_c().int
proc rl_version_label*(): string {.inline.} = $rl_version_label_c()
proc rl_version_number*(): uint32 {.inline.} = rl_version_number_c()
proc rl_version_string*(): string {.inline.} = $rl_version_string_c()

proc rl_boot*(config = RLBootConfig()): int =
  discard config
  let runtimeMajor = rl_version_major()
  let runtimeMinor = rl_version_minor()
  let runtimePatch = rl_version_patch()
  echo "[librl] bindings version: ", rlBindingMajor, ", ", rlBindingMinor, ", ", rlBindingPatch
  echo "[librl] librl version: ", runtimeMajor, ", ", runtimeMinor, ", ", runtimePatch
  if runtimeMajor != rlBindingMajor:
    raise newException(ValueError, "librl major version mismatch")
  if runtimeMinor != rlBindingMinor:
    raise newException(ValueError, "librl minor version mismatch")
  if runtimePatch != rlBindingPatch:
    echo "[librl] warning: librl patch ", runtimePatch, " differs from binding patch ", rlBindingPatch
  return RL_INIT_OK
proc rl_render_begin_mode_2d*(camera: RLHandle) {.importc, cdecl, header: "rl_render.h".}
proc rl_render_end_mode_2d*() {.importc, cdecl, header: "rl_render.h".}
proc rl_render_begin_mode_3d*() {.importc, cdecl, header: "rl.h".}
proc rl_render_end_mode_3d*() {.importc, cdecl, header: "rl.h".}
proc rl_camera3d_create*(
  positionX: cfloat, positionY: cfloat, positionZ: cfloat,
  targetX: cfloat, targetY: cfloat, targetZ: cfloat,
  upX: cfloat, upY: cfloat, upZ: cfloat,
  fovy: cfloat, projection: cint
): RLHandle {.importc, cdecl, header: "rl_camera3d.h".}
proc rl_camera3d_get_default*(): RLHandle {.importc, cdecl, header: "rl_camera3d.h".}
proc rl_camera3d_set*(
  camera: RLHandle,
  positionX: cfloat, positionY: cfloat, positionZ: cfloat,
  targetX: cfloat, targetY: cfloat, targetZ: cfloat,
  upX: cfloat, upY: cfloat, upZ: cfloat,
  fovy: cfloat, projection: cint
): bool {.importc, cdecl, header: "rl_camera3d.h".}
proc rl_camera3d_set_active*(camera: RLHandle): bool {.importc, cdecl, header: "rl_camera3d.h".}
proc rl_camera3d_get_active*(): RLHandle {.importc, cdecl, header: "rl_camera3d.h".}
proc rl_camera3d_destroy*(camera: RLHandle) {.importc, cdecl, header: "rl_camera3d.h".}
proc rl_enable_lighting*() {.importc, cdecl, header: "rl.h".}
proc rl_disable_lighting*() {.importc, cdecl, header: "rl.h".}
proc rl_is_lighting_enabled_c(): cint {.importc: "rl_is_lighting_enabled", cdecl, header: "rl.h".}
proc rl_set_light_direction*(x: cfloat, y: cfloat, z: cfloat) {.importc, cdecl, header: "rl.h".}
proc rl_set_light_ambient*(ambient: cfloat) {.importc, cdecl, header: "rl.h".}
proc rl_shape_draw_cube*(
  positionX: cfloat, positionY: cfloat, positionZ: cfloat,
  width: cfloat, height: cfloat, length: cfloat,
  color: RLHandle
) {.importc, cdecl, header: "rl.h".}
proc rl_shape_draw_rectangle*(x: cint, y: cint, width: cint, height: cint,
                              color: RLHandle) {.importc, cdecl, header: "rl_shape.h".}
proc rl_render_clear_background*(color: RLHandle) {.importc, cdecl, header: "rl.h".}
proc rl_set_target_fps*(fps: cint) {.importc, cdecl, header: "rl.h".}
proc rl_debug_enable_fps*(x: cint, y: cint, fontSize: cint, fontPath: cstring) {.importc, cdecl, header: "rl_debug.h".}
proc rl_debug_disable*() {.importc, cdecl, header: "rl_debug.h".}
proc rl_text_draw_fps*(x: cint, y: cint) {.importc, cdecl, header: "rl_text.h".}
proc rl_text_draw*(text: cstring, x: cint, y: cint, fontSize: cint, color: RLHandle) {.importc, cdecl, header: "rl.h".}
proc rl_text_draw_ex*(font: RLHandle, text: cstring, x: cint, y: cint, fontSize: cfloat, spacing: cfloat, color: RLHandle) {.importc, cdecl, header: "rl.h".}
proc rl_text_measure*(text: cstring, fontSize: cint): cint {.importc, cdecl, header: "rl_text.h".}
proc rl_text_measure_ex*(font: RLHandle, text: cstring, fontSize: cfloat, spacing: cfloat): Vec2 {.importc, cdecl, header: "rl.h".}
proc rl_text_draw_fps_ex*(font: RLHandle, x: cint, y: cint, fontSize: cfloat, color: RLHandle) {.importc, cdecl, header: "rl.h".}
proc rl_color_create*(r: cint, g: cint, b: cint, a: cint): RLHandle {.importc, cdecl, header: "rl_color.h".}
proc rl_color_destroy*(color: RLHandle) {.importc, cdecl, header: "rl_color.h".}
proc rl_font_create*(filename: cstring, fontSize: cint): RLHandle {.importc, cdecl, header: "rl_font.h".}
proc rl_font_destroy*(font: RLHandle) {.importc, cdecl, header: "rl_font.h".}
proc rl_font_get_default*(): RLHandle {.importc, cdecl, header: "rl_font.h".}
proc rl_model_create*(filename: cstring): RLHandle {.importc, cdecl, header: "rl_model.h".}
proc rl_model_set_transform*(
  model: RLHandle,
  positionX: cfloat, positionY: cfloat, positionZ: cfloat,
  rotationX: cfloat, rotationY: cfloat, rotationZ: cfloat,
  scaleX: cfloat, scaleY: cfloat, scaleZ: cfloat
): bool {.importc, cdecl, header: "rl_model.h".}
proc rl_model_draw*(model: RLHandle, tint: RLHandle) {.importc, cdecl, header: "rl_model.h".}
proc rl_model_is_valid*(model: RLHandle): bool {.importc, cdecl, header: "rl_model.h".}
proc rl_model_is_valid_strict*(model: RLHandle): bool {.importc, cdecl, header: "rl_model.h".}
proc rl_model_animation_count_c(model: RLHandle): cint {.importc: "rl_model_animation_count", cdecl, header: "rl_model.h".}
proc rl_model_animation_frame_count*(model: RLHandle, animationIndex: cint): cint {.importc, cdecl, header: "rl_model.h".}
proc rl_model_animation_update*(model: RLHandle, animationIndex: cint, frame: cint) {.importc, cdecl, header: "rl_model.h".}
proc rl_model_set_animation*(model: RLHandle, animationIndex: cint): bool {.importc, cdecl, header: "rl_model.h".}
proc rl_model_set_animation_speed*(model: RLHandle, speed: cfloat): bool {.importc, cdecl, header: "rl_model.h".}
proc rl_model_set_animation_loop*(model: RLHandle, shouldLoop: bool): bool {.importc, cdecl, header: "rl_model.h".}
proc rl_model_animate*(model: RLHandle, deltaSeconds: cfloat): bool {.importc, cdecl, header: "rl_model.h".}
proc rl_model_destroy*(model: RLHandle) {.importc, cdecl, header: "rl_model.h".}
proc rl_pick_model*(
  camera: RLHandle,
  model: RLHandle,
  mouseX: cfloat,
  mouseY: cfloat
): RLPickResult {.importc, cdecl, header: "rl_pick.h".}
proc rl_pick_sprite3d*(
  camera: RLHandle,
  sprite3d: RLHandle,
  mouseX: cfloat,
  mouseY: cfloat
): RLPickResult {.importc, cdecl, header: "rl_pick.h".}
proc rl_pick_reset_stats*() {.importc, cdecl, header: "rl_pick.h".}
proc rl_pick_get_broadphase_tests*(): cint {.importc, cdecl, header: "rl_pick.h".}
proc rl_pick_get_broadphase_rejects*(): cint {.importc, cdecl, header: "rl_pick.h".}
proc rl_pick_get_narrowphase_tests*(): cint {.importc, cdecl, header: "rl_pick.h".}
proc rl_pick_get_narrowphase_hits*(): cint {.importc, cdecl, header: "rl_pick.h".}
proc rl_music_create*(filename: cstring): RLHandle {.importc, cdecl, header: "rl_music.h".}
proc rl_music_destroy*(music: RLHandle) {.importc, cdecl, header: "rl_music.h".}
proc rl_music_play*(music: RLHandle): bool {.importc, cdecl, header: "rl_music.h".}
proc rl_music_pause*(music: RLHandle): bool {.importc, cdecl, header: "rl_music.h".}
proc rl_music_stop*(music: RLHandle): bool {.importc, cdecl, header: "rl_music.h".}
proc rl_music_set_loop*(music: RLHandle, shouldLoop: bool): bool {.importc, cdecl, header: "rl_music.h".}
proc rl_music_set_volume*(music: RLHandle, volume: cfloat): bool {.importc, cdecl, header: "rl_music.h".}
proc rl_music_is_playing*(music: RLHandle): bool {.importc, cdecl, header: "rl_music.h".}
proc rl_music_update*(music: RLHandle): bool {.importc, cdecl, header: "rl_music.h".}
proc rl_music_update_all*() {.importc, cdecl, header: "rl_music.h".}
proc rl_sound_create*(filename: cstring): RLHandle {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_destroy*(sound: RLHandle) {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_play*(sound: RLHandle): bool {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_pause*(sound: RLHandle): bool {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_resume*(sound: RLHandle): bool {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_stop*(sound: RLHandle): bool {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_set_volume*(sound: RLHandle, volume: cfloat): bool {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_set_pitch*(sound: RLHandle, pitch: cfloat): bool {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_set_pan*(sound: RLHandle, pan: cfloat): bool {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_is_playing*(sound: RLHandle): bool {.importc, cdecl, header: "rl_sound.h".}
proc rl_texture_create*(filename: cstring): RLHandle {.importc, cdecl, header: "rl_texture.h".}
proc rl_texture_destroy*(texture: RLHandle) {.importc, cdecl, header: "rl_texture.h".}
proc rl_texture_draw_ex*(texture: RLHandle, x: cfloat, y: cfloat, scale: cfloat,
                         rotation: cfloat, tint: RLHandle) {.importc, cdecl, header: "rl_texture.h".}
proc rl_texture_draw_ground*(texture: RLHandle, x: cfloat, y: cfloat, z: cfloat,
                             width: cfloat, length: cfloat, tint: RLHandle) {.importc, cdecl, header: "rl_texture.h".}
proc rl_sprite3d_create*(filename: cstring): RLHandle {.importc, cdecl, header: "rl_sprite3d.h".}
proc rl_sprite3d_create_from_texture*(texture: RLHandle): RLHandle {.importc, cdecl, header: "rl_sprite3d.h".}
proc rl_sprite3d_set_transform*(
  sprite: RLHandle,
  positionX: cfloat, positionY: cfloat, positionZ: cfloat,
  size: cfloat
): bool {.importc, cdecl, header: "rl_sprite3d.h".}
proc rl_sprite3d_draw*(sprite: RLHandle, tint: RLHandle) {.importc, cdecl, header: "rl_sprite3d.h".}
proc rl_sprite3d_destroy*(sprite: RLHandle) {.importc, cdecl, header: "rl_sprite3d.h".}
proc rl_sprite2d_create*(filename: cstring): RLHandle {.importc, cdecl, header: "rl_sprite2d.h".}
proc rl_sprite2d_create_from_texture*(texture: RLHandle): RLHandle {.importc, cdecl, header: "rl_sprite2d.h".}
proc rl_sprite2d_set_transform*(
  sprite: RLHandle,
  x: cfloat, y: cfloat,
  scale: cfloat, rotation: cfloat
): bool {.importc, cdecl, header: "rl_sprite2d.h".}
proc rl_sprite2d_draw*(sprite: RLHandle, tint: RLHandle) {.importc, cdecl, header: "rl_sprite2d.h".}
proc rl_sprite2d_destroy*(sprite: RLHandle) {.importc, cdecl, header: "rl_sprite2d.h".}

# Text2D
proc rl_text2d_create_c(font: RLHandle, size: cfloat): RLHandle {.importc: "rl_text2d_create", cdecl, header: "rl_text2d.h".}
proc rl_text2d_set_font*(handle: RLHandle, font: RLHandle) {.importc, cdecl, header: "rl_text2d.h".}
proc rl_text2d_set_size_c(handle: RLHandle, size: cfloat) {.importc: "rl_text2d_set_size", cdecl, header: "rl_text2d.h".}
proc rl_text2d_set_content_c(handle: RLHandle, content: cstring) {.importc: "rl_text2d_set_content", cdecl, header: "rl_text2d.h".}
proc rl_text2d_set_position_c(handle: RLHandle, x: cfloat, y: cfloat) {.importc: "rl_text2d_set_position", cdecl, header: "rl_text2d.h".}
proc rl_text2d_set_color*(handle: RLHandle, color: RLHandle) {.importc, cdecl, header: "rl_text2d.h".}
proc rl_text2d_draw*(handle: RLHandle) {.importc, cdecl, header: "rl_text2d.h".}
proc rl_text2d_destroy*(handle: RLHandle) {.importc, cdecl, header: "rl_text2d.h".}

proc rl_text2d_create*(font: RLHandle, size: float): RLHandle {.inline.} =
  rl_text2d_create_c(font, size.cfloat)
proc rl_text2d_set_size*(handle: RLHandle, size: float) {.inline.} =
  rl_text2d_set_size_c(handle, size.cfloat)
proc rl_text2d_set_content*(handle: RLHandle, content: string) {.inline.} =
  rl_text2d_set_content_c(handle, content.cstring)
proc rl_text2d_set_position*(handle: RLHandle, x: float, y: float) {.inline.} =
  rl_text2d_set_position_c(handle, x.cfloat, y.cfloat)

proc rl_get_time*(): float {.inline.} =
  rl_get_time_raw().float

proc rl_get_delta_time*(): float {.inline.} =
  rl_get_delta_time_raw().float

proc rl_tick*(): int {.inline.} = rl_tick_c().int

proc rl_is_lighting_enabled*(): int {.inline.} = rl_is_lighting_enabled_c().int

proc rl_model_animation_count*(model: RLHandle): int {.inline.} = rl_model_animation_count_c(model).int

proc rl_fileio_finish_task*(task: RLHandle): int {.inline.} = rl_fileio_finish_c(task).int

proc rl_window_set_title*(title: string) {.inline.} =
  rl_window_set_title(title.cstring)

proc rl_window_set_size*(width, height: int) {.inline.} =
  rl_window_set_size(width.cint, height.cint)

proc rl_window_set_monitor*(monitor: int) {.inline.} =
  rl_window_set_monitor(monitor.cint)

proc rl_window_get_monitor_width*(monitor: int): int {.inline.} =
  rl_window_get_monitor_width(monitor.cint).int

proc rl_window_get_monitor_height*(monitor: int): int {.inline.} =
  rl_window_get_monitor_height(monitor.cint).int

proc rl_window_get_monitor_position*(monitor: int): Vec2 {.inline.} =
  rl_window_get_monitor_position(monitor.cint)

proc rl_window_set_position*(x, y: int) {.inline.} =
  rl_window_set_position(x.cint, y.cint)

proc rl_input_get_mouse_button*(button: int): int {.inline.} =
  rl_input_get_mouse_button(button.cint).int

proc rl_camera3d_create*(
  positionX, positionY, positionZ,
  targetX, targetY, targetZ,
  upX, upY, upZ, fovy: float, projection: int
): RLHandle {.inline.} =
  rl_camera3d_create(
    positionX.cfloat, positionY.cfloat, positionZ.cfloat,
    targetX.cfloat, targetY.cfloat, targetZ.cfloat,
    upX.cfloat, upY.cfloat, upZ.cfloat,
    fovy.cfloat, projection.cint
  )

proc rl_camera3d_set*(
  camera: RLHandle,
  positionX, positionY, positionZ,
  targetX, targetY, targetZ,
  upX, upY, upZ, fovy: float, projection: int
): bool {.inline.} =
  rl_camera3d_set(
    camera,
    positionX.cfloat, positionY.cfloat, positionZ.cfloat,
    targetX.cfloat, targetY.cfloat, targetZ.cfloat,
    upX.cfloat, upY.cfloat, upZ.cfloat,
    fovy.cfloat, projection.cint
  )

proc rl_set_light_direction*(x, y, z: float) {.inline.} =
  rl_set_light_direction(x.cfloat, y.cfloat, z.cfloat)

proc rl_set_light_ambient*(ambient: float) {.inline.} =
  rl_set_light_ambient(ambient.cfloat)

proc rl_shape_draw_cube*(
  positionX, positionY, positionZ,
  width, height, length: float,
  tint: RLHandle
) {.inline.} =
  rl_shape_draw_cube(
    positionX.cfloat, positionY.cfloat, positionZ.cfloat,
    width.cfloat, height.cfloat, length.cfloat,
    tint
  )

proc rl_shape_draw_rectangle*(x, y, width, height: int, color: RLHandle) {.inline.} =
  rl_shape_draw_rectangle(x.cint, y.cint, width.cint, height.cint, color)

proc rl_set_target_fps*(fps: int) {.inline.} =
  rl_set_target_fps(fps.cint)

proc rl_debug_enable_fps*(x, y, fontSize: int, fontPath: string) {.inline.} =
  rl_debug_enable_fps(x.cint, y.cint, fontSize.cint, fontPath.cstring)

proc rl_text_draw_fps*(x, y: int) {.inline.} =
  rl_text_draw_fps(x.cint, y.cint)

proc rl_text_draw*(text: string, x, y, fontSize: int, color: RLHandle) {.inline.} =
  rl_text_draw(text.cstring, x.cint, y.cint, fontSize.cint, color)

proc rl_text_draw_ex*(font: RLHandle, text: string, x, y: int,
                      fontSize, spacing: float, color: RLHandle) {.inline.} =
  rl_text_draw_ex(font, text.cstring, x.cint, y.cint, fontSize.cfloat, spacing.cfloat, color)

proc rl_text_measure*(text: string, fontSize: int): int {.inline.} =
  rl_text_measure(text.cstring, fontSize.cint).int

proc rl_text_measure_ex*(font: RLHandle, text: string, fontSize, spacing: float): Vec2 {.inline.} =
  rl_text_measure_ex(font, text.cstring, fontSize.cfloat, spacing.cfloat)

proc rl_text_draw_fps_ex*(font: RLHandle, x, y: int, fontSize: float,
                          color: RLHandle) {.inline.} =
  rl_text_draw_fps_ex(font, x.cint, y.cint, fontSize.cfloat, color)

proc rl_color_create*(r, g, b, a: int): RLHandle {.inline.} =
  rl_color_create(r.cint, g.cint, b.cint, a.cint)

proc rl_font_create*(filename: string, fontSize: int): RLHandle {.inline.} =
  rl_font_create(filename.cstring, fontSize.cint)

proc rl_model_create*(filename: string): RLHandle {.inline.} =
  rl_model_create(filename.cstring)

proc rl_model_set_transform*(
  model: RLHandle,
  positionX, positionY, positionZ,
  rotationX, rotationY, rotationZ,
  scaleX, scaleY, scaleZ: float
): bool {.inline.} =
  rl_model_set_transform(
    model,
    positionX.cfloat, positionY.cfloat, positionZ.cfloat,
    rotationX.cfloat, rotationY.cfloat, rotationZ.cfloat,
    scaleX.cfloat, scaleY.cfloat, scaleZ.cfloat
  )

proc rl_model_animation_frame_count*(model: RLHandle, animationIndex: int): int {.inline.} =
  rl_model_animation_frame_count(model, animationIndex.cint).int

proc rl_model_animation_update*(model: RLHandle, animationIndex, frame: int) {.inline.} =
  rl_model_animation_update(model, animationIndex.cint, frame.cint)

proc rl_model_set_animation*(model: RLHandle, animationIndex: int): bool {.inline.} =
  rl_model_set_animation(model, animationIndex.cint)

proc rl_model_set_animation_speed*(model: RLHandle, speed: float): bool {.inline.} =
  rl_model_set_animation_speed(model, speed.cfloat)

proc rl_model_animate*(model: RLHandle, deltaSeconds: float): bool {.inline.} =
  rl_model_animate(model, deltaSeconds.cfloat)

proc rl_music_create*(filename: string): RLHandle {.inline.} =
  rl_music_create(filename.cstring)

proc rl_music_set_volume*(music: RLHandle, volume: float): bool {.inline.} =
  rl_music_set_volume(music, volume.cfloat)

proc rl_sound_create*(filename: string): RLHandle {.inline.} =
  rl_sound_create(filename.cstring)

proc rl_sound_set_volume*(sound: RLHandle, volume: float): bool {.inline.} =
  rl_sound_set_volume(sound, volume.cfloat)

proc rl_sound_set_pitch*(sound: RLHandle, pitch: float): bool {.inline.} =
  rl_sound_set_pitch(sound, pitch.cfloat)

proc rl_sound_set_pan*(sound: RLHandle, pan: float): bool {.inline.} =
  rl_sound_set_pan(sound, pan.cfloat)

proc rl_texture_create*(filename: string): RLHandle {.inline.} =
  rl_texture_create(filename.cstring)

proc rl_texture_draw_ex*(texture: RLHandle, x, y, scale, rotation: float,
                         tint: RLHandle) {.inline.} =
  rl_texture_draw_ex(texture, x.cfloat, y.cfloat, scale.cfloat, rotation.cfloat, tint)

proc rl_texture_draw_ground*(texture: RLHandle, x, y, z, width, length: float,
                             tint: RLHandle) {.inline.} =
  rl_texture_draw_ground(texture, x.cfloat, y.cfloat, z.cfloat, width.cfloat, length.cfloat, tint)

proc rl_sprite3d_create*(filename: string): RLHandle {.inline.} =
  rl_sprite3d_create(filename.cstring)

proc rl_sprite3d_set_transform*(sprite: RLHandle,
                                positionX, positionY, positionZ, size: float): bool {.inline.} =
  rl_sprite3d_set_transform(sprite, positionX.cfloat, positionY.cfloat, positionZ.cfloat, size.cfloat)

proc rl_sprite2d_create*(filename: string): RLHandle {.inline.} =
  rl_sprite2d_create(filename.cstring)

proc rl_sprite2d_set_transform*(sprite: RLHandle,
                                x, y, scale, rotation: float): bool {.inline.} =
  rl_sprite2d_set_transform(sprite, x.cfloat, y.cfloat, scale.cfloat, rotation.cfloat)

proc clearText*(text: var array[256, char]) {.inline.} =
  text[0] = '\0'

proc setText*(text: var array[256, char], value: string): int {.inline.} =
  let last = text.high
  var copied = 0
  while copied < value.len and copied < last:
    text[copied] = value[copied]
    inc copied
  text[copied] = '\0'
  copied

proc textLen*(text: array[256, char]): int {.inline.} =
  var i = 0
  while i < text.len and text[i] != '\0':
    inc i
  i
