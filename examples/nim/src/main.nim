import rl
import rl_log as log
import std/[os, strutils, strformat]

when defined(emscripten):
  # wasm/browser can use relative path to the host
  const assetHost = "./"
else:
  # desktop needs an actual url for fetch
  const assetHost = "https://localhost:4444"

const
  fontSize = 24
  smallFontSize = 16
  modelPath = "assets/models/gumshoe/gumshoe.glb"
  spritePath = "assets/sprites/logo/wg-logo-bw-alpha.png"
  fontPath = "assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf"
  bgmPath = "assets/music/ethernight_club.mp3"
  message = "Hello World!"

type
  AppContext = object
    komika: RLHandle
    komikaSmall: RLHandle
    gumshoe: RLHandle
    sprite: RLHandle
    camera: RLHandle
    bgm: RLHandle
    greyAlphaColor: RLHandle
    countdownTimer: float
    totalTime: float
    lastTime: float
    loadingGroup: RLTaskGroup[AppContext]

proc onInit(userData: pointer) {.cdecl.} =
  var ctx = cast[ptr AppContext](userData)

  let monitorOverride = getEnv("RL_MONITOR", "")
  if monitorOverride.len > 0:
    try:
      rl_window_set_monitor(parseInt(monitorOverride).cint)
    except ValueError:
      log.warn("Ignoring invalid RL_MONITOR value: " & monitorOverride)
  rl_window_set_monitor(1)
  rl_set_target_fps(60.cint)
  ctx.greyAlphaColor = rl_color_create(0, 0, 0, 128)
  rl_enable_lighting()
  rl_set_light_direction(-0.6, -1.0, -0.5)
  rl_set_light_ambient(0.25)
  ctx.camera = rl_camera3d_create(
    12.0, 12.0, 12.0,
    0.0, 1.0, 0.0,
    0.0, 1.0, 0.0,
    45.0, RL_CAMERA_PERSPECTIVE
  )
  discard rl_camera3d_set_active(ctx.camera)
  ctx.lastTime = rl_get_time().float
  ctx.countdownTimer = 5.0

  ctx.loadingGroup = loaderCreateTaskGroup(
    ctx,
    onComplete = proc(group: RLTaskGroup[AppContext], loadedCtx: var AppContext) =
      loadedCtx.loadingGroup = nil,
    onError = proc(group: RLTaskGroup[AppContext], loadedCtx: var AppContext) =
      log.error("asset import failed: " & group.failedPaths().join(", "))
      loadedCtx.loadingGroup = nil
      rl_stop()
  )
  ctx.loadingGroup.addImportTask(modelPath, onSuccess = proc(path: string, loadedCtx: var AppContext) =
    loadedCtx.gumshoe = rl_model_create(path.cstring)
    discard rl_model_set_animation(loadedCtx.gumshoe, 1)
    discard rl_model_set_animation_speed(loadedCtx.gumshoe, 1.0)
    discard rl_model_set_animation_loop(loadedCtx.gumshoe, true)
  )
  ctx.loadingGroup.addImportTask(spritePath, onSuccess = proc(path: string, loadedCtx: var AppContext) =
    loadedCtx.sprite = rl_sprite3d_create(path.cstring)
  )
  ctx.loadingGroup.addImportTask(fontPath, onSuccess = proc(path: string, loadedCtx: var AppContext) =
    loadedCtx.komika = rl_font_create(path.cstring, fontSize.cint)
    loadedCtx.komikaSmall = rl_font_create(path.cstring, smallFontSize.cint)
  )
  ctx.loadingGroup.addImportTask(bgmPath, onSuccess = proc(path: string, loadedCtx: var AppContext) =
    loadedCtx.bgm = rl_music_create(path.cstring)
    discard rl_music_set_loop(loadedCtx.bgm, true)
    discard rl_music_play(loadedCtx.bgm)
  )


proc onTick(userData: pointer) {.cdecl.} =
  var ctx = cast[ptr AppContext](userData)

  if not ctx.loadingGroup.isNil and ctx.loadingGroup.process() > 0:
    return

  let currentTime = rl_get_time().float
  let deltaTime = currentTime - ctx.lastTime
  ctx.totalTime += deltaTime
  ctx.lastTime = currentTime
  ctx.countdownTimer -= deltaTime
  if ctx.countdownTimer <= 0:
    rl_stop()
    return

  rl_music_update_all()

  rl_render_begin()
  rl_render_clear_background(RL_COLOR_RAYWHITE)
  rl_render_begin_mode_3d()
  discard rl_model_animate(ctx.gumshoe, deltaTime.cfloat)
  discard rl_model_set_transform(ctx.gumshoe, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0,
      1.0, 1.0)
  rl_model_draw(ctx.gumshoe, RL_COLOR_RAYWHITE)
  discard rl_sprite3d_set_transform(ctx.sprite, 0.0, 0.0, 0.0, 1.0)
  rl_sprite3d_draw(ctx.sprite, RL_COLOR_RAYWHITE)
  rl_render_end_mode_3d()

  let screen = rl_window_get_screen_size()
  let w = cint(screen.x)
  let h = cint(screen.y)
  let textSize = rl_text_measure_ex(ctx.komika, message.cstring,
      fontSize.cfloat, 0)
  let textX = cint((w.float32 - textSize.x) / 2)
  let textY = cint((h.float32 - textSize.y) / 2)
  rl_text_draw_ex(ctx.komika, message.cstring, textX, textY, fontSize.cfloat,
      1.0, RL_COLOR_BLUE)
  let remaining = fmt"Remaining: {ctx.countdownTimer:.2f}"
  let elapsed = fmt"Elapsed: {ctx.totalTime:.2f}"
  let mouse = rl_input_get_mouse_state()
  let mouseText = fmt"Mouse: ({mouse.x}, {mouse.y}) w:{mouse.wheel} b:[{mouse.left}, {mouse.right}, {mouse.middle}]"
  rl_text_draw_ex(ctx.komikaSmall, remaining.cstring, 10.cint, 36.cint,
      smallFontSize.cfloat, 1.0, RL_COLOR_BLACK)
  rl_text_draw_ex(ctx.komikaSmall, elapsed.cstring, 10.cint, 56.cint,
      smallFontSize.cfloat, 1.0, RL_COLOR_BLACK)
  rl_text_draw_ex(ctx.komikaSmall, mouseText.cstring, 10.cint, 76.cint,
      smallFontSize.cfloat, 1.0, RL_COLOR_BLACK)
  rl_text_draw_fps_ex(ctx.komikaSmall, 10.cint, 10.cint, smallFontSize.cfloat,
      ctx.greyAlphaColor)
  rl_render_end()

proc onShutdown(userData: pointer) {.cdecl.} =
  var ctx = cast[ptr AppContext](userData)
  rl_disable_lighting()
  if ctx.sprite != 0: rl_sprite3d_destroy(ctx.sprite)
  if ctx.gumshoe != 0: rl_model_destroy(ctx.gumshoe)
  if ctx.komika != 0: rl_font_destroy(ctx.komika)
  if ctx.komikaSmall != 0: rl_font_destroy(ctx.komikaSmall)
  if ctx.greyAlphaColor != 0: rl_color_destroy(ctx.greyAlphaColor)
  if ctx.camera != 0: rl_camera3d_destroy(ctx.camera)
  rl_deinit()

when isMainModule:
  var ctx = AppContext()
  var initCfg: RLInitConfig
  zeroMem(addr initCfg, sizeof(initCfg).csize_t)
  initCfg.window_width = 1024
  initCfg.window_height = 1280
  initCfg.window_title = "Hello, World! (Nim)"
  initCfg.window_flags = RL_FLAG_MSAA_4X_HINT.cuint
  initCfg.asset_host = assetHost
  if rl_init(initCfg) != 0:
    quit(1)
  rl_run(onInit, onTick, onShutdown, addr ctx)
