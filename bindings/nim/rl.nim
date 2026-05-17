import rl_async
export rl_async

when defined(js):
  include impl/rl_js
else:
  include impl/rl_native

type RLInitConfig* = object
  windowWidth*: int
  windowHeight*: int
  windowTitle*: string
  windowFlags*: RLWindowFlags
  assetHost*: string
  loaderCacheDir*: string

proc rl_init*(config = RLInitConfig()): int {.rlAsync.} =
  return rlAwait rl_init_values(config.windowWidth, config.windowHeight,
                                config.windowTitle, config.windowFlags,
                                config.assetHost, config.loaderCacheDir)
