import std/[strformat, os, strutils]
import rl

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
  message = "Hello World!"

type
  AppContext = object
    komika: RLHandle
    komikaSmall: RLHandle
    gumshoe: RLHandle
    sprite: RLHandle
    camera: RLHandle
    greyAlphaColor: RLHandle
    countdownTimer: float
    totalTime: float
    lastTime: float
    assetsReady: int

proc onAssetReady(path: cstring, userData: pointer) {.cdecl.} =
  var ctx = cast[ptr AppContext](userData)
  ctx.assetsReady.inc

proc onAssetFailed(path: cstring, userData: pointer) {.cdecl.} =
  echo "Failed to load asset: ", path

proc queueAsset(path: cstring, ctx: ptr AppContext) =
  let task = rl_loader_import_asset_async(path)
  let rc = rl_loader_add_task(task, path, onAssetReady, onAssetFailed, ctx)
  if rc != RL_LOADER_ADD_TASK_OK:
    echo "Failed to queue asset: ", path

proc onInit(userData: pointer) {.cdecl.} =
  var ctx = cast[ptr AppContext](userData)

  rl_window_open(1024, 1280, "Hello, World! (Nim)", RL_FLAG_MSAA_4X_HINT)
  let monitorOverride = getEnv("RL_MONITOR", "")
  if monitorOverride.len > 0:
    try:
      rl_window_set_monitor(parseInt(monitorOverride).cint)
    except ValueError:
      discard
  rl_window_set_monitor(1)
  rl_set_target_fps(60.cint)

  queueAsset(fontPath, ctx)
  queueAsset(modelPath, ctx)
  queueAsset(spritePath, ctx)

proc onTick(userData: pointer) {.cdecl.} =
  var ctx = cast[ptr AppContext](userData)

  if ctx.assetsReady < 3:
    return

  if ctx.komika == 0:
    ctx.greyAlphaColor = rl_color_create(0, 0, 0, 128)
    rl_enable_lighting()
    rl_set_light_direction(-0.6, -1.0, -0.5)
    rl_set_light_ambient(0.25)

    ctx.komika = rl_font_create(fontPath.cstring, fontSize.cfloat)
    ctx.komikaSmall = rl_font_create(fontPath.cstring, smallFontSize.cfloat)
    ctx.gumshoe = rl_model_create(modelPath.cstring)
    ctx.sprite = rl_sprite3d_create(spritePath.cstring)
    ctx.camera = rl_camera3d_create(
      12.0, 12.0, 12.0,
      0.0, 1.0, 0.0,
      0.0, 1.0, 0.0,
      45.0, RL_CAMERA_PERSPECTIVE
    )
    discard rl_camera3d_set_active(ctx.camera)
    discard rl_model_set_animation(ctx.gumshoe, 1)
    discard rl_model_set_animation_speed(ctx.gumshoe, 1.0)
    discard rl_model_set_animation_loop(ctx.gumshoe, true)
    ctx.lastTime = rl_get_time().float
    ctx.countdownTimer = 5.0

  let currentTime = rl_get_time().float
  let deltaTime = currentTime - ctx.lastTime
  ctx.totalTime += deltaTime
  ctx.lastTime = currentTime
  ctx.countdownTimer -= deltaTime
  if ctx.countdownTimer <= 0:
    rl_request_stop()
    return

  rl_render_begin()
  rl_render_clear_background(RL_COLOR_RAYWHITE)
  rl_render_begin_mode_3d()
  discard rl_model_animate(ctx.gumshoe, deltaTime.cfloat)
  discard rl_model_set_transform(ctx.gumshoe, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0)
  rl_model_draw(ctx.gumshoe, RL_COLOR_RAYWHITE)
  discard rl_sprite3d_set_transform(ctx.sprite, 0.0, 0.0, 0.0, 1.0)
  rl_sprite3d_draw(ctx.sprite, RL_COLOR_RAYWHITE)
  rl_render_end_mode_3d()

  let screen = rl_window_get_screen_size()
  let w = cint(screen.x)
  let h = cint(screen.y)
  let textSize = rl_text_measure_ex(ctx.komika, message.cstring, fontSize.cfloat, 0)
  let textX = cint((w.float32 - textSize.x) / 2)
  let textY = cint((h.float32 - textSize.y) / 2)
  rl_text_draw_ex(ctx.komika, message.cstring, textX, textY, fontSize.cfloat, 1.0, RL_COLOR_BLUE)
  let remaining = fmt"Remaining: {ctx.countdownTimer:.2f}"
  let elapsed = fmt"Elapsed: {ctx.totalTime:.2f}"
  let mouse = rl_input_get_mouse_state()
  let mouseText = fmt"Mouse: ({mouse.x}, {mouse.y}) w:{mouse.wheel} b:[{mouse.left}, {mouse.right}, {mouse.middle}]"
  rl_text_draw_ex(ctx.komikaSmall, remaining.cstring, 10.cint, 36.cint, smallFontSize.cfloat, 1.0, RL_COLOR_BLACK)
  rl_text_draw_ex(ctx.komikaSmall, elapsed.cstring, 10.cint, 56.cint, smallFontSize.cfloat, 1.0, RL_COLOR_BLACK)
  rl_text_draw_ex(ctx.komikaSmall, mouseText.cstring, 10.cint, 76.cint, smallFontSize.cfloat, 1.0, RL_COLOR_BLACK)
  rl_text_draw_fps_ex(ctx.komikaSmall, 10.cint, 10.cint, smallFontSize.cint, ctx.greyAlphaColor)
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
  rl_window_close()

when isMainModule:
  var ctx = AppContext()
  rl_init()
  discard rl_set_asset_host(assetHost)
  rl_run(onInit, onTick, onShutdown, addr ctx)
