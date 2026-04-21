type
  RLHandle* = uint32
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
  RLModuleLogFn* = proc(userData: pointer, level: cint, message: cstring) {.cdecl.}
  RLModuleLogSourceFn* = proc(userData: pointer, level: cint, sourceFile: cstring,
                              sourceLine: cint, message: cstring) {.cdecl.}
  RLModuleAllocFn* = proc(size: csize_t, userData: pointer): pointer {.cdecl.}
  RLModuleFreeFn* = proc(p: pointer, userData: pointer) {.cdecl.}
  RLModuleEventListenerFn* = proc(payload: pointer, listenerUserData: pointer) {.cdecl.}
  RLModuleEventOnFn* = proc(hostUserData: pointer, eventName: cstring,
                            listener: RLModuleEventListenerFn, listenerUserData: pointer): cint {.cdecl.}
  RLModuleEventOffFn* = proc(hostUserData: pointer, eventName: cstring,
                             listener: RLModuleEventListenerFn, listenerUserData: pointer): cint {.cdecl.}
  RLModuleEventEmitFn* = proc(hostUserData: pointer, eventName: cstring, payload: pointer): cint {.cdecl.}
  RLLoaderCallbackFn* = proc(path: cstring, userData: pointer) {.cdecl.}
  RLInitFn* = proc(userData: pointer) {.cdecl.}
  RLTickFn* = proc(userData: pointer) {.cdecl.}
  RLShutdownFn* = proc(userData: pointer) {.cdecl.}
  RLModuleInitFn* = proc(host: ptr RLModuleHostApi, moduleState: ptr pointer): cint {.cdecl.}
  RLModuleDeinitFn* = proc(moduleState: pointer) {.cdecl.}
  RLModuleUpdateFn* = proc(moduleState: pointer, dtSeconds: cfloat): cint {.cdecl.}
  RLModuleHostApi* {.importc: "rl_module_host_api_t", header: "rl_module.h", bycopy.} = object
    user_data*: pointer
    log*: RLModuleLogFn
    log_source*: RLModuleLogSourceFn
    alloc*: RLModuleAllocFn
    free*: RLModuleFreeFn
    event_on*: RLModuleEventOnFn
    event_off*: RLModuleEventOffFn
    event_emit*: RLModuleEventEmitFn
  RLModuleApi* {.importc: "rl_module_api_t", header: "rl_module.h", bycopy.} = object
    name*: cstring
    abi_version*: cint
    init*: RLModuleInitFn
    deinit*: RLModuleDeinitFn
    update*: RLModuleUpdateFn
  RLModuleInstance* {.importc: "rl_module_instance_t", header: "rl_module.h", bycopy.} = object
    api*: ptr RLModuleApi
    state*: pointer
  RLModuleEntryGetApiFn* = proc(): ptr RLModuleApi {.cdecl.}
  RLModuleEntry* {.importc: "rl_module_entry_t", header: "rl_module.h", bycopy.} = object
    name*: cstring
    get_api_fn*: RLModuleEntryGetApiFn
  RLLoaderTask* {.importc: "rl_loader_task_t", header: "rl_loader.h", bycopy.} = object

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
  RL_CAMERA_PERSPECTIVE* = 0.cint
  RL_CAMERA_ORTHOGRAPHIC* = 1.cint
  RL_FLAG_WINDOW_RESIZABLE* = 4.cint
  RL_FLAG_MSAA_4X_HINT* = 32.cint
  RL_BUTTON_UP* = 0.cint
  RL_BUTTON_PRESSED* = 1.cint
  RL_BUTTON_DOWN* = 2.cint
  RL_BUTTON_RELEASED* = 3.cint
  RL_MODULE_LOG_TRACE* = 0.cint
  RL_MODULE_LOG_DEBUG* = 1.cint
  RL_MODULE_LOG_INFO* = 2.cint
  RL_MODULE_LOG_WARN* = 3.cint
  RL_MODULE_LOG_ERROR* = 4.cint
  RL_LOGGER_LEVEL_TRACE* = 0.cint
  RL_LOGGER_LEVEL_DEBUG* = 1.cint
  RL_LOGGER_LEVEL_INFO* = 2.cint
  RL_LOGGER_LEVEL_WARN* = 3.cint
  RL_LOGGER_LEVEL_ERROR* = 4.cint
  RL_LOGGER_LEVEL_FATAL* = 5.cint
  RL_MODULE_ABI_VERSION* = 1.cint
  RL_LOADER_ADD_TASK_OK* = 0.cint
  RL_LOADER_ADD_TASK_ERR_INVALID* = (-1).cint
  RL_LOADER_ADD_TASK_ERR_QUEUE_FULL* = (-2).cint
proc rl_init*() {.importc, cdecl, header: "rl.h".}
proc rl_deinit*() {.importc, cdecl, header: "rl.h".}
proc rl_set_asset_host*(assetHost: cstring): cint {.importc, cdecl, header: "rl.h".}
proc rl_get_asset_host*(): cstring {.importc, cdecl, header: "rl.h".}
proc rl_loader_set_asset_host*(assetHost: cstring): cint {.importc, cdecl, header: "rl_loader.h".}
proc rl_loader_get_asset_host*(): cstring {.importc, cdecl, header: "rl_loader.h".}
proc rl_loader_restore_fs_async*(): ptr RLLoaderTask {.importc, cdecl, header: "rl_loader.h".}
proc rl_loader_import_asset_async*(filename: cstring): ptr RLLoaderTask {.importc, cdecl, header: "rl_loader.h".}
proc rl_loader_import_assets_async_raw(filenames: ptr cstring, filenameCount: csize_t): ptr RLLoaderTask {.importc: "rl_loader_import_assets_async", cdecl, header: "rl_loader.h".}

proc rl_loader_import_assets_async*(filenames: openArray[string]): ptr RLLoaderTask =
  var cstrs = newSeq[cstring](filenames.len)
  for i, s in filenames:
    cstrs[i] = s.cstring
  return rl_loader_import_assets_async_raw(addr cstrs[0], cstrs.len.csize_t)

proc rl_loader_poll_task*(task: ptr RLLoaderTask): bool {.importc, cdecl, header: "rl_loader.h".}
proc rl_loader_finish_task*(task: ptr RLLoaderTask): cint {.importc, cdecl, header: "rl_loader.h".}
proc rl_loader_free_task*(task: ptr RLLoaderTask) {.importc, cdecl, header: "rl_loader.h".}
proc rl_loader_add_task*(task: ptr RLLoaderTask, path: cstring,
                         onSuccess: RLLoaderCallbackFn, onFailure: RLLoaderCallbackFn,
                         userData: pointer): cint {.importc, cdecl, header: "rl_loader.h".}
proc rl_loader_tick*() {.importc, cdecl, header: "rl_loader.h".}
proc rl_loader_is_local*(filename: cstring): bool {.importc, cdecl, header: "rl_loader.h".}
proc rl_loader_uncache_file*(filename: cstring): cint {.importc, cdecl, header: "rl_loader.h".}
proc rl_loader_clear_cache*(): cint {.importc, cdecl, header: "rl_loader.h".}
proc rl_logger_set_level*(level: cint) {.importc, cdecl, header: "rl_logger.h".}
proc rl_logger_message*(level: cint, format: cstring) {.importc, cdecl, varargs, header: "rl_logger.h".}
proc rl_logger_message_source*(level: cint, sourceFile: cstring, sourceLine: cint,
                               format: cstring) {.importc, cdecl, varargs, header: "rl_logger.h".}
proc rl_module_log*(host: ptr RLModuleHostApi, level: cint, message: cstring) {.importc, cdecl, header: "rl_module.h".}
proc rl_module_log_source*(host: ptr RLModuleHostApi, level: cint, sourceFile: cstring,
                           sourceLine: cint, message: cstring) {.importc, cdecl, header: "rl_module.h".}
proc rl_module_alloc*(host: ptr RLModuleHostApi, size: csize_t): pointer {.importc, cdecl, header: "rl_module.h".}
proc rl_module_free*(host: ptr RLModuleHostApi, p: pointer) {.importc, cdecl, header: "rl_module.h".}
proc rl_module_event_on*(host: ptr RLModuleHostApi, eventName: cstring,
                         listener: RLModuleEventListenerFn, listenerUserData: pointer): cint {.importc, cdecl, header: "rl_module.h".}
proc rl_module_event_off*(host: ptr RLModuleHostApi, eventName: cstring,
                          listener: RLModuleEventListenerFn, listenerUserData: pointer): cint {.importc, cdecl, header: "rl_module.h".}
proc rl_module_event_emit*(host: ptr RLModuleHostApi, eventName: cstring, payload: pointer): cint {.importc, cdecl, header: "rl_module.h".}
proc rl_module_api_validate*(api: ptr RLModuleApi, error: cstring, errorSize: csize_t): cint {.importc, cdecl, header: "rl_module.h".}
proc rl_module_init_instance*(api: ptr RLModuleApi, host: ptr RLModuleHostApi, moduleState: ptr pointer,
                              error: cstring, errorSize: csize_t): cint {.importc, cdecl, header: "rl_module.h".}
proc rl_module_deinit_instance*(api: ptr RLModuleApi, moduleState: pointer) {.importc, cdecl, header: "rl_module.h".}
proc rl_module_get_api*(name: cstring): ptr RLModuleApi {.importc, cdecl, header: "rl_module.h".}
proc rl_module_init*(name: cstring, host: ptr RLModuleHostApi, outApi: ptr ptr RLModuleApi,
                     moduleState: ptr pointer, error: cstring, errorSize: csize_t): cint {.importc, cdecl, header: "rl_module.h".}
proc rl_event_on*(eventName: cstring, listener: RLEventListenerFn, userData: pointer): cint {.importc, cdecl, header: "rl_event.h".}
proc rl_event_once*(eventName: cstring, listener: RLEventListenerFn, userData: pointer): cint {.importc, cdecl, header: "rl_event.h".}
proc rl_event_off*(eventName: cstring, listener: RLEventListenerFn, userData: pointer): cint {.importc, cdecl, header: "rl_event.h".}
proc rl_event_off_all*(eventName: cstring): cint {.importc, cdecl, header: "rl_event.h".}
proc rl_event_emit*(eventName: cstring, payload: pointer): cint {.importc, cdecl, header: "rl_event.h".}
proc rl_event_listener_count*(eventName: cstring): cint {.importc, cdecl, header: "rl_event.h".}
proc rl_update*() {.importc, cdecl, header: "rl.h".}
proc rl_run*(initFn: RLInitFn, tickFn: RLTickFn, shutdownFn: RLShutdownFn, userData: pointer) {.importc, cdecl, header: "rl.h".}
proc rl_request_stop*() {.importc, cdecl, header: "rl.h".}
proc rl_get_time*(): cdouble {.importc, cdecl, header: "rl.h".}
proc rl_get_delta_time*(): cfloat {.importc, cdecl, header: "rl.h".}
proc rl_window_open*(width: cint, height: cint, title: cstring, flags: cint) {.importc, cdecl, header: "rl.h".}
proc rl_window_set_title*(title: cstring) {.importc, cdecl, header: "rl_window.h".}
proc rl_window_set_size*(width: cint, height: cint) {.importc, cdecl, header: "rl_window.h".}
proc rl_window_get_monitor_count*(): cint {.importc, cdecl, header: "rl.h".}
proc rl_window_get_current_monitor*(): cint {.importc, cdecl, header: "rl.h".}
proc rl_window_set_monitor*(monitor: cint) {.importc, cdecl, header: "rl.h".}
proc rl_window_get_monitor_width*(monitor: cint): cint {.importc, cdecl, header: "rl.h".}
proc rl_window_get_monitor_height*(monitor: cint): cint {.importc, cdecl, header: "rl.h".}
proc rl_window_get_screen_size*(): Vec2 {.importc, cdecl, header: "rl.h".}
proc rl_window_get_monitor_position*(monitor: cint): Vec2 {.importc, cdecl, header: "rl.h".}
proc rl_window_get_position*(): Vec2 {.importc, cdecl, header: "rl.h".}
proc rl_window_set_position*(x: cint, y: cint) {.importc, cdecl, header: "rl_window.h".}
proc rl_input_get_mouse_position*(): Vec2 {.importc, cdecl, header: "rl.h".}
proc rl_input_get_mouse_wheel*(): cint {.importc, cdecl, header: "rl.h".}
proc rl_input_get_mouse_button*(button: cint): cint {.importc, cdecl, header: "rl.h".}
proc rl_input_get_mouse_state*(): RLMouseState {.importc, cdecl, header: "rl.h".}
proc rl_input_get_keyboard_state*(): RLKeyboardState {.importc, cdecl, header: "rl.h".}
proc rl_window_close*() {.importc, cdecl, header: "rl.h".}
proc rl_render_begin*() {.importc, cdecl, header: "rl.h".}
proc rl_render_end*() {.importc, cdecl, header: "rl.h".}
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
proc rl_is_lighting_enabled*(): cint {.importc, cdecl, header: "rl.h".}
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
proc rl_text_draw_fps_ex*(font: RLHandle, x: cint, y: cint, fontSize: cint, color: RLHandle) {.importc, cdecl, header: "rl.h".}
proc rl_color_create*(r: cint, g: cint, b: cint, a: cint): RLHandle {.importc, cdecl, header: "rl_color.h".}
proc rl_color_destroy*(color: RLHandle) {.importc, cdecl, header: "rl_color.h".}
proc rl_font_create*(filename: cstring, fontSize: cfloat): RLHandle {.importc, cdecl, header: "rl_font.h".}
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
proc rl_model_animation_count*(model: RLHandle): cint {.importc, cdecl, header: "rl_model.h".}
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
  mouseY: cfloat,
  positionX: cfloat,
  positionY: cfloat,
  positionZ: cfloat,
  scale: cfloat
): RLPickResult {.importc, cdecl, header: "rl_pick.h".}
proc rl_pick_sprite3d*(
  camera: RLHandle,
  sprite3d: RLHandle,
  mouseX: cfloat,
  mouseY: cfloat,
  positionX: cfloat,
  positionY: cfloat,
  positionZ: cfloat,
  size: cfloat
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

# --- Sprite2D (rl_sprite2d.h) ---
proc rl_sprite2d_create*(filename: cstring): RLHandle {.importc, cdecl, header: "rl_sprite2d.h".}
proc rl_sprite2d_create_from_texture*(texture: RLHandle): RLHandle {.importc, cdecl, header: "rl_sprite2d.h".}
proc rl_sprite2d_set_transform*(
  sprite: RLHandle,
  x: cfloat, y: cfloat,
  scale: cfloat, rotation: cfloat
): bool {.importc, cdecl, header: "rl_sprite2d.h".}
proc rl_sprite2d_draw*(sprite: RLHandle, tint: RLHandle) {.importc, cdecl, header: "rl_sprite2d.h".}
proc rl_sprite2d_destroy*(sprite: RLHandle) {.importc, cdecl, header: "rl_sprite2d.h".}

proc clearText*(text: var array[256, char]) {.inline.} =
  text[0] = '\0'

proc setText*(text: var array[256, char], value: string): cint {.inline.} =
  let last = text.high
  var copied = 0
  while copied < value.len and copied < last:
    text[copied] = value[copied]
    inc copied
  text[copied] = '\0'
  copied.cint

proc textLen*(text: array[256, char]): cint {.inline.} =
  var i = 0
  while i < text.len and text[i] != '\0':
    inc i
  i.cint

