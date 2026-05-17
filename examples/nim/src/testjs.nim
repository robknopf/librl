import rl
import rl_log as log

when defined(emscripten):
  const assetHost = "./"
else:
  const assetHost = "https://localhost:4444"

const
  ResultOk = 0
  ResultError = -1
  ResultQuit = 1
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
    resultCode: cint

var ctx: AppContext

proc onBoot(): int {.rlAsync.} =
  echo "boot"
  let rc = rlAwait rl_boot(RLBootConfig(
    bindingsPath: "/bindings/js/rl.js",
  ))
  if rc != 0: return rc
  return ResultOk

proc onInit(): int {.rlAsync.} =
  echo "init"
  log.debug("Hello")
  let rc = rlAwait rl_init(RLInitConfig(
    windowWidth: 800,
    windowHeight: 600,
    windowTitle: "Hello World!",
    assetHost: assetHost,
  ))
  if rc != 0: return rc
  return ResultOk

proc onTick(hostDt: float): int =
  echo "tick"
  ResultOk

proc onShutdown() =
  echo "shutdown"


# include the runtime footer
include runtime
