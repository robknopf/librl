import std/[strformat, os, strutils]
import rl

proc main() =
  let komikaSize = 24
  let komikaSmallSize = 16
  var countdownTimer:float = 5.0
  var totalTime:float
  var deltaTime:float = 0
  var lastTime:float = 0
  var currentTime:float = 0

  rl_init()
  rl_init_window(800.cint, 600.cint, "Hello, World! (Nim)")
  let monitorOverride = getEnv("RL_MONITOR", "")
  if monitorOverride.len > 0:
    try:
      rl_set_window_monitor(parseInt(monitorOverride).cint)
    except ValueError:
      discard

  rl_set_window_monitor(1)

  rl_set_target_fps(60.cint)

  rl_enable_lighting();
  rl_set_light_direction(-0.6, -1.0, -0.5);
  rl_set_light_ambient(0.25);

  let komika = rl_font_create("https://localhost:4444/fonts/Komika/KOMIKAH_.ttf", komikaSize.cfloat)
  let komikaSmall = rl_font_create("https://localhost:4444/fonts/Komika/KOMIKAH_.ttf", komikaSmallSize.cfloat)
  let gumshoe = rl_model_create("https://localhost:4444/models/gumshoe/gumshoe.glb");
  discard rl_model_set_animation(gumshoe, 1)
  discard rl_model_set_animation_speed(gumshoe, 1.0)
  discard rl_model_set_animation_loop(gumshoe, true)

  lastTime = rl_get_time().float

  while true:
    currentTime = rl_get_time().float
    deltaTime = currentTime - lastTime
    totalTime += deltaTime
    lastTime = currentTime
    countdownTimer = countdownTimer - deltaTime
    if countdownTimer <= 0:
      break

    rl_update()
    rl_begin_drawing()
    rl_clear_background(RL_RAYWHITE)
    rl_begin_mode_3d(
      4.0, 4.0, 4.0,       # camera position
      0.0, 1.0, 0.0,       # camera target
      0.0, 1.0, 0.0,       # camera up
      45.0, RL_CAMERA_PERSPECTIVE
    )
    discard rl_model_animate(gumshoe, deltaTime.cfloat)
    rl_model_draw(gumshoe, 0.0, 0.0, 0.0, 1.0, RL_RAYWHITE)
    rl_end_mode_3d()
    rl_draw_text_ex(komika, "Hello World!", 10.cint, 10.cint, komikaSize.cfloat, 1.0, RL_BLUE)
    rl_draw_fps_ex(komikaSmall, 10.cint, 10.cint, komikaSmallSize.cint, RL_GRAY)
    let secondsRemainingText = fmt"Remaining: {countdownTimer:.2f}"
    rl_draw_text(secondsRemainingText.cstring, 10.cint, 30.cint, 20.cint, RL_BLACK)
    rl_end_drawing()

  rl_disable_lighting()
  rl_model_destroy(gumshoe)
  rl_deinit()
  rl_close_window()

when isMainModule:
  main()
