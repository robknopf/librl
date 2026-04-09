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
  RLFrameClear* {.importc: "rl_frame_clear_t", header: "rl_frame_command.h", bycopy.} = object
    color*: RLHandle
  RLFrameDrawText* {.importc: "rl_frame_draw_text_t", header: "rl_frame_command.h", bycopy.} = object
    font*: RLHandle
    color*: RLHandle
    x*: cfloat
    y*: cfloat
    font_size*: cfloat
    spacing*: cfloat
    text*: array[256, char]
  RLFrameDrawSprite3d* {.importc: "rl_frame_draw_sprite3d_t", header: "rl_frame_command.h", bycopy.} = object
    sprite*: RLHandle
    tint*: RLHandle
  RLFramePlaySound* {.importc: "rl_frame_play_sound_t", header: "rl_frame_command.h", bycopy.} = object
    sound*: RLHandle
    volume*: cfloat
    pitch*: cfloat
    pan*: cfloat
  RLFramePlayMusic* {.importc: "rl_frame_play_music_t", header: "rl_frame_command.h", bycopy.} = object
    music*: RLHandle
  RLFramePauseMusic* {.importc: "rl_frame_pause_music_t", header: "rl_frame_command.h", bycopy.} = object
    music*: RLHandle
  RLFrameStopMusic* {.importc: "rl_frame_stop_music_t", header: "rl_frame_command.h", bycopy.} = object
    music*: RLHandle
  RLFrameSetMusicLoop* {.importc: "rl_frame_set_music_loop_t", header: "rl_frame_command.h", bycopy.} = object
    music*: RLHandle
    loop*: bool
  RLFrameSetMusicVolume* {.importc: "rl_frame_set_music_volume_t", header: "rl_frame_command.h", bycopy.} = object
    music*: RLHandle
    volume*: cfloat
  RLFrameDrawModel* {.importc: "rl_frame_draw_model_t", header: "rl_frame_command.h", bycopy.} = object
    model*: RLHandle
    tint*: RLHandle
    animation_index*: cint
    animation_frame*: cint
  RLFrameDrawTexture* {.importc: "rl_frame_draw_texture_t", header: "rl_frame_command.h", bycopy.} = object
    texture*: RLHandle
    tint*: RLHandle
    x*: cfloat
    y*: cfloat
    scale*: cfloat
    rotation*: cfloat
  RLFrameDrawCube* {.importc: "rl_frame_draw_cube_t", header: "rl_frame_command.h", bycopy.} = object
    color*: RLHandle
    x*: cfloat
    y*: cfloat
    z*: cfloat
    width*: cfloat
    height*: cfloat
    length*: cfloat
  RLFrameDrawGroundTexture* {.importc: "rl_frame_draw_ground_texture_t", header: "rl_frame_command.h", bycopy.} = object
    texture*: RLHandle
    tint*: RLHandle
    x*: cfloat
    y*: cfloat
    z*: cfloat
    width*: cfloat
    length*: cfloat
  RLFrameSetCamera3d* {.importc: "rl_frame_set_camera3d_t", header: "rl_frame_command.h", bycopy.} = object
    camera*: RLHandle
    position_x*: cfloat
    position_y*: cfloat
    position_z*: cfloat
    target_x*: cfloat
    target_y*: cfloat
    target_z*: cfloat
    up_x*: cfloat
    up_y*: cfloat
    up_z*: cfloat
    fovy*: cfloat
    projection*: cint
  RLFrameSetModelTransform* {.importc: "rl_frame_set_model_transform_t", header: "rl_frame_command.h", bycopy.} = object
    model*: RLHandle
    position_x*: cfloat
    position_y*: cfloat
    position_z*: cfloat
    rotation_x*: cfloat
    rotation_y*: cfloat
    rotation_z*: cfloat
    scale_x*: cfloat
    scale_y*: cfloat
    scale_z*: cfloat
  RLFrameSetSprite3dTransform* {.importc: "rl_frame_set_sprite3d_transform_t", header: "rl_frame_command.h", bycopy.} = object
    sprite*: RLHandle
    position_x*: cfloat
    position_y*: cfloat
    position_z*: cfloat
    size*: cfloat
  RLRenderCommandData* {.importc: "data", header: "rl_frame_command.h", bycopy, union.} = object
    clear*: RLFrameClear
    draw_text*: RLFrameDrawText
    draw_sprite3d*: RLFrameDrawSprite3d
    play_sound*: RLFramePlaySound
    play_music*: RLFramePlayMusic
    pause_music*: RLFramePauseMusic
    stop_music*: RLFrameStopMusic
    set_music_loop*: RLFrameSetMusicLoop
    set_music_volume*: RLFrameSetMusicVolume
    draw_model*: RLFrameDrawModel
    draw_texture*: RLFrameDrawTexture
    draw_cube*: RLFrameDrawCube
    draw_ground_texture*: RLFrameDrawGroundTexture
    set_camera3d*: RLFrameSetCamera3d
    set_model_transform*: RLFrameSetModelTransform
    set_sprite3d_transform*: RLFrameSetSprite3dTransform
  RLRenderCommand* {.importc: "rl_render_command_t", header: "rl_frame_command.h", bycopy.} = object
    `type`*: cint
    data*: RLRenderCommandData
  RLFrameCommandBuffer* {.importc: "rl_frame_command_buffer_t", header: "rl_frame_command.h", bycopy.} = object
    commands*: array[128, RLRenderCommand]
    count*: cint

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
  RL_FRAME_COMMAND_CAPACITY* = 128.cint
  RL_FRAME_TEXT_MAX* = 256.cint
  RL_RENDER_CMD_CLEAR* = 0.cint
  RL_RENDER_CMD_DRAW_TEXT* = 1.cint
  RL_RENDER_CMD_DRAW_SPRITE3D* = 2.cint
  RL_RENDER_CMD_PLAY_SOUND* = 3.cint
  RL_RENDER_CMD_DRAW_MODEL* = 4.cint
  RL_RENDER_CMD_DRAW_TEXTURE* = 5.cint
  RL_RENDER_CMD_DRAW_CUBE* = 6.cint
  RL_RENDER_CMD_DRAW_GROUND_TEXTURE* = 7.cint
  RL_RENDER_CMD_SET_CAMERA3D* = 8.cint
  RL_RENDER_CMD_SET_MODEL_TRANSFORM* = 9.cint
  RL_RENDER_CMD_SET_SPRITE3D_TRANSFORM* = 10.cint
  RL_RENDER_CMD_PLAY_MUSIC* = 11.cint
  RL_RENDER_CMD_PAUSE_MUSIC* = 12.cint
  RL_RENDER_CMD_STOP_MUSIC* = 13.cint
  RL_RENDER_CMD_SET_MUSIC_LOOP* = 14.cint
  RL_RENDER_CMD_SET_MUSIC_VOLUME* = 15.cint

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
proc rl_frame_commands_reset*(frameCommands: ptr RLFrameCommandBuffer) {.importc, cdecl, header: "rl_frame_command.h".}
proc rl_frame_commands_append*(userData: pointer, command: ptr RLRenderCommand) {.importc, cdecl, header: "rl_frame_command.h".}
proc rl_frame_commands_execute_clear*(frameCommands: ptr RLFrameCommandBuffer) {.importc, cdecl, header: "rl_frame_command.h".}
proc rl_frame_commands_execute_audio*(frameCommands: ptr RLFrameCommandBuffer) {.importc, cdecl, header: "rl_frame_command.h".}
proc rl_frame_commands_execute_state*(frameCommands: ptr RLFrameCommandBuffer) {.importc, cdecl, header: "rl_frame_command.h".}
proc rl_frame_commands_execute_3d*(frameCommands: ptr RLFrameCommandBuffer) {.importc, cdecl, header: "rl_frame_command.h".}
proc rl_frame_commands_execute_2d*(frameCommands: ptr RLFrameCommandBuffer) {.importc, cdecl, header: "rl_frame_command.h".}
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

proc initRenderCommand*(kind: cint): RLRenderCommand {.inline.} =
  result.`type` = kind

proc initClearCommand*(color: RLHandle): RLRenderCommand {.inline.} =
  result.`type` = RL_RENDER_CMD_CLEAR
  result.data.clear.color = color

proc initDrawTextCommand*(font: RLHandle, color: RLHandle, x: cfloat, y: cfloat,
                          fontSize: cfloat, spacing: cfloat, text: string): RLRenderCommand {.inline.} =
  result.`type` = RL_RENDER_CMD_DRAW_TEXT
  result.data.draw_text.font = font
  result.data.draw_text.color = color
  result.data.draw_text.x = x
  result.data.draw_text.y = y
  result.data.draw_text.font_size = fontSize
  result.data.draw_text.spacing = spacing
  discard result.data.draw_text.text.setText(text)

proc initDrawSprite3dCommand*(sprite: RLHandle, tint: RLHandle): RLRenderCommand {.inline.} =
  result.`type` = RL_RENDER_CMD_DRAW_SPRITE3D
  result.data.draw_sprite3d.sprite = sprite
  result.data.draw_sprite3d.tint = tint

proc initPlaySoundCommand*(sound: RLHandle, volume: cfloat = 1.0, pitch: cfloat = 1.0,
                           pan: cfloat = 0.5): RLRenderCommand {.inline.} =
  result.`type` = RL_RENDER_CMD_PLAY_SOUND
  result.data.play_sound.sound = sound
  result.data.play_sound.volume = volume
  result.data.play_sound.pitch = pitch
  result.data.play_sound.pan = pan

proc initDrawModelCommand*(model: RLHandle, tint: RLHandle, animationIndex: cint = -1,
                           animationFrame: cint = 0): RLRenderCommand {.inline.} =
  result.`type` = RL_RENDER_CMD_DRAW_MODEL
  result.data.draw_model.model = model
  result.data.draw_model.tint = tint
  result.data.draw_model.animation_index = animationIndex
  result.data.draw_model.animation_frame = animationFrame

proc initDrawTextureCommand*(texture: RLHandle, tint: RLHandle, x: cfloat, y: cfloat,
                             scale: cfloat = 1.0, rotation: cfloat = 0.0): RLRenderCommand {.inline.} =
  result.`type` = RL_RENDER_CMD_DRAW_TEXTURE
  result.data.draw_texture.texture = texture
  result.data.draw_texture.tint = tint
  result.data.draw_texture.x = x
  result.data.draw_texture.y = y
  result.data.draw_texture.scale = scale
  result.data.draw_texture.rotation = rotation

proc initDrawCubeCommand*(color: RLHandle, x: cfloat, y: cfloat, z: cfloat,
                          width: cfloat, height: cfloat, length: cfloat): RLRenderCommand {.inline.} =
  result.`type` = RL_RENDER_CMD_DRAW_CUBE
  result.data.draw_cube.color = color
  result.data.draw_cube.x = x
  result.data.draw_cube.y = y
  result.data.draw_cube.z = z
  result.data.draw_cube.width = width
  result.data.draw_cube.height = height
  result.data.draw_cube.length = length

proc initDrawGroundTextureCommand*(texture: RLHandle, tint: RLHandle, x: cfloat, y: cfloat,
                                   z: cfloat, width: cfloat, length: cfloat): RLRenderCommand {.inline.} =
  result.`type` = RL_RENDER_CMD_DRAW_GROUND_TEXTURE
  result.data.draw_ground_texture.texture = texture
  result.data.draw_ground_texture.tint = tint
  result.data.draw_ground_texture.x = x
  result.data.draw_ground_texture.y = y
  result.data.draw_ground_texture.z = z
  result.data.draw_ground_texture.width = width
  result.data.draw_ground_texture.length = length

proc initSetCamera3dCommand*(camera: RLHandle,
                             positionX: cfloat, positionY: cfloat, positionZ: cfloat,
                             targetX: cfloat, targetY: cfloat, targetZ: cfloat,
                             upX: cfloat, upY: cfloat, upZ: cfloat,
                             fovy: cfloat, projection: cint): RLRenderCommand {.inline.} =
  result.`type` = RL_RENDER_CMD_SET_CAMERA3D
  result.data.set_camera3d.camera = camera
  result.data.set_camera3d.position_x = positionX
  result.data.set_camera3d.position_y = positionY
  result.data.set_camera3d.position_z = positionZ
  result.data.set_camera3d.target_x = targetX
  result.data.set_camera3d.target_y = targetY
  result.data.set_camera3d.target_z = targetZ
  result.data.set_camera3d.up_x = upX
  result.data.set_camera3d.up_y = upY
  result.data.set_camera3d.up_z = upZ
  result.data.set_camera3d.fovy = fovy
  result.data.set_camera3d.projection = projection

proc initSetModelTransformCommand*(model: RLHandle,
                                   positionX: cfloat, positionY: cfloat, positionZ: cfloat,
                                   rotationX: cfloat, rotationY: cfloat, rotationZ: cfloat,
                                   scaleX: cfloat, scaleY: cfloat, scaleZ: cfloat): RLRenderCommand {.inline.} =
  result.`type` = RL_RENDER_CMD_SET_MODEL_TRANSFORM
  result.data.set_model_transform.model = model
  result.data.set_model_transform.position_x = positionX
  result.data.set_model_transform.position_y = positionY
  result.data.set_model_transform.position_z = positionZ
  result.data.set_model_transform.rotation_x = rotationX
  result.data.set_model_transform.rotation_y = rotationY
  result.data.set_model_transform.rotation_z = rotationZ
  result.data.set_model_transform.scale_x = scaleX
  result.data.set_model_transform.scale_y = scaleY
  result.data.set_model_transform.scale_z = scaleZ

proc initSetSprite3dTransformCommand*(sprite: RLHandle,
                                      positionX: cfloat, positionY: cfloat, positionZ: cfloat,
                                      size: cfloat): RLRenderCommand {.inline.} =
  result.`type` = RL_RENDER_CMD_SET_SPRITE3D_TRANSFORM
  result.data.set_sprite3d_transform.sprite = sprite
  result.data.set_sprite3d_transform.position_x = positionX
  result.data.set_sprite3d_transform.position_y = positionY
  result.data.set_sprite3d_transform.position_z = positionZ
  result.data.set_sprite3d_transform.size = size

proc initPlayMusicCommand*(music: RLHandle): RLRenderCommand {.inline.} =
  result.`type` = RL_RENDER_CMD_PLAY_MUSIC
  result.data.play_music.music = music

proc initPauseMusicCommand*(music: RLHandle): RLRenderCommand {.inline.} =
  result.`type` = RL_RENDER_CMD_PAUSE_MUSIC
  result.data.pause_music.music = music

proc initStopMusicCommand*(music: RLHandle): RLRenderCommand {.inline.} =
  result.`type` = RL_RENDER_CMD_STOP_MUSIC
  result.data.stop_music.music = music

proc initSetMusicLoopCommand*(music: RLHandle, shouldLoop: bool): RLRenderCommand {.inline.} =
  result.`type` = RL_RENDER_CMD_SET_MUSIC_LOOP
  result.data.set_music_loop.music = music
  result.data.set_music_loop.loop = shouldLoop

proc initSetMusicVolumeCommand*(music: RLHandle, volume: cfloat): RLRenderCommand {.inline.} =
  result.`type` = RL_RENDER_CMD_SET_MUSIC_VOLUME
  result.data.set_music_volume.music = music
  result.data.set_music_volume.volume = volume

proc reset*(frameCommands: var RLFrameCommandBuffer) {.inline.} =
  frameCommands.count = 0

proc len*(frameCommands: RLFrameCommandBuffer): cint {.inline.} =
  frameCommands.count

proc remaining*(frameCommands: RLFrameCommandBuffer): cint {.inline.} =
  RL_FRAME_COMMAND_CAPACITY - frameCommands.count

proc canAppend*(frameCommands: RLFrameCommandBuffer, n: cint = 1): bool {.inline.} =
  frameCommands.count + n <= RL_FRAME_COMMAND_CAPACITY

proc append*(frameCommands: var RLFrameCommandBuffer, command: RLRenderCommand): bool {.inline.} =
  if not frameCommands.canAppend():
    return false
  frameCommands.commands[frameCommands.count] = command
  inc frameCommands.count
  true
