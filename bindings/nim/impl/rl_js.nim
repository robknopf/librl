## Nim JS backend binding — wraps bindings/js/rl.js.
## Included by rl.nim when defined(js).  Do not import directly.

when defined(js):
  when not declared(rl_async):
    import ../rl_async

  import std/asyncjs
  import std/jsffi

  include ../gen/rl_version

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

  type
    RLLogCallback* = proc(message: string)
    RLLocateFileCallback* = proc(path: string, prefix: string): string

  type RLBootConfig* = object
    bindingsPath*: string
    canvasId*: string
    modulePath*: string
    wasmPath*: string
    idealWidth*: int
    idealHeight*: int
    print*: RLLogCallback
    printErr*: RLLogCallback
    locateFile*: RLLocateFileCallback    

  
  type RLInitConfig* = object
    windowWidth*: int
    windowHeight*: int
    windowTitle*: string
    windowFlags*: RLWindowFlags
    assetHost*: string
    fsRootDir*: string

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
    RL_BOOT_OK* = 0
    RL_BOOT_ERR_UNKNOWN* = -10
    RL_BOOT_ERR_LOADER* = -11
    RL_BOOT_ERR_VERSION_MISMATCH* = -12
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
    RL_ASSET_ADD_TASK_OK* = 0
    RL_ASSET_ADD_TASK_ERR_INVALID* = -1
    RL_ASSET_ADD_TASK_ERR_QUEUE_FULL* = -2
    RL_HANDLE_KIND_NONE* = 0
    RL_HANDLE_KIND_COLOR* = 1
    RL_HANDLE_KIND_CAMERA3D* = 2
    RL_HANDLE_KIND_FONT* = 3
    RL_HANDLE_KIND_TEXTURE* = 4
    RL_HANDLE_KIND_SPRITE2D* = 5
    RL_HANDLE_KIND_SPRITE3D* = 6
    RL_HANDLE_KIND_MODEL* = 7
    RL_HANDLE_KIND_MODEL_ASSET* = 8
    RL_HANDLE_KIND_SOUND* = 9
    RL_HANDLE_KIND_MUSIC* = 10
    RL_HANDLE_KIND_TEXT2D* = 11
    RL_HANDLE_KIND_ASSET_TASK* = 12

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

  template rlJsEmitEnsureBindings(): untyped =
    {.emit: """
var __gRlBindingsPromise = null;
async function __rlEnsureBindings(bindingsPath) {
  if (__gRl != null) return 0;
  if (__gRlBindingsPromise) return await __gRlBindingsPromise;
  __gRlBindingsPromise = (async function() {
    var url = (bindingsPath && bindingsPath.length > 0)
      ? bindingsPath
      : new URL('bindings/js/dist/rl.js', document.baseURI).href;
""".}
    # Do not cache-bust rl.js here — hot reload targets the Nim script bundle
    # (see runtime_host.js / example_runner.js ?t= on the script URL).
    # Busting rl.js creates a second wasm instance and breaks scriptable hosts.
    {.emit: """
    var lib = await import(/* @vite-ignore */ url);
    __gRl = lib.rl || lib.default;
    if (!__gRl) return -1;
    return 0;
  })();
  var rc = await __gRlBindingsPromise;
  if (rc !== 0) __gRlBindingsPromise = null;
  return rc;
}
""".}

  rlJsEmitEnsureBindings()

  template rlJsEmitPatchColors(): untyped =
    {.emit: """
  if (__gRl && __gRl.color) {
    `RL_COLOR_DEFAULT` = __gRl.color.DEFAULT >>> 0;
    `RL_COLOR_LIGHTGRAY` = __gRl.color.LIGHTGRAY >>> 0;
    `RL_COLOR_GRAY` = __gRl.color.GRAY >>> 0;
    `RL_COLOR_DARKGRAY` = __gRl.color.DARKGRAY >>> 0;
    `RL_COLOR_YELLOW` = __gRl.color.YELLOW >>> 0;
    `RL_COLOR_GOLD` = __gRl.color.GOLD >>> 0;
    `RL_COLOR_ORANGE` = __gRl.color.ORANGE >>> 0;
    `RL_COLOR_PINK` = __gRl.color.PINK >>> 0;
    `RL_COLOR_RED` = __gRl.color.RED >>> 0;
    `RL_COLOR_MAROON` = __gRl.color.MAROON >>> 0;
    `RL_COLOR_GREEN` = __gRl.color.GREEN >>> 0;
    `RL_COLOR_LIME` = __gRl.color.LIME >>> 0;
    `RL_COLOR_DARKGREEN` = __gRl.color.DARKGREEN >>> 0;
    `RL_COLOR_SKYBLUE` = __gRl.color.SKYBLUE >>> 0;
    `RL_COLOR_BLUE` = __gRl.color.BLUE >>> 0;
    `RL_COLOR_DARKBLUE` = __gRl.color.DARKBLUE >>> 0;
    `RL_COLOR_PURPLE` = __gRl.color.PURPLE >>> 0;
    `RL_COLOR_VIOLET` = __gRl.color.VIOLET >>> 0;
    `RL_COLOR_DARKPURPLE` = __gRl.color.DARKPURPLE >>> 0;
    `RL_COLOR_BEIGE` = __gRl.color.BEIGE >>> 0;
    `RL_COLOR_BROWN` = __gRl.color.BROWN >>> 0;
    `RL_COLOR_DARKBROWN` = __gRl.color.DARKBROWN >>> 0;
    `RL_COLOR_WHITE` = __gRl.color.WHITE >>> 0;
    `RL_COLOR_BLACK` = __gRl.color.BLACK >>> 0;
    `RL_COLOR_BLANK` = __gRl.color.BLANK >>> 0;
    `RL_COLOR_MAGENTA` = __gRl.color.MAGENTA >>> 0;
    `RL_COLOR_RAYWHITE` = __gRl.color.RAYWHITE >>> 0;
  }
""".}

  # ---------------------------------------------------------------------------
  # Boot / init / deinit  (async)
  # ---------------------------------------------------------------------------

  proc rl_boot_js_load*(config = RLBootConfig()): Future[int] =
    ## Load bindings/js/rl.js, call rl.boot(), patch color constants.
    let bindingsPath = config.bindingsPath.cstring
    let canvasId = config.canvasId.cstring
    let modulePath = config.modulePath.cstring
    let wasmPath = config.wasmPath.cstring
    let idealWidth = config.idealWidth
    let idealHeight = config.idealHeight
    let printFn = config.print
    let printErrFn = config.printErr
    let hasLocateFile = not config.locateFile.isNil
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
    {.emit: """return (async function() {
      var bindingsRc = await __rlEnsureBindings(`bindingsPath`);
      if (bindingsRc !== 0) return bindingsRc;
      var rc = await __gRl.boot(__rl_boot_opts);
      if (!rc) {
""".}
    rlJsEmitPatchColors()
    {.emit: """
      }
      return rc | 0;
    })();""".}

  proc rl_boot*(config = RLBootConfig()): Future[int] {.async.} =
    ## Load bindings/js/rl.js and boot wasm. Returns `RL_BOOT_*` codes.
    return await rl_boot_js_load(config)

  proc rl_init_impl(windowWidth, windowHeight: int, windowTitle, assetHost, fsRootDir: cstring,
                    windowFlags: RLWindowFlags): Future[int] =
    {.emit: """return (async function() {
""".}
    rlJsEmitPatchColors()
    {.emit: """
      return await __gRl.init({
        windowWidth: `windowWidth`,
        windowHeight: `windowHeight`,
        windowTitle: `windowTitle`,
        windowFlags: `windowFlags`,
        assetHost: `assetHost`,
        fsRootDir: `fsRootDir`,
      }) | 0;
    })();""".}

  proc rl_init_from_config*(config: RLInitConfig): Future[int] =
    rl_init_impl(config.windowWidth, config.windowHeight, config.windowTitle.cstring,
                 config.assetHost.cstring, config.fsRootDir.cstring, config.windowFlags)

  proc rl_init*(config = RLInitConfig()): int {.rlAsync.} =
    return rlAwait rl_init_from_config(config)

  proc rl_deinit*(): Future[void] =
    {.emit: "return (async function() { await __gRl.deinit(); })();".}

  proc rl_fs_init_impl(baseDir: cstring): Future[int] =
    {.emit: "return (async function() { return await __gRl.fs.init(`baseDir`) | 0; })();".}

  proc rl_fs_init*(baseDir: string = ""): Future[int] =
    rl_fs_init_impl(baseDir.cstring)

  proc rl_fs_deinit*(): Future[void] =
    {.emit: "return (async function() { await __gRl.fs.deinit(); })();".}

  # ---------------------------------------------------------------------------
  # Synchronous API
  # ---------------------------------------------------------------------------

  proc rl_tick*(): int =
    {.emit: "return __gRl.tick();".}
  proc rl_set_target_fps*(fps: int) {.importjs: "__gRl.setTargetFPS(#)".}
  proc rl_get_time*(): float {.importjs: "__gRl.getTime()".}
  proc rl_get_delta_time*(): float {.importjs: "__gRl.getDeltaTime()".}
  proc rl_is_initialized*(): bool {.importjs: "__gRl.isInitialized()".}
  proc rl_get_platform*(): cstring {.importjs: "__gRl.getPlatform()".}
  proc rl_handle_get_kind*(handle: RLHandle): int {.importjs: "__gRl.handleKind(#)".}
  proc rl_version_major*(): int {.importjs: "__gRl.getVersionMajor()".}
  proc rl_version_minor*(): int {.importjs: "__gRl.getVersionMinor()".}
  proc rl_version_patch*(): int {.importjs: "__gRl.getVersionPatch()".}
  proc rl_version_label*(): string {.importjs: "__gRl.getVersionLabel()".}
  proc rl_version_number*(): uint32 {.importjs: "__gRl.getVersionNumber()".}
  proc rl_version_string*(): string {.importjs: "__gRl.getVersionString()".}
  # Intentionally not exposed: scratch/SAB bridge is JS/wasm-only (see docs/BINDINGS.md).
  # Haxe/Nim JS callers use rl_tick() → bindings/js/rl.js tick(), which refreshes scratch internally.
  # proc rl_scratch_refresh*() {.importjs: "__gRl.refreshScratch()".}
  proc rl_asset_set_host_impl(assetHost: cstring): int {.importjs: "__gRl.asset.setHost(#)".}
  proc rl_asset_set_host*(assetHost: string): int {.inline.} = rl_asset_set_host_impl(assetHost.cstring)
  proc rl_asset_get_host*(): cstring {.importjs: "__gRl.asset.getHost()".}

  # Window
  proc rl_window_close_requested*(): bool {.importjs: "__gRl.window.isCloseRequested()".}
  proc rl_window_set_title_impl(title: cstring) {.importjs: "__gRl.window.setTitle(#)".}
  proc rl_window_set_title*(title: string) {.inline.} = rl_window_set_title_impl(title.cstring)
  proc rl_window_set_size*(width, height: int) {.importjs: "__gRl.window.setSize(#, #)".}
  proc rl_window_get_screen_size*(): Vec2 {.importjs: "__gRl.window.getScreenSize()".}
  proc rl_window_get_position*(): Vec2 {.importjs: "__gRl.window.getPosition()".}
  proc rl_window_get_monitor_count*(): int {.importjs: "__gRl.window.getMonitorCount()".}
  proc rl_window_get_current_monitor*(): int {.importjs: "__gRl.window.getCurrentMonitor()".}
  proc rl_window_set_monitor*(monitor: int) {.importjs: "__gRl.window.setMonitor(#)".}
  proc rl_window_get_monitor_width*(monitor: int): int {.importjs: "__gRl.window.getMonitorWidth(#)".}
  proc rl_window_get_monitor_height*(monitor: int): int {.importjs: "__gRl.window.getMonitorHeight(#)".}
  proc rl_window_set_position*(x, y: int) {.importjs: "__gRl.window.setPosition(#, #)".}

  # Render
  proc rl_render_begin*() {.importjs: "__gRl.render.begin()".}
  proc rl_render_end*() {.importjs: "__gRl.render.end()".}
  proc rl_render_begin_mode_2d*(camera: RLHandle) {.importjs: "__gRl.render.beginMode2D(#)".}
  proc rl_render_end_mode_2d*() {.importjs: "__gRl.render.endMode2D()".}
  proc rl_render_begin_mode_3d*() {.importjs: "__gRl.render.beginMode3D()".}
  proc rl_render_end_mode_3d*() {.importjs: "__gRl.render.endMode3D()".}
  proc rl_render_clear_background*(color: RLHandle) {.importjs: "__gRl.render.clearBackground(#)".}

  # Input
  proc rl_input_poll_events*() {.importjs: "__gRl.input.pollEvents()".}
  proc rl_input_get_mouse_position*(): Vec2 {.importjs: "__gRl.input.getMousePosition()".}
  proc rl_input_get_mouse_wheel*(): int {.importjs: "__gRl.input.getMouseWheel()".}
  proc rl_input_get_mouse_button*(button: int): int {.importjs: "__gRl.input.getMouseButton(#)".}
  proc rl_input_get_mouse_state*(): RLMouseState {.importjs: "__gRl.input.getMouseState()".}
  proc rl_input_get_keyboard_state*(): RLKeyboardState {.importjs: "__gRl.input.getKeyboardState()".}

  # Camera3D
  proc rl_camera3d_create*(positionX, positionY, positionZ,
                          targetX, targetY, targetZ,
                          upX, upY, upZ, fovy: float, projection: int): RLHandle {.
    importjs: "__gRl.camera3d.create(#,#,#,#,#,#,#,#,#,#,#)".}
  proc rl_camera3d_get_default*(): RLHandle {.importjs: "__gRl.camera3d.getDefault()".}
  proc rl_camera3d_set*(camera: RLHandle,
                        positionX, positionY, positionZ,
                        targetX, targetY, targetZ,
                        upX, upY, upZ, fovy: float, projection: int): bool {.
    importjs: "__gRl.camera3d.set(#,#,#,#,#,#,#,#,#,#,#,#)".}
  proc rl_camera3d_set_active*(camera: RLHandle): bool {.importjs: "__gRl.camera3d.setActive(#)".}
  proc rl_camera3d_get_active*(): RLHandle {.importjs: "__gRl.camera3d.getActive()".}
  proc rl_camera3d_destroy*(camera: RLHandle) {.importjs: "__gRl.camera3d.destroy(#)".}

  # Lighting
  proc rl_enable_lighting*() {.importjs: "__gRl.render.enableLighting()".}
  proc rl_disable_lighting*() {.importjs: "__gRl.render.disableLighting()".}
  proc rl_is_lighting_enabled*(): int {.importjs: "__gRl.render.isLightingEnabled()".}
  proc rl_set_light_direction*(x, y, z: float) {.importjs: "__gRl.render.setLightDirection(#,#,#)".}
  proc rl_set_light_ambient*(ambient: float) {.importjs: "__gRl.render.setLightAmbient(#)".}

  # Drawing
  proc rl_shape_draw_cube*(positionX, positionY, positionZ,
                          width, height, length: float,
                          color: RLHandle) {.importjs: "__gRl.shape.drawCube(#,#,#,#,#,#,#)".}
  proc rl_shape_draw_rectangle*(x, y, width, height: int, color: RLHandle) {.
    importjs: "__gRl.shape.drawRectangle(#,#,#,#,#)".}
  proc rl_text_draw_fps*(x, y: int) {.importjs: "__gRl.text.drawFps(#,#)".}
  proc rl_text_draw_fps_ex*(font: RLHandle, x, y: int, fontSize: float, color: RLHandle) {.
    importjs: "__gRl.text.drawFpsEx(#,#,#,#,#)".}
  proc rl_text_draw_impl(text: cstring, x, y, fontSize: int, color: RLHandle) {.
    importjs: "__gRl.text.draw(#,#,#,#,#)".}
  proc rl_text_draw*(text: string, x, y, fontSize: int, color: RLHandle) {.inline.} =
    rl_text_draw_impl(text.cstring, x, y, fontSize, color)
  proc rl_text_draw_ex_impl(font: RLHandle, text: cstring, x, y: int,
                            fontSize, spacing: float, color: RLHandle) {.
    importjs: "__gRl.text.drawEx(#,#,#,#,#,#,#)".}
  proc rl_text_draw_ex*(font: RLHandle, text: string, x, y: int,
                        fontSize, spacing: float, color: RLHandle) {.inline.} =
    rl_text_draw_ex_impl(font, text.cstring, x, y, fontSize, spacing, color)
  proc rl_text_measure_impl(text: cstring, fontSize: int): int {.importjs: "__gRl.text.measure(#,#)".}
  proc rl_text_measure*(text: string, fontSize: int): int {.inline.} =
    rl_text_measure_impl(text.cstring, fontSize)
  proc rl_text_measure_ex_impl(font: RLHandle, text: cstring, fontSize, spacing: float): Vec2 {.
    importjs: "__gRl.text.measureEx(#,#,#,#)".}
  proc rl_text_measure_ex*(font: RLHandle, text: string, fontSize, spacing: float): Vec2 {.inline.} =
    rl_text_measure_ex_impl(font, text.cstring, fontSize, spacing)

  # Color
  proc rl_color_create*(r, g, b, a: int): RLHandle {.importjs: "__gRl.color.create(#,#,#,#)".}
  proc rl_color_destroy*(color: RLHandle) {.importjs: "__gRl.color.destroy(#)".}

  # Font
  proc rl_font_create*(filename: cstring, fontSize: int): RLHandle {.importjs: "__gRl.font.create(#,#)".}
  proc rl_font_create*(filename: string, fontSize: int): RLHandle {.inline.} =
    rl_font_create(filename.cstring, fontSize)
  proc rl_font_destroy*(font: RLHandle) {.importjs: "__gRl.font.destroy(#)".}
  proc rl_font_get_default*(): RLHandle {.importjs: "__gRl.font.getDefault()".}

  # Texture
  proc rl_texture_create*(filename: cstring): RLHandle {.importjs: "__gRl.texture.create(#)".}
  proc rl_texture_create*(filename: string): RLHandle {.inline.} = rl_texture_create(filename.cstring)
  proc rl_texture_destroy*(texture: RLHandle) {.importjs: "__gRl.texture.destroy(#)".}
  proc rl_texture_get_default*(): RLHandle {.importjs: "__gRl.texture.getDefault()".}
  proc rl_texture_draw_ex*(texture: RLHandle, x, y, scale, rotation: float, tint: RLHandle) {.
    importjs: "__gRl.texture.drawEx(#,#,#,#,#,#)".}
  proc rl_texture_draw_ground*(texture: RLHandle, x, y, z, width, length: float, tint: RLHandle) {.
    importjs: "__gRl.texture.drawGround(#,#,#,#,#,#,#)".}

  # Model
  proc rl_model_get_default_asset*(): RLHandle {.importjs: "__gRl.model.getDefaultAsset()".}
  proc rl_model_load_asset*(filename: cstring): RLHandle {.importjs: "__gRl.model.loadAsset(#)".}
  proc rl_model_load_asset*(filename: string): RLHandle {.inline.} = rl_model_load_asset(filename.cstring)
  proc rl_model_destroy_asset*(asset: RLHandle) {.importjs: "__gRl.model.destroyAsset(#)".}
  proc rl_model_create*(asset: RLHandle): RLHandle {.importjs: "__gRl.model.create(#)".}
  proc rl_model_create_from_file*(filename: cstring): RLHandle {.importjs: "__gRl.model.createFromFile(#)".}
  proc rl_model_create_from_file*(filename: string): RLHandle {.inline.} = rl_model_create_from_file(filename.cstring)
  proc rl_model_set_asset*(model: RLHandle, asset: RLHandle): bool {.importjs: "__gRl.model.setAsset(#,#)".}
  proc rl_model_destroy*(model: RLHandle) {.importjs: "__gRl.model.destroy(#)".}
  proc rl_model_draw*(model: RLHandle, tint: RLHandle = 0) {.importjs: "__gRl.model.draw(#,#)".}
  proc rl_model_is_valid*(model: RLHandle): bool {.importjs: "__gRl.model.isValid(#)".}
  proc rl_model_is_valid_strict*(model: RLHandle): bool {.importjs: "__gRl.model.isValidStrict(#)".}
  proc rl_model_set_transform*(model: RLHandle,
                                positionX, positionY, positionZ,
                                rotationX, rotationY, rotationZ,
                                scaleX, scaleY, scaleZ: float): bool {.
    importjs: "__gRl.model.setTransform(#,#,#,#,#,#,#,#,#,#)".}
  proc rl_model_get_animation_count*(model: RLHandle): int {.importjs: "__gRl.model.getAnimationCount(#)".}
  proc rl_model_get_animation_frame_count*(model: RLHandle, animationIndex: int): int {.
    importjs: "__gRl.model.getAnimationFrameCount(#,#)".}
  proc rl_model_update_animation*(model: RLHandle, animationIndex, frame: int) {.
    importjs: "__gRl.model.updateAnimation(#,#,#)".}
  proc rl_model_set_animation*(model: RLHandle, animationIndex: int): bool {.
    importjs: "__gRl.model.setAnimation(#,#)".}
  proc rl_model_set_animation_speed*(model: RLHandle, speed: float): bool {.
    importjs: "__gRl.model.setAnimationSpeed(#,#)".}
  proc rl_model_set_animation_loop*(model: RLHandle, shouldLoop: bool): bool {.
    importjs: "__gRl.model.setAnimationLoop(#,#)".}
  proc rl_model_set_tint*(model: RLHandle, color: RLHandle = 0): bool {.
    importjs: "__gRl.model.setTint(#,#)".}
  proc rl_model_animate*(model: RLHandle, deltaSeconds: float): bool {.
    importjs: "__gRl.model.animate(#,#)".}
  proc rl_pick_model*(camera, model: RLHandle, mouseX, mouseY: float): RLPickResult {.
    importjs: "__gRl.pick.model(#,#,#,#)".}

  # Sprite3D
  proc rl_sprite3d_create*(texture: RLHandle): RLHandle {.importjs: "__gRl.sprite3d.create(#)".}
  proc rl_sprite3d_create_from_file*(filename: cstring): RLHandle {.importjs: "__gRl.sprite3d.createFromFile(#)".}
  proc rl_sprite3d_create_from_file*(filename: string): RLHandle {.inline.} = rl_sprite3d_create_from_file(filename.cstring)
  proc rl_sprite3d_set_texture*(sprite: RLHandle, texture: RLHandle): bool {.
    importjs: "__gRl.sprite3d.setTexture(#,#)".}
  proc rl_sprite3d_set_transform*(sprite: RLHandle,
                                positionX, positionY, positionZ, size: float): bool {.
    importjs: "__gRl.sprite3d.setTransform(#,#,#,#,#)".}
  proc rl_sprite3d_set_tint*(sprite: RLHandle, color: RLHandle = 0): bool {.importjs: "__gRl.sprite3d.setTint(#,#)".}
  proc rl_sprite3d_draw*(sprite: RLHandle, tint: RLHandle = 0) {.importjs: "__gRl.sprite3d.draw(#,#)".}
  proc rl_sprite3d_destroy*(sprite: RLHandle) {.importjs: "__gRl.sprite3d.destroy(#)".}
  proc rl_pick_sprite3d*(camera, sprite3d: RLHandle, mouseX, mouseY: float): RLPickResult {.
    importjs: "__gRl.pick.sprite3d(#,#,#,#)".}

  # Sprite2D
  proc rl_sprite2d_create*(texture: RLHandle): RLHandle {.importjs: "__gRl.sprite2d.create(#)".}
  proc rl_sprite2d_create_from_file*(filename: cstring): RLHandle {.importjs: "__gRl.sprite2d.createFromFile(#)".}
  proc rl_sprite2d_create_from_file*(filename: string): RLHandle {.inline.} = rl_sprite2d_create_from_file(filename.cstring)
  proc rl_sprite2d_set_texture*(sprite: RLHandle, texture: RLHandle): bool {.
    importjs: "__gRl.sprite2d.setTexture(#,#)".}
  proc rl_sprite2d_set_transform*(sprite: RLHandle, x, y, scale, rotation: float): bool {.
    importjs: "__gRl.sprite2d.setTransform(#,#,#,#,#)".}
  proc rl_sprite2d_set_tint*(sprite: RLHandle, color: RLHandle = 0): bool {.importjs: "__gRl.sprite2d.setTint(#,#)".}
  proc rl_sprite2d_draw*(sprite: RLHandle, tint: RLHandle = 0) {.importjs: "__gRl.sprite2d.draw(#,#)".}
  proc rl_sprite2d_destroy*(sprite: RLHandle) {.importjs: "__gRl.sprite2d.destroy(#)".}

  # Text2D
  proc rl_text2d_create*(font: RLHandle, size: float): RLHandle {.importjs: "__gRl.text2d.create(#,#)".}
  proc rl_text2d_set_font*(handle: RLHandle, font: RLHandle) {.importjs: "__gRl.text2d.setFont(#,#)".}
  proc rl_text2d_set_size*(handle: RLHandle, size: float) {.importjs: "__gRl.text2d.setSize(#,#)".}
  proc rl_text2d_set_content_impl(handle: RLHandle, content: cstring) {.importjs: "__gRl.text2d.setContent(#,#)".}
  proc rl_text2d_set_content*(handle: RLHandle, content: string) {.inline.} = rl_text2d_set_content_impl(handle, content.cstring)
  proc rl_text2d_set_position*(handle: RLHandle, x: float, y: float) {.importjs: "__gRl.text2d.setPosition(#,#,#)".}
  proc rl_text2d_set_color*(handle: RLHandle, color: RLHandle) {.importjs: "__gRl.text2d.setColor(#,#)".}
  proc rl_text2d_draw*(handle: RLHandle) {.importjs: "__gRl.text2d.draw(#)".}
  proc rl_text2d_destroy*(handle: RLHandle) {.importjs: "__gRl.text2d.destroy(#)".}

  # Music
  proc rl_music_create*(filename: cstring): RLHandle {.importjs: "__gRl.music.create(#)".}
  proc rl_music_create*(filename: string): RLHandle {.inline.} = rl_music_create(filename.cstring)
  proc rl_music_destroy*(music: RLHandle) {.importjs: "__gRl.music.destroy(#)".}
  proc rl_music_play*(music: RLHandle): bool {.importjs: "__gRl.music.play(#)".}
  proc rl_music_pause*(music: RLHandle): bool {.importjs: "__gRl.music.pause(#)".}
  proc rl_music_stop*(music: RLHandle): bool {.importjs: "__gRl.music.stop(#)".}
  proc rl_music_set_loop*(music: RLHandle, shouldLoop: bool): bool {.importjs: "__gRl.music.setLoop(#,#)".}
  proc rl_music_set_volume*(music: RLHandle, volume: float): bool {.importjs: "__gRl.music.setVolume(#,#)".}
  proc rl_music_is_playing*(music: RLHandle): bool {.importjs: "__gRl.music.isPlaying(#)".}
  proc rl_music_update*(music: RLHandle): bool {.importjs: "__gRl.music.update(#)".}
  proc rl_music_update_all*() {.importjs: "__gRl.music.updateAll()".}

  # Sound
  proc rl_sound_create*(filename: cstring): RLHandle {.importjs: "__gRl.sound.create(#)".}
  proc rl_sound_create*(filename: string): RLHandle {.inline.} = rl_sound_create(filename.cstring)
  proc rl_sound_destroy*(sound: RLHandle) {.importjs: "__gRl.sound.destroy(#)".}
  proc rl_sound_play*(sound: RLHandle): bool {.importjs: "__gRl.sound.play(#)".}
  proc rl_sound_pause*(sound: RLHandle): bool {.importjs: "__gRl.sound.pause(#)".}
  proc rl_sound_resume*(sound: RLHandle): bool {.importjs: "__gRl.sound.resume(#)".}
  proc rl_sound_stop*(sound: RLHandle): bool {.importjs: "__gRl.sound.stop(#)".}
  proc rl_sound_set_volume*(sound: RLHandle, volume: float): bool {.importjs: "__gRl.sound.setVolume(#,#)".}
  proc rl_sound_set_pitch*(sound: RLHandle, pitch: float): bool {.importjs: "__gRl.sound.setPitch(#,#)".}
  proc rl_sound_set_pan*(sound: RLHandle, pan: float): bool {.importjs: "__gRl.sound.setPan(#,#)".}
  proc rl_sound_is_playing*(sound: RLHandle): bool {.importjs: "__gRl.sound.isPlaying(#)".}

  # Fileio
  proc rl_fs_is_initialized*(): bool {.importjs: "__gRl.fs.isInitialized()".}
  proc rl_fs_is_ready*(): bool {.importjs: "__gRl.fs.isReady()".}
  proc rl_fs_flush*(): int {.importjs: "__gRl.fs.flush()".}
  proc rl_fs_get_root_dir*(): cstring {.importjs: "__gRl.fs.getRootDir()".}
  proc rl_fs_exists*(filename: cstring): bool {.importjs: "__gRl.fs.exists(#)".}
  proc rl_fs_exists*(filename: string): bool {.inline.} =
    rl_fs_exists(filename.cstring)
  proc rl_fs_remove*(filename: cstring): int {.importjs: "__gRl.fs.remove(#)".}
  proc rl_fs_remove*(filename: string): int {.inline.} =
    rl_fs_remove(filename.cstring)
  proc rl_fs_clear*(): int {.importjs: "__gRl.fs.clear()".}
  proc rl_fs_restore_async*(): RLHandle {.importjs: "__gRl.fs.restoreAsync()".}
  proc rl_asset_ensure*(localPath: string, src: string = ""): Future[int] =
    let localPathCstr = localPath.cstring
    let srcCstr = if src.len == 0: cstring(nil) else: src.cstring
    {.emit: "return (async function() { return await __gRl.asset.ensure(`localPathCstr`, `srcCstr`) | 0; })();".}
  proc rl_asset_ensure_async*(localPath: cstring, src: cstring): RLHandle {.importjs: "__gRl.asset.ensureAsync(#,#)".}
  proc rl_asset_ensure_async*(localPath: string, src: string = ""): RLHandle {.inline.} =
    let srcPtr = if src.len == 0: cstring(nil) else: src.cstring
    rl_asset_ensure_async(localPath.cstring, srcPtr)
  proc rl_asset_poll_task*(task: RLHandle): bool {.importjs: "__gRl.asset.pollTask(#)".}
  proc rl_asset_finish_task*(task: RLHandle): int {.importjs: "__gRl.asset.finishTask(#)".}
  proc rl_asset_get_task_path*(task: RLHandle): cstring {.importjs: "__gRl.asset.getTaskPath(#)".}
  proc rl_asset_free_task*(task: RLHandle) {.importjs: "__gRl.asset.freeTask(#)".}
  proc rl_asset_tick*() {.importjs: "__gRl.asset.tick()".}
  proc rl_asset_ping_host*(assetHost: cstring): float {.importjs: "__gRl.asset.pingHost(#)".}
  proc rl_asset_ping_host*(assetHost: string = ""): float {.inline.} =
    let hostPtr = if assetHost.len == 0: cstring(nil) else: assetHost.cstring
    rl_asset_ping_host(hostPtr)

  # Logger
  # rl_log.nim calls these with a printf-style format string + message arg;
  # the JS binding takes (level, message) directly, so we emit raw JS to skip the format param.
  proc rl_logger_set_level*(level: int) {.importjs: "__gRl.logger.setLevel(#)".}
  proc rl_logger_message*(level: int, format: cstring, message: cstring) =
    {.emit: "__gRl.logger.message(`level`, `message`);".}
  proc rl_logger_message_source*(level: int, sourceFile: cstring, sourceLine: int,
                                format: cstring, message: cstring) =
    {.emit: "__gRl.logger.message(`level`, `message`);".}

  # Events
  proc rl_event_emit*(eventName: cstring, payload: int): int {.importjs: "__gRl.event.emit(#,#)".}

  # ---------------------------------------------------------------------------
  # Task group (mirrors the native RLTaskGroup API using JS primitives)
  # ---------------------------------------------------------------------------

  type
    RLFileioClosureCallback* = proc(path: string) {.closure.}
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

  proc assetCreateTaskGroup*[T](
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
      task: task, path: $rl_asset_get_task_path(task),
      done: false, rc: 1, onSuccess: onSuccess, onError: onError))

  proc addImportTask*[T](group: RLTaskGroup[T], path: string,
                        onSuccess: RLTaskGroupTaskCallback[T] = nil,
                        onError: RLTaskGroupTaskCallback[T] = nil) =
    if group.isNil: return
    group.addTask(rl_asset_ensure_async(path), onSuccess, onError)

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
    rl_asset_tick()
    for idx in 0 ..< group.entries.len:
      if group.entries[idx].done: continue
      if not rl_asset_poll_task(group.entries[idx].task): continue
      group.entries[idx].rc = rl_asset_finish_task(group.entries[idx].task)
      rl_asset_free_task(group.entries[idx].task)
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

