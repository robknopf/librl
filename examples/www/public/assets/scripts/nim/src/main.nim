import rl
import rl_log as log
import std/[math, strformat]
import esmexports

when not declared(rlAsync):
  import rl_async

when defined(emscripten) or defined(js):
  const AssetHost = "./"
else:
  const AssetHost = "https://localhost:4444"

const
  ResultOk = 0
  ResultError = -1
  ResultQuit = 1
  ScreenTitle = "nim scriptable (Nim runtime)"
  ScreenFlags = RL_FLAG_MSAA_4X_HINT
  ScreenWidth = 1024
  ScreenHeight = 1280
  DebugFontSize = 18
  DebugFontPath = "assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf"
  KomikaFontSize = 24
  KomikaFontPath = "assets/fonts/Komika/KOMIKAH_.ttf"
  BgmPath = "assets/music/ethernight_club.mp3"
  ModelPath = "assets/models/gumshoe/gumshoe.glb"
  SpritePath = "assets/sprites/logo/wg-logo-bw-alpha.png"

type
  AppContext = object
    elapsed: float
    countdownTimer: float
    totalTime: float
    debugFont: RLHandle
    komikaFont: RLHandle
    labelText2d: RLHandle
    sprite: RLHandle
    camera: RLHandle
    bgm: RLHandle
    greyAlphaColor: RLHandle
    gumshoe: RLHandle
    reloadCount: int
    spriteYOffset: float
    backgroundColor: RLHandle
    loadingGroup: RLTaskGroup[AppContext]

var
  ctx: ref AppContext
  msg = "Hello from Nim Simple Main !"
  platformText = "Platform: <unknown>"

proc getPlatformText(): string =
  "Platform: " & $rl_get_platform()

proc setupScene() =
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
  ctx.greyAlphaColor = rl_color_create(0, 0, 0, 128)
  ctx.backgroundColor = rl_color_create(245, 245, 245, 255)

proc teardownScene() =
  rl_disable_lighting()
  discard rl_camera3d_set_active(0)
  if ctx.camera != 0:
    rl_camera3d_destroy(ctx.camera)
    ctx.camera = 0
  if ctx.greyAlphaColor != 0:
    rl_color_destroy(ctx.greyAlphaColor)
    ctx.greyAlphaColor = 0
  if ctx.backgroundColor != 0:
    rl_color_destroy(ctx.backgroundColor)
    ctx.backgroundColor = 0

proc loadAssets() =
  ctx.gumshoe = rl_model_create(0)
  discard rl_model_set_transform(
    ctx.gumshoe,
    0.0, 0.0, 0.0,
    0.0, 0.0, 0.0,
    1.0, 1.0, 1.0
  )
  discard rl_model_set_animation(ctx.gumshoe, 1)
  discard rl_model_set_animation_speed(ctx.gumshoe, 1.0)
  discard rl_model_set_animation_loop(ctx.gumshoe, true)

  ctx.sprite = rl_sprite3d_create(0)
  discard rl_sprite3d_set_transform(ctx.sprite, 0.0, 0.0, ctx.spriteYOffset, 1.0)

  ctx.labelText2d = rl_text2d_create(0, KomikaFontSize.float)
  rl_text2d_set_content(ctx.labelText2d, "rl_text2d: retained label")
  rl_text2d_set_position(ctx.labelText2d, 10, 136)
  rl_text2d_set_color(ctx.labelText2d, RL_COLOR_GREEN)

  echo "queuing assets!!"
  ctx.loadingGroup = assetCreateTaskGroup(
    addr ctx[],
    onComplete = proc(group: RLTaskGroup[AppContext], loadedCtx: var AppContext) =
      loadedCtx.loadingGroup = nil,
    onError = proc(group: RLTaskGroup[AppContext], loadedCtx: var AppContext) =
      loadedCtx.loadingGroup = nil
  )

  ctx.loadingGroup.addImportTask(BgmPath,
    onSuccess = proc(path: string, loadedCtx: var AppContext) =
      loadedCtx.bgm = rl_music_create(path)
      discard rl_music_set_loop(loadedCtx.bgm, true)
      discard rl_music_play(loadedCtx.bgm),
    onError = proc(path: string, loadedCtx: var AppContext) =
      log.error("Failed to import BGM: " & path)
  )

  ctx.loadingGroup.addImportTask(ModelPath,
    onSuccess = proc(path: string, loadedCtx: var AppContext) =
      let modelAsset = rl_model_load_asset(path)
      discard rl_model_set_asset(loadedCtx.gumshoe, modelAsset),
    onError = proc(path: string, loadedCtx: var AppContext) =
      log.error("Failed to import MODEL: " & path)
  )

  ctx.loadingGroup.addImportTask(SpritePath,
    onSuccess = proc(path: string, loadedCtx: var AppContext) =
      let textureAsset = rl_texture_create(path)
      discard rl_sprite3d_set_texture(loadedCtx.sprite, textureAsset),
    onError = proc(path: string, loadedCtx: var AppContext) =
      log.error("Failed to import SPRITE: " & path)
  )

  ctx.loadingGroup.addImportTask(DebugFontPath,
    onSuccess = proc(path: string, loadedCtx: var AppContext) =
      loadedCtx.debugFont = rl_font_create(path, DebugFontSize),
    onError = proc(path: string, loadedCtx: var AppContext) =
      log.error("Failed to import DEBUG FONT: " & path)
  )

  ctx.loadingGroup.addImportTask(KomikaFontPath,
    onSuccess = proc(path: string, loadedCtx: var AppContext) =
      loadedCtx.komikaFont = rl_font_create(path, KomikaFontSize)
      rl_text2d_set_font(loadedCtx.labelText2d, loadedCtx.komikaFont),
    onError = proc(path: string, loadedCtx: var AppContext) =
      log.error("Failed to import KOMIKA FONT: " & path)
  )

proc unloadAssets() =
  ctx.loadingGroup = nil
  if ctx.gumshoe != 0:
    rl_model_destroy(ctx.gumshoe)
    ctx.gumshoe = 0
  if ctx.sprite != 0:
    rl_sprite3d_destroy(ctx.sprite)
    ctx.sprite = 0
  if ctx.bgm != 0:
    rl_music_destroy(ctx.bgm)
    ctx.bgm = 0
  if ctx.debugFont != 0:
    rl_font_destroy(ctx.debugFont)
    ctx.debugFont = 0

proc animateFrame(deltaTimeSec: float) =
  discard rl_model_animate(ctx.gumshoe, deltaTimeSec)

  var spriteX = 0.0
  var spriteY = 0.0
  var spriteZ = 0.0

  let bobSpeed = 1.0
  let bobHeight = 1.5
  let y = sin(ctx.elapsed * bobSpeed) * bobHeight
  spriteY = y + ctx.spriteYOffset

  discard rl_sprite3d_set_transform(ctx.sprite, spriteX, spriteY, spriteZ, 1.0)

 
# Included by default by runtime.nim.  Declare it here to override the default implementation.
#[
proc onBoot(): int {.rlAsync.} =
  let rc = rlAwait rl_boot(RLBootConfig(
    canvasId: "renderCanvas",
  ))
  if rc != 0:
    log.error("Main: onBoot failed with error: " & $rc)
    return ResultError

  rl_logger_set_level(RL_LOGGER_LEVEL_WARN.cint)
  return ResultOk
]#

proc onInit(): int {.rlAsync.} =
  ctx = new(AppContext)
  ctx[] = AppContext(
    elapsed: 0.0,
    countdownTimer: 30.0,
    totalTime: 0.0,
    debugFont: 0,
    komikaFont: 0,
    sprite: 0,
    camera: 0,
    bgm: 0,
    greyAlphaColor: 0,
    gumshoe: 0,
    reloadCount: 0,
    spriteYOffset: 3.0,
    backgroundColor: 0,
    loadingGroup: nil
  )

  let rc = rlAwait rl_init(RLInitConfig(
    windowWidth: ScreenWidth,
    windowHeight: ScreenHeight,
    windowTitle: ScreenTitle,
    windowFlags: ScreenFlags,
    assetHost: AssetHost,
  ))
  if rc != RL_INIT_OK:
    log.error("Main: onInit failed with error: " & $rc)
    return ResultError

  rl_window_set_monitor(1)
  discard rl_fs_clear()

  setupScene()

  rl_render_begin()
  rl_render_clear_background(ctx.backgroundColor)
  rl_render_end()

  return ResultOk

proc onTick(hostDt: float): int =
  let tickRc = rl_tick()
  if tickRc == RL_TICK_FAILED:
    log.error("Main: RL.tick failed with error: " & $tickRc)
    return ResultError
  if tickRc == RL_TICK_WAITING:
    return ResultOk
  if rl_window_close_requested():
    return ResultQuit

  if not ctx.isNil and not ctx.loadingGroup.isNil:
    discard ctx.loadingGroup.process()

  ctx.elapsed += hostDt
  ctx.totalTime += hostDt
  ctx.countdownTimer -= hostDt
  if ctx.countdownTimer <= 0:
    discard

  animateFrame(hostDt)
  rl_music_update_all()

  let mouse = rl_input_get_mouse_state()
  let mouseText = fmt"Mouse: ({mouse.x}, {mouse.y}) w:{mouse.wheel} b:[{mouse.left}, {mouse.right}, {mouse.middle}]"
  let remainingText = fmt"Remaining: {ctx.countdownTimer:.2f}"
  let elapsedText = fmt"Elapsed: {ctx.totalTime:.2f}"

  msg = "Nothing picked..."

  let pickResultModel = rl_pick_model(ctx.camera, ctx.gumshoe, mouse.x.float, mouse.y.float)
  if pickResultModel.hit:
    msg = fmt"Model pick: Mouse position (mouse.x:{mouse.x}, mouse.y:{mouse.y}) pick result y: {pickResultModel.point.y}"

  let pickResultSprite = rl_pick_sprite3d(ctx.camera, ctx.sprite, mouse.x.float, mouse.y.float)
  if pickResultSprite.hit:
    msg = fmt"Sprite pick: Mouse position (mouse.x:{mouse.x}, mouse.y:{mouse.y}) pick result y: {pickResultSprite.point.y}"

  rl_render_begin()
  rl_render_clear_background(ctx.backgroundColor)

  rl_render_begin_mode_3d()
  rl_model_draw(ctx.gumshoe, RL_COLOR_RAYWHITE)
  rl_sprite3d_draw(ctx.sprite, RL_COLOR_RAYWHITE)
  rl_render_end_mode_3d()

  let screen = rl_window_get_screen_size()
  let textSize = rl_text_measure_ex(ctx.komikaFont, msg, KomikaFontSize.float, 1.0)
  let textX = int((screen.x - textSize.x) / 2)
  let textY = int((screen.y - textSize.y) / 2)
  rl_text_draw_ex(ctx.komikaFont, msg, textX, textY, KomikaFontSize.float, 1.0, RL_COLOR_BLUE)
  rl_text_draw_ex(ctx.debugFont, remainingText, 10, 36, DebugFontSize.float, 1.0, RL_COLOR_BLACK)
  rl_text_draw_ex(ctx.debugFont, elapsedText, 10, 56, DebugFontSize.float, 1.0, RL_COLOR_BLACK)
  rl_text_draw_ex(ctx.debugFont, mouseText, 10, 76, DebugFontSize.float, 1.0, RL_COLOR_BLACK)
  rl_text_draw_ex(ctx.debugFont, fmt"Reloads: {ctx.reloadCount}", 10, 96, DebugFontSize.float, 1.0, RL_COLOR_BLACK)
  rl_text_draw_ex(ctx.debugFont, platformText, 10, 116, DebugFontSize.float, 1.0, RL_COLOR_BLACK)
  rl_text_draw_fps_ex(ctx.debugFont, 10, 10, DebugFontSize.float, ctx.greyAlphaColor)
  rl_text2d_draw(ctx.labelText2d)

  rl_render_end()
  return ResultOk

proc onLoad(stashed: ref AppContext): Future[int] {.rlAsync.} =
  echo "Main: onLoad"
  if stashed != nil:
    ctx = stashed
    inc ctx.reloadCount
  setupScene()
  loadAssets()
  platformText = getPlatformText()
  return ResultOk

proc onUnload(): ref AppContext =
  echo "Main: onUnload"
  unloadAssets()
  return ctx

proc onShutdown() {.rlAsync.} =
  echo "Main: onShutdown"
  teardownScene()
  rlAwaitVoid rl_deinit()

# required for runtime hooks
include runtime
