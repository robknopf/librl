## Nim JS backend binding — wraps bindings/js/rl.js.
## Included by rl.nim when defined(js).  Do not import directly.

import std/asyncjs
import std/jsffi

# Module-level handle to the loaded rl.js binding object.
# Set by rl_boot(); all other procs assume it is non-null.
{.emit: "var __gRl = null;".}

# ---------------------------------------------------------------------------
# Types (plain objects — no C header pragmas on the JS backend)
# ---------------------------------------------------------------------------

type
  RLHandle* = uint32
  RLWindowFlags* = uint32

  Vec2* = object
    x*, y*: float32

  Vec3* = object
    x*, y*, z*: float32

  RLPickResult* = object
    hit*: bool
    distance*: float32
    point*: Vec3
    normal*: Vec3

  RLMouseState* = object
    x*, y*, wheel*: cint
    left*, right*, middle*: cint

  RLKeyboardState* = object
    max_num_keys*: cint
    keys*: JsObject        # HEAP32 TypedArray subarray
    pressed_key*: cint
    pressed_char*: cint
    num_pressed_keys*: cint
    pressed_keys*: JsObject
    num_pressed_chars*: cint
    pressed_chars*: JsObject

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

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
  RL_MODULE_LOG_TRACE* = 0
  RL_MODULE_LOG_DEBUG* = 1
  RL_MODULE_LOG_INFO* = 2
  RL_MODULE_LOG_WARN* = 3
  RL_MODULE_LOG_ERROR* = 4
  RL_LOGGER_LEVEL_TRACE* = 0
  RL_LOGGER_LEVEL_DEBUG* = 1
  RL_LOGGER_LEVEL_INFO* = 2
  RL_LOGGER_LEVEL_WARN* = 3
  RL_LOGGER_LEVEL_ERROR* = 4
  RL_LOGGER_LEVEL_FATAL* = 5
  RL_LOADER_QUEUE_TASK_OK* = 0
  RL_LOADER_QUEUE_TASK_ERR_INVALID* = -1
  RL_LOADER_QUEUE_TASK_ERR_QUEUE_FULL* = -2

# Color handles — zero until rl_boot() succeeds (rl.js patches them after boot)
var
  RL_COLOR_DEFAULT* = 0.RLHandle
  RL_COLOR_LIGHTGRAY* = 0.RLHandle
  RL_COLOR_GRAY* = 0.RLHandle
  RL_COLOR_DARKGRAY* = 0.RLHandle
  RL_COLOR_YELLOW* = 0.RLHandle
  RL_COLOR_GOLD* = 0.RLHandle
  RL_COLOR_ORANGE* = 0.RLHandle
  RL_COLOR_PINK* = 0.RLHandle
  RL_COLOR_RED* = 0.RLHandle
  RL_COLOR_MAROON* = 0.RLHandle
  RL_COLOR_GREEN* = 0.RLHandle
  RL_COLOR_LIME* = 0.RLHandle
  RL_COLOR_DARKGREEN* = 0.RLHandle
  RL_COLOR_SKYBLUE* = 0.RLHandle
  RL_COLOR_BLUE* = 0.RLHandle
  RL_COLOR_DARKBLUE* = 0.RLHandle
  RL_COLOR_PURPLE* = 0.RLHandle
  RL_COLOR_VIOLET* = 0.RLHandle
  RL_COLOR_DARKPURPLE* = 0.RLHandle
  RL_COLOR_BEIGE* = 0.RLHandle
  RL_COLOR_BROWN* = 0.RLHandle
  RL_COLOR_DARKBROWN* = 0.RLHandle
  RL_COLOR_WHITE* = 0.RLHandle
  RL_COLOR_BLACK* = 0.RLHandle
  RL_COLOR_BLANK* = 0.RLHandle
  RL_COLOR_MAGENTA* = 0.RLHandle
  RL_COLOR_RAYWHITE* = 0.RLHandle

# ---------------------------------------------------------------------------
# Boot / init / deinit  (async)
# ---------------------------------------------------------------------------

proc rl_boot*(config = RLBootConfig()): Future[int] =
  ## Load bindings/js/rl.js via dynamic import, call rl.boot(), and patch
  ## color constants into Nim global vars.  Must be awaited before any
  ## other rl_ call.
  let bindingsPath = (if config.bindingsPath.len > 0: config.bindingsPath else: "/bindings/js/rl.js").cstring
  let canvasId = config.canvasId.cstring
  let modulePath = config.modulePath.cstring
  let wasmPath = config.wasmPath.cstring
  let idealWidth = config.idealWidth
  let idealHeight = config.idealHeight
  let printFn = config.print
  let printErrFn = config.printErr
  let hasLocateFile = not config.locateFile.isNil
  {.emit: "var __rl_boot_url = `bindingsPath`;".}
  {.emit: """var __rl_boot_opts = { env: {} };
if (`canvasId`.length > 0) __rl_boot_opts.canvasId = `canvasId`;
if (`modulePath`.length > 0) __rl_boot_opts.modulePath = `modulePath`;
if (`wasmPath`.length > 0) __rl_boot_opts.wasmPath = `wasmPath`;
if (`idealWidth` > 0) __rl_boot_opts.idealWidth = `idealWidth`;
if (`idealHeight` > 0) __rl_boot_opts.idealHeight = `idealHeight`;
if (`printFn` !== null) __rl_boot_opts.env.print = `printFn`;
if (`printErrFn` !== null) __rl_boot_opts.env.printErr = `printErrFn`;
if (`hasLocateFile`) console.warn("rl_boot: RLBootConfig.locateFile is not supported on Nim JS yet; ignoring");
if (Object.keys(__rl_boot_opts.env).length === 0) delete __rl_boot_opts.env;""".}
  when defined(debug):
    {.emit: """__rl_boot_url = __rl_boot_url + (__rl_boot_url.indexOf("?") >= 0 ? "&" : "?") + "t=" + Date.now();""".}
  {.emit: """return (async function() {
    var lib = await import(/* @vite-ignore */ __rl_boot_url);
    __gRl = lib.rl || lib.default;
    var rc = await __gRl.boot(__rl_boot_opts);
    if (rc === 0) {
      `RL_COLOR_DEFAULT` = __gRl.COLOR_DEFAULT >>> 0;
      `RL_COLOR_LIGHTGRAY` = __gRl.COLOR_LIGHTGRAY >>> 0;
      `RL_COLOR_GRAY` = __gRl.COLOR_GRAY >>> 0;
      `RL_COLOR_DARKGRAY` = __gRl.COLOR_DARKGRAY >>> 0;
      `RL_COLOR_YELLOW` = __gRl.COLOR_YELLOW >>> 0;
      `RL_COLOR_GOLD` = __gRl.COLOR_GOLD >>> 0;
      `RL_COLOR_ORANGE` = __gRl.COLOR_ORANGE >>> 0;
      `RL_COLOR_PINK` = __gRl.COLOR_PINK >>> 0;
      `RL_COLOR_RED` = __gRl.COLOR_RED >>> 0;
      `RL_COLOR_MAROON` = __gRl.COLOR_MAROON >>> 0;
      `RL_COLOR_GREEN` = __gRl.COLOR_GREEN >>> 0;
      `RL_COLOR_LIME` = __gRl.COLOR_LIME >>> 0;
      `RL_COLOR_DARKGREEN` = __gRl.COLOR_DARKGREEN >>> 0;
      `RL_COLOR_SKYBLUE` = __gRl.COLOR_SKYBLUE >>> 0;
      `RL_COLOR_BLUE` = __gRl.COLOR_BLUE >>> 0;
      `RL_COLOR_DARKBLUE` = __gRl.COLOR_DARKBLUE >>> 0;
      `RL_COLOR_PURPLE` = __gRl.COLOR_PURPLE >>> 0;
      `RL_COLOR_VIOLET` = __gRl.COLOR_VIOLET >>> 0;
      `RL_COLOR_DARKPURPLE` = __gRl.COLOR_DARKPURPLE >>> 0;
      `RL_COLOR_BEIGE` = __gRl.COLOR_BEIGE >>> 0;
      `RL_COLOR_BROWN` = __gRl.COLOR_BROWN >>> 0;
      `RL_COLOR_DARKBROWN` = __gRl.COLOR_DARKBROWN >>> 0;
      `RL_COLOR_WHITE` = __gRl.COLOR_WHITE >>> 0;
      `RL_COLOR_BLACK` = __gRl.COLOR_BLACK >>> 0;
      `RL_COLOR_BLANK` = __gRl.COLOR_BLANK >>> 0;
      `RL_COLOR_MAGENTA` = __gRl.COLOR_MAGENTA >>> 0;
      `RL_COLOR_RAYWHITE` = __gRl.COLOR_RAYWHITE >>> 0;
    }
    return rc | 0;
  })();""".}

proc rl_init_values_impl(windowWidth, windowHeight: int, windowTitle: cstring,
                         windowFlags: RLWindowFlags,
                         assetHost: cstring, loaderCacheDir: cstring): Future[int] =
  {.emit: """return (async function() {
    return await __gRl.initValues(
      `windowWidth`, `windowHeight`, `windowTitle`,
      `windowFlags`, `assetHost`, `loaderCacheDir`
    ) | 0;
  })();""".}

proc rl_init_values*(windowWidth, windowHeight: int, windowTitle: string,
                     windowFlags: RLWindowFlags = 0.RLWindowFlags,
                     assetHost: string = "", loaderCacheDir: string = ""): Future[int] =
  rl_init_values_impl(windowWidth, windowHeight, windowTitle.cstring, windowFlags,
                      assetHost.cstring, loaderCacheDir.cstring)

proc rl_deinit*(): Future[void] =
  {.emit: "return (async function() { await __gRl.deinit(); })();".}

proc rl_loader_init_impl(mountPoint: cstring): Future[int] =
  {.emit: "return (async function() { return await __gRl.loaderInit(`mountPoint`) | 0; })();".}

proc rl_loader_init*(mountPoint: string = ""): Future[int] =
  rl_loader_init_impl(mountPoint.cstring)

proc rl_loader_deinit*(): Future[void] =
  {.emit: "return (async function() { await __gRl.loaderDeinit(); })();".}

# ---------------------------------------------------------------------------
# Synchronous API
# ---------------------------------------------------------------------------

proc rl_tick*(): int {.importjs: "__gRl.tick()".}
proc rl_set_target_fps*(fps: int) {.importjs: "__gRl.setTargetFPS(#)".}
proc rl_get_time*(): float {.importjs: "__gRl.getTime()".}
proc rl_get_delta_time*(): float {.importjs: "__gRl.getDeltaTime()".}
proc rl_is_initialized*(): bool {.importjs: "__gRl.isInitialized()".}
proc rl_get_platform*(): cstring {.importjs: "__gRl.getPlatform()".}
proc rl_scratch_refresh*() {.importjs: "__gRl.refreshScratch()".}
proc rl_set_asset_host_impl(assetHost: cstring): int {.importjs: "__gRl.setAssetHost(#)".}
proc rl_set_asset_host*(assetHost: string): int {.inline.} = rl_set_asset_host_impl(assetHost.cstring)
proc rl_get_asset_host*(): cstring {.importjs: "__gRl.getAssetHost()".}

# Window
proc rl_window_close_requested*(): bool {.importjs: "__gRl.isWindowCloseRequested()".}
proc rl_window_set_title_impl(title: cstring) {.importjs: "__gRl.setWindowTitle(#)".}
proc rl_window_set_title*(title: string) {.inline.} = rl_window_set_title_impl(title.cstring)
proc rl_window_set_size*(width, height: int) {.importjs: "__gRl.setWindowSize(#, #)".}
proc rl_window_get_screen_size*(): Vec2 {.importjs: "__gRl.getScreenSize()".}
proc rl_window_get_position*(): Vec2 {.importjs: "__gRl.getWindowPosition()".}
proc rl_window_get_monitor_count*(): int {.importjs: "__gRl.getMonitorCount()".}
proc rl_window_get_current_monitor*(): int {.importjs: "__gRl.getCurrentMonitor()".}
proc rl_window_set_monitor*(monitor: int) {.importjs: "__gRl.setWindowMonitor(#)".}
proc rl_window_get_monitor_width*(monitor: int): int {.importjs: "__gRl.getMonitorWidth(#)".}
proc rl_window_get_monitor_height*(monitor: int): int {.importjs: "__gRl.getMonitorHeight(#)".}
proc rl_window_set_position*(x, y: int) {.importjs: "__gRl.setWindowPosition(#, #)".}

# Render
proc rl_render_begin*() {.importjs: "__gRl.beginDrawing()".}
proc rl_render_end*() {.importjs: "__gRl.endDrawing()".}
proc rl_render_begin_mode_2d*(camera: RLHandle) {.importjs: "__gRl.beginMode2D(#)".}
proc rl_render_end_mode_2d*() {.importjs: "__gRl.endMode2D()".}
proc rl_render_begin_mode_3d*() {.importjs: "__gRl.beginMode3d()".}
proc rl_render_end_mode_3d*() {.importjs: "__gRl.endMode3d()".}
proc rl_render_clear_background*(color: RLHandle) {.importjs: "__gRl.clearBackground(#)".}

# Input
proc rl_input_poll_events*() {.importjs: "__gRl.pollInputEvents()".}
proc rl_input_get_mouse_position*(): Vec2 {.importjs: "__gRl.getMousePosition()".}
proc rl_input_get_mouse_wheel*(): int {.importjs: "__gRl.getMouseWheel()".}
proc rl_input_get_mouse_button*(button: int): int {.importjs: "__gRl.getMouseButton(#)".}
proc rl_input_get_mouse_state*(): RLMouseState {.importjs: "__gRl.getMouseState()".}
proc rl_input_get_keyboard_state*(): RLKeyboardState {.importjs: "__gRl.getKeyboardState()".}

# Camera3D
proc rl_camera3d_create*(positionX, positionY, positionZ,
                         targetX, targetY, targetZ,
                         upX, upY, upZ, fovy: float, projection: int): RLHandle {.
  importjs: "__gRl.createCamera3d(#,#,#,#,#,#,#,#,#,#,#)".}
proc rl_camera3d_get_default*(): RLHandle {.importjs: "__gRl.getDefaultCamera3d()".}
proc rl_camera3d_set*(camera: RLHandle,
                      positionX, positionY, positionZ,
                      targetX, targetY, targetZ,
                      upX, upY, upZ, fovy: float, projection: int): bool {.
  importjs: "__gRl.setCamera3d(#,#,#,#,#,#,#,#,#,#,#,#)".}
proc rl_camera3d_set_active*(camera: RLHandle): bool {.importjs: "__gRl.setActiveCamera3d(#)".}
proc rl_camera3d_get_active*(): RLHandle {.importjs: "__gRl.getActiveCamera3d()".}
proc rl_camera3d_destroy*(camera: RLHandle) {.importjs: "__gRl.destroyCamera3d(#)".}

# Lighting
proc rl_enable_lighting*() {.importjs: "__gRl.enableLighting()".}
proc rl_disable_lighting*() {.importjs: "__gRl.disableLighting()".}
proc rl_is_lighting_enabled*(): int {.importjs: "__gRl.isLightingEnabled()".}
proc rl_set_light_direction*(x, y, z: float) {.importjs: "__gRl.setLightDirection(#,#,#)".}
proc rl_set_light_ambient*(ambient: float) {.importjs: "__gRl.setLightAmbient(#)".}

# Drawing
proc rl_shape_draw_cube*(positionX, positionY, positionZ,
                         width, height, length: float,
                         color: RLHandle) {.importjs: "__gRl.drawCube(#,#,#,#,#,#,#)".}
proc rl_shape_draw_rectangle*(x, y, width, height: int, color: RLHandle) {.
  importjs: "__gRl.drawRectangle(#,#,#,#,#)".}
proc rl_text_draw_fps*(x, y: int) {.importjs: "__gRl.drawFPS(#,#)".}
proc rl_text_draw_fps_ex*(font: RLHandle, x, y: int, fontSize: float, color: RLHandle) {.
  importjs: "__gRl.drawFPSEx(#,#,#,#,#)".}
proc rl_text_draw_impl(text: cstring, x, y, fontSize: int, color: RLHandle) {.
  importjs: "__gRl.drawText(#,#,#,#,#)".}
proc rl_text_draw*(text: string, x, y, fontSize: int, color: RLHandle) {.inline.} =
  rl_text_draw_impl(text.cstring, x, y, fontSize, color)
proc rl_text_draw_ex_impl(font: RLHandle, text: cstring, x, y: int,
                          fontSize, spacing: float, color: RLHandle) {.
  importjs: "__gRl.drawTextEx(#,#,#,#,#,#,#)".}
proc rl_text_draw_ex*(font: RLHandle, text: string, x, y: int,
                      fontSize, spacing: float, color: RLHandle) {.inline.} =
  rl_text_draw_ex_impl(font, text.cstring, x, y, fontSize, spacing, color)
proc rl_text_measure_impl(text: cstring, fontSize: int): int {.importjs: "__gRl.measureText(#,#)".}
proc rl_text_measure*(text: string, fontSize: int): int {.inline.} =
  rl_text_measure_impl(text.cstring, fontSize)
proc rl_text_measure_ex_impl(font: RLHandle, text: cstring, fontSize, spacing: float): Vec2 {.
  importjs: "__gRl.measureTextEx(#,#,#,#)".}
proc rl_text_measure_ex*(font: RLHandle, text: string, fontSize, spacing: float): Vec2 {.inline.} =
  rl_text_measure_ex_impl(font, text.cstring, fontSize, spacing)

# Color
proc rl_color_create*(r, g, b, a: int): RLHandle {.importjs: "__gRl.createColor(#,#,#,#)".}
proc rl_color_destroy*(color: RLHandle) {.importjs: "__gRl.destroyColor(#)".}

# Font
proc rl_font_create*(filename: cstring, fontSize: int): RLHandle {.importjs: "__gRl.createFont(#,#)".}
proc rl_font_create*(filename: string, fontSize: int): RLHandle {.inline.} =
  rl_font_create(filename.cstring, fontSize)
proc rl_font_destroy*(font: RLHandle) {.importjs: "__gRl.destroyFont(#)".}
proc rl_font_get_default*(): RLHandle {.importjs: "__gRl.rl_font_get_default()".}

# Texture
proc rl_texture_create*(filename: cstring): RLHandle {.importjs: "__gRl.createTexture(#)".}
proc rl_texture_create*(filename: string): RLHandle {.inline.} = rl_texture_create(filename.cstring)
proc rl_texture_destroy*(texture: RLHandle) {.importjs: "__gRl.destroyTexture(#)".}
proc rl_texture_draw_ex*(texture: RLHandle, x, y, scale, rotation: float, tint: RLHandle) {.
  importjs: "__gRl.drawTextureEx(#,#,#,#,#,#)".}
proc rl_texture_draw_ground*(texture: RLHandle, x, y, z, width, length: float, tint: RLHandle) {.
  importjs: "__gRl.drawTextureGround(#,#,#,#,#,#,#)".}

# Model
proc rl_model_create*(filename: cstring): RLHandle {.importjs: "__gRl.createModel(#)".}
proc rl_model_create*(filename: string): RLHandle {.inline.} = rl_model_create(filename.cstring)
proc rl_model_destroy*(model: RLHandle) {.importjs: "__gRl.destroyModel(#)".}
proc rl_model_draw*(model: RLHandle, tint: RLHandle) {.importjs: "__gRl.drawModel(#,#)".}
proc rl_model_is_valid*(model: RLHandle): bool {.importjs: "__gRl.isModelValid(#)".}
proc rl_model_is_valid_strict*(model: RLHandle): bool {.importjs: "__gRl.isModelValidStrict(#)".}
proc rl_model_set_transform*(model: RLHandle,
                              positionX, positionY, positionZ,
                              rotationX, rotationY, rotationZ,
                              scaleX, scaleY, scaleZ: float): bool {.
  importjs: "__gRl.modelSetTransform(#,#,#,#,#,#,#,#,#,#)".}
proc rl_model_animation_count*(model: RLHandle): int {.importjs: "__gRl.modelAnimationCount(#)".}
proc rl_model_animation_frame_count*(model: RLHandle, animationIndex: int): int {.
  importjs: "__gRl.modelAnimationFrameCount(#,#)".}
proc rl_model_animation_update*(model: RLHandle, animationIndex, frame: int) {.
  importjs: "__gRl.modelAnimationUpdate(#,#,#)".}
proc rl_model_set_animation*(model: RLHandle, animationIndex: int): bool {.
  importjs: "__gRl.modelSetAnimation(#,#)".}
proc rl_model_set_animation_speed*(model: RLHandle, speed: float): bool {.
  importjs: "__gRl.modelSetAnimationSpeed(#,#)".}
proc rl_model_set_animation_loop*(model: RLHandle, shouldLoop: bool): bool {.
  importjs: "__gRl.modelSetAnimationLoop(#,#)".}
proc rl_model_animate*(model: RLHandle, deltaSeconds: float): bool {.
  importjs: "__gRl.modelAnimate(#,#)".}

# Sprite3D
proc rl_sprite3d_create*(filename: cstring): RLHandle {.importjs: "__gRl.createSprite3d(#)".}
proc rl_sprite3d_create*(filename: string): RLHandle {.inline.} = rl_sprite3d_create(filename.cstring)
proc rl_sprite3d_create_from_texture*(texture: RLHandle): RLHandle {.
  importjs: "__gRl.createSprite3dFromTexture(#)".}
proc rl_sprite3d_set_transform*(sprite: RLHandle,
                                positionX, positionY, positionZ, size: float): bool {.
  importjs: "__gRl.sprite3dSetTransform(#,#,#,#,#)".}
proc rl_sprite3d_draw*(sprite: RLHandle, tint: RLHandle) {.importjs: "__gRl.drawSprite3d(#,#)".}
proc rl_sprite3d_destroy*(sprite: RLHandle) {.importjs: "__gRl.destroySprite3d(#)".}

# Sprite2D
proc rl_sprite2d_create*(filename: cstring): RLHandle {.importjs: "__gRl.createSprite2D(#)".}
proc rl_sprite2d_create*(filename: string): RLHandle {.inline.} = rl_sprite2d_create(filename.cstring)
proc rl_sprite2d_create_from_texture*(texture: RLHandle): RLHandle {.
  importjs: "__gRl.createSprite2DFromTexture(#)".}
proc rl_sprite2d_set_transform*(sprite: RLHandle, x, y, scale, rotation: float): bool {.
  importjs: "__gRl.sprite2DSetTransform(#,#,#,#,#)".}
proc rl_sprite2d_draw*(sprite: RLHandle, tint: RLHandle) {.importjs: "__gRl.drawSprite2D(#,#)".}
proc rl_sprite2d_destroy*(sprite: RLHandle) {.importjs: "__gRl.destroySprite2D(#)".}

# Music
proc rl_music_create*(filename: cstring): RLHandle {.importjs: "__gRl.createMusic(#)".}
proc rl_music_create*(filename: string): RLHandle {.inline.} = rl_music_create(filename.cstring)
proc rl_music_destroy*(music: RLHandle) {.importjs: "__gRl.destroyMusic(#)".}
proc rl_music_play*(music: RLHandle): bool {.importjs: "__gRl.playMusic(#)".}
proc rl_music_pause*(music: RLHandle): bool {.importjs: "__gRl.pauseMusic(#)".}
proc rl_music_stop*(music: RLHandle): bool {.importjs: "__gRl.stopMusic(#)".}
proc rl_music_set_loop*(music: RLHandle, shouldLoop: bool): bool {.importjs: "__gRl.setMusicLoop(#,#)".}
proc rl_music_set_volume*(music: RLHandle, volume: float): bool {.importjs: "__gRl.setMusicVolume(#,#)".}
proc rl_music_is_playing*(music: RLHandle): bool {.importjs: "__gRl.isMusicPlaying(#)".}
proc rl_music_update*(music: RLHandle): bool {.importjs: "__gRl.updateMusic(#)".}
proc rl_music_update_all*() {.importjs: "__gRl.updateAllMusic()".}

# Sound
proc rl_sound_create*(filename: cstring): RLHandle {.importjs: "__gRl.createSound(#)".}
proc rl_sound_create*(filename: string): RLHandle {.inline.} = rl_sound_create(filename.cstring)
proc rl_sound_destroy*(sound: RLHandle) {.importjs: "__gRl.destroySound(#)".}
proc rl_sound_play*(sound: RLHandle): bool {.importjs: "__gRl.playSound(#)".}
proc rl_sound_pause*(sound: RLHandle): bool {.importjs: "__gRl.pauseSound(#)".}
proc rl_sound_resume*(sound: RLHandle): bool {.importjs: "__gRl.resumeSound(#)".}
proc rl_sound_stop*(sound: RLHandle): bool {.importjs: "__gRl.stopSound(#)".}
proc rl_sound_set_volume*(sound: RLHandle, volume: float): bool {.importjs: "__gRl.setSoundVolume(#,#)".}
proc rl_sound_set_pitch*(sound: RLHandle, pitch: float): bool {.importjs: "__gRl.setSoundPitch(#,#)".}
proc rl_sound_set_pan*(sound: RLHandle, pan: float): bool {.importjs: "__gRl.setSoundPan(#,#)".}
proc rl_sound_is_playing*(sound: RLHandle): bool {.importjs: "__gRl.isSoundPlaying(#)".}

# Loader
proc rl_loader_is_initialized*(): bool {.importjs: "__gRl.loaderIsInitialized()".}
proc rl_loader_get_cache_dir*(): cstring {.importjs: "__gRl.getCacheDir()".}
proc rl_loader_is_asset_cached*(filename: cstring): bool {.importjs: "__gRl.isAssetCached(#)".}
proc rl_loader_is_asset_cached*(filename: string): bool {.inline.} =
  rl_loader_is_asset_cached(filename.cstring)
proc rl_loader_uncache_asset*(filename: cstring): int {.importjs: "__gRl.uncacheAsset(#)".}
proc rl_loader_clear_cache*(): int {.importjs: "__gRl.clearCache()".}
proc rl_loader_create_import_task*(filename: cstring): RLHandle {.importjs: "__gRl.importAssetAsync(#)".}
proc rl_loader_create_import_task*(filename: string): RLHandle {.inline.} =
  rl_loader_create_import_task(filename.cstring)
proc rl_loader_poll_task*(task: RLHandle): bool {.importjs: "__gRl.pollTask(#)".}
proc rl_loader_finish_task*(task: RLHandle): int {.importjs: "__gRl.finishTask(#)".}
proc rl_loader_get_task_path*(task: RLHandle): cstring {.importjs: "__gRl.getTaskPath(#)".}
proc rl_loader_free_task*(task: RLHandle) {.importjs: "__gRl.freeTask(#)".}
proc rl_loader_tick*() {.importjs: "__gRl.loaderTick()".}

# Logger
# rl_log.nim calls these with a printf-style format string + message arg;
# the JS binding takes (level, message) directly, so we emit raw JS to skip the format param.
proc rl_logger_set_level*(level: int) {.importjs: "__gRl.loggerSetLevel(#)".}
proc rl_logger_message*(level: int, format: cstring, message: cstring) =
  {.emit: "__gRl.loggerMessage(`level`, `message`);".}
proc rl_logger_message_source*(level: int, sourceFile: cstring, sourceLine: int,
                               format: cstring, message: cstring) =
  {.emit: "__gRl.loggerMessage(`level`, `message`);".}

# Events
proc rl_event_emit*(eventName: cstring, payload: int): int {.importjs: "__gRl.emitEvent(#,#)".}

# ---------------------------------------------------------------------------
# Task group (mirrors the native RLTaskGroup API using JS primitives)
# ---------------------------------------------------------------------------

type
  RLLoaderClosureCallback* = proc(path: string) {.closure.}
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

proc loaderCreateTaskGroup*[T](
  ctx: ptr T,
  onComplete: RLTaskGroupCallback[T] = nil,
  onError: RLTaskGroupCallback[T] = nil
): RLTaskGroup[T] =
  new(result)
  result.entries = @[]
  result.callbackContext = ctx
  result.onCompleteCallback = onComplete
  result.onErrorCallback = onError

proc addTask*[T](group: RLTaskGroup[T], task: RLHandle,
                 onSuccess: RLTaskGroupTaskCallback[T] = nil,
                 onError: RLTaskGroupTaskCallback[T] = nil) =
  if group.isNil or task == 0: return
  group.entries.add(RLTaskGroupEntry[T](
    task: task, path: $rl_loader_get_task_path(task),
    done: false, rc: 1, onSuccess: onSuccess, onError: onError))

proc addImportTask*[T](group: RLTaskGroup[T], path: string,
                       onSuccess: RLTaskGroupTaskCallback[T] = nil,
                       onError: RLTaskGroupTaskCallback[T] = nil) =
  if group.isNil: return
  group.addTask(rl_loader_create_import_task(path), onSuccess, onError)

proc addImportTasks*[T](group: RLTaskGroup[T], paths: openArray[string]) =
  for path in paths: group.addImportTask(path)

proc remainingTasks*[T](group: RLTaskGroup[T]): int =
  if group.isNil: return 0
  group.entries.len - group.completedCount

proc isDone*[T](group: RLTaskGroup[T]): bool = group.remainingTasks() == 0

proc hasFailures*[T](group: RLTaskGroup[T]): bool =
  if group.isNil: return false
  group.failedCount > 0

proc tick*[T](group: RLTaskGroup[T]): bool =
  if group.isNil: return false
  rl_loader_tick()
  for idx in 0 ..< group.entries.len:
    if group.entries[idx].done: continue
    if not rl_loader_poll_task(group.entries[idx].task): continue
    group.entries[idx].rc = rl_loader_finish_task(group.entries[idx].task)
    rl_loader_free_task(group.entries[idx].task)
    group.entries[idx].done = true
    group.completedCount.inc
    if group.entries[idx].rc != 0:
      group.failedCount.inc
      if group.entries[idx].onError != nil and not group.callbackContext.isNil:
        group.entries[idx].onError(group.entries[idx].path, group.callbackContext[])
    elif group.entries[idx].onSuccess != nil and not group.callbackContext.isNil:
      group.entries[idx].onSuccess(group.entries[idx].path, group.callbackContext[])
  group.remainingTasks() > 0

proc process*[T](group: RLTaskGroup[T]): int =
  if group.isNil: return 0
  discard group.tick()
  if not group.terminalCallbackInvoked and group.remainingTasks() == 0 and
     not group.callbackContext.isNil:
    group.terminalCallbackInvoked = true
    if group.hasFailures():
      if group.onErrorCallback != nil:
        group.onErrorCallback(group, group.callbackContext[])
    elif group.onCompleteCallback != nil:
      group.onCompleteCallback(group, group.callbackContext[])
  group.remainingTasks()

proc failedPaths*[T](group: RLTaskGroup[T]): seq[string] =
  result = @[]
  if group.isNil: return
  for entry in group.entries:
    if entry.done and entry.rc != 0: result.add(entry.path)
