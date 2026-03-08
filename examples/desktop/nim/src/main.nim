import std/[strformat, os, strutils]
import rl

proc main() =
  let fontSize = 24
  let smallFontSize = 16
  let modelPath = "assets/models/gumshoe/gumshoe.glb"
  let spritePath = "assets/sprites/logo/wg-logo-bw-alpha.png"
  let fontPath = "assets/fonts/Komika/KOMIKAH_.ttf"
  let message = "Hello World!"
  var countdownTimer = 5.0
  var totalTime = 0.0
  var deltaTime = 0.0
  var lastTime = 0.0
  var currentTime = 0.0

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
  let greyAlphaColor = rl_color_create(0, 0, 0, 128)

  rl_enable_lighting();
  rl_set_light_direction(-0.6, -1.0, -0.5);
  rl_set_light_ambient(0.25);

  let komika = rl_font_create(fontPath.cstring, fontSize.cfloat)
  let komikaSmall = rl_font_create(fontPath.cstring, smallFontSize.cfloat)
  let gumshoe = rl_model_create(modelPath.cstring)
  let sprite = rl_sprite3d_create(spritePath.cstring)
  let camera = rl_camera3d_create(
    12.0, 12.0, 12.0,
    0.0, 1.0, 0.0,
    0.0, 1.0, 0.0,
    45.0, RL_CAMERA_PERSPECTIVE
  )
  discard rl_camera3d_set(
    camera,
    12.0, 12.0, 12.0,
    0.0, 1.0, 0.0,
    0.0, 1.0, 0.0,
    45.0, RL_CAMERA_PERSPECTIVE
  )
  discard rl_camera3d_set_active(camera)
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

    rl_begin_drawing()
    rl_clear_background(RL_RAYWHITE)
    rl_begin_mode_3d()
    discard rl_model_animate(gumshoe, deltaTime.cfloat)
    rl_model_draw(gumshoe, 0.0, 0.0, 0.0, 1.0, RL_RAYWHITE)
    rl_sprite3d_draw(sprite, 0.0, 0.0, 0.0, 1.0, RL_RAYWHITE)
    rl_end_mode_3d()

    let screen = rl_get_screen_size()
    let w = cint(screen.x)
    let h = cint(screen.y)
    let textSize = rl_measure_text_ex(komika, message.cstring, fontSize.cfloat, 0)
    let textX = cint((w.float32 - textSize.x) / 2)
    let textY = cint((h.float32 - textSize.y) / 2)
    rl_draw_text_ex(komika, message.cstring, textX, textY, fontSize.cfloat, 1.0, RL_BLUE)
    let remaining = fmt"Remaining: {countdownTimer:.2f}"
    let elapsed = fmt"Elapsed: {totalTime:.2f}"
    let mouse = rl_get_mouse_state()
    let mouseText = fmt"Mouse: ({mouse.x}, {mouse.y}) w:{mouse.wheel} b:[{mouse.left}, {mouse.right}, {mouse.middle}]"
    rl_draw_text_ex(komikaSmall, remaining.cstring, 10.cint, 36.cint, smallFontSize.cfloat, 1.0, RL_BLACK)
    rl_draw_text_ex(komikaSmall, elapsed.cstring, 10.cint, 56.cint, smallFontSize.cfloat, 1.0, RL_BLACK)
    rl_draw_text_ex(komikaSmall, mouseText.cstring, 10.cint, 76.cint, smallFontSize.cfloat, 1.0, RL_BLACK)
    rl_draw_fps_ex(komikaSmall, 10.cint, 10.cint, smallFontSize.cint, greyAlphaColor)
    rl_end_drawing()

  rl_disable_lighting()
  rl_sprite3d_destroy(sprite)
  rl_model_destroy(gumshoe)
  rl_font_destroy(komika)
  rl_font_destroy(komikaSmall)
  rl_color_destroy(greyAlphaColor)
  rl_camera3d_destroy(camera)
  rl_deinit()
  rl_close_window()

when isMainModule:
  main()
