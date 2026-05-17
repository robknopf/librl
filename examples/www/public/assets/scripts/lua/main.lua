local rl = require("rl")

rl.logger_set_level(rl.RL_LOGGER_LEVEL_WARN)

local DebugFontSize  = 18
local KomikaFontSize = 24

local ctx = {
  elapsed        = 0.0,
  countdown      = 30.0,
  message        = "Nothing picked!",
  mono_font      = 0,
  small_font     = 0,
  model          = 0,
  sprite         = 0,
  bgm            = 0,
  camera         = 0,
  bg_color       = 0,
  grey_alpha_color = 0,
  sprite_y_offset = 3.0,
}

local platform_text = "Platform: <unknown>"

local function setup_scene()
  local music_task = rl.loader_import_asset_async("assets/music/ethernight_club.mp3")
  if music_task and music_task ~= 0 then
    rl.loader_add_task(music_task, function(path)
      ctx.bgm = rl.music_create(path)
      rl.music_set_loop(ctx.bgm, true)
      rl.music_play(ctx.bgm)
    end, nil)
  else
    rl.warn("Failed to create music import task")
  end

  ctx.bg_color         = rl.color_create(245, 245, 245, 255)
  ctx.grey_alpha_color = rl.color_create(0, 0, 0, 128)

  ctx.camera = rl.camera3d_create(
    12.0, 12.0, 12.0,
    0.0,  1.0,  0.0,
    0.0,  1.0,  0.0,
    45.0, 0
  )
  rl.enable_lighting()
  rl.set_light_direction(-0.6, -1.0, -0.5)
  rl.set_light_ambient(0.25)
  rl.camera3d_set_active(ctx.camera)

  -- draw a blank frame while assets load
  rl.begin_drawing()
  rl.clear_background(ctx.bg_color)
  rl.end_drawing()
end

---@return ResultCode
local function on_init()
  local rc = rl.init({
    window_width  = 1024,
    window_height = 1280,
    window_title  = "Hello, World! (Lua)",
    window_flags  = rl.RL_WINDOW_FLAG_MSAA_4X_HINT,
    asset_host    = "https://localhost:4444",
  })
  if rc ~= rl.RL_INIT_OK then
    error("rl.init failed: " .. tostring(rc))
    return ResultCode.ERROR
  end

  rl.set_target_fps(60)
  rl.loader_clear_cache()

  setup_scene()

  platform_text = "Platform: " .. tostring(rl.get_platform())

  rl.loader_add_task(rl.loader_import_asset_async("assets/models/gumshoe/gumshoe.glb"), function(path)
    ctx.model = rl.model_create(path)
    rl.model_set_animation(ctx.model, 1)
    rl.model_set_animation_speed(ctx.model, 1.0)
    rl.model_set_animation_loop(ctx.model, true)
    rl.model_set_transform(ctx.model, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0)
  end, nil)

  rl.loader_add_task(rl.loader_import_asset_async("assets/sprites/logo/wg-logo-bw-alpha.png"), function(path)
    ctx.sprite = rl.sprite3d_create(path)
  end, nil)

  rl.loader_add_task(
    rl.loader_import_asset_async("assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf"),
    function(path)
      ctx.mono_font = rl.font_create(path, DebugFontSize)
    end, nil)

  rl.loader_add_task(rl.loader_import_asset_async("assets/fonts/Komika/KOMIKAH_.ttf"), function(path)
    ctx.small_font = rl.font_create(path, KomikaFontSize)
  end, nil)

  return ResultCode.OK
end

---@param delta_time number delta time in seconds
---@return ResultCode
local function on_tick(delta_time)
  ctx.elapsed   = ctx.elapsed + delta_time
  ctx.countdown = ctx.countdown - delta_time

  rl.music_update_all()

  -- bob sprite
  if ctx.sprite and ctx.sprite ~= 0 then
    local bob_y = math.sin(ctx.elapsed) * 1.5 + ctx.sprite_y_offset
    rl.sprite3d_set_transform(ctx.sprite, 0.0, bob_y, 0.0, 1.0)
  end

  -- animate model
  if ctx.model and ctx.model ~= 0 then
    rl.model_animate(ctx.model, delta_time)
  end

  -- pick testing
  local mouse = rl.input_get_mouse_state()
  ctx.message = "Nothing picked!"
  if ctx.model and ctx.model ~= 0 then
    local pick = rl.pick_model(ctx.camera, ctx.model, mouse.x, mouse.y)
    if pick.hit then
      ctx.message = string.format("Model pick: (%d, %d) y=%.2f", mouse.x, mouse.y, pick.point.y)
    end
  end
  if ctx.sprite and ctx.sprite ~= 0 then
    local pick = rl.pick_sprite3d(ctx.camera, ctx.sprite, mouse.x, mouse.y)
    if pick.hit then
      ctx.message = string.format("Sprite pick: (%d, %d) y=%.2f", mouse.x, mouse.y, pick.point.y)
    end
  end

  rl.begin_drawing()
  rl.clear_background(ctx.bg_color)

  rl.render_begin_mode_3d()
  if ctx.model and ctx.model ~= 0 then
    rl.model_draw(ctx.model, rl.RL_COLOR_RAYWHITE)
  end
  if ctx.sprite and ctx.sprite ~= 0 then
    rl.sprite3d_draw(ctx.sprite, rl.RL_COLOR_RAYWHITE)
  end
  rl.render_end_mode_3d()

  local screen_w, screen_h = rl.window_get_screen_size()
  screen_w = math.floor(screen_w)
  screen_h = math.floor(screen_h)

  -- center message (Komika)
  if ctx.small_font and ctx.small_font ~= 0 then
    local tw, th = rl.text_measure_ex(ctx.small_font, ctx.message, KomikaFontSize, 1.0)
    local tx = math.floor((screen_w - tw) / 2)
    local ty = math.floor((screen_h - th) / 2)
    rl.text_draw_ex(ctx.small_font, ctx.message, tx, ty, KomikaFontSize, 1.0, rl.RL_COLOR_BLUE)
  else
    local tw = rl.text_measure(ctx.message, KomikaFontSize)
    local tx = math.floor((screen_w - tw) / 2)
    local ty = math.floor(screen_h / 2)
    rl.text_draw(ctx.message, tx, ty, KomikaFontSize, rl.RL_COLOR_BLUE)
  end

  -- debug overlay (mono font)
  local remaining_text = string.format("Remaining: %.2f", ctx.countdown)
  local elapsed_text   = string.format("Elapsed: %.2f",   ctx.elapsed)
  local mouse_text     = string.format("Mouse: (%d, %d) w:%d b:[%d, %d, %d]",
    mouse.x, mouse.y, mouse.wheel, mouse.left, mouse.right, mouse.middle)

  if ctx.mono_font and ctx.mono_font ~= 0 then
    rl.text_draw_fps_ex(ctx.mono_font, 10, 10, DebugFontSize, ctx.grey_alpha_color)
    rl.text_draw_ex(ctx.mono_font, remaining_text, 10,  36, DebugFontSize, 1.0, rl.RL_COLOR_BLACK)
    rl.text_draw_ex(ctx.mono_font, elapsed_text,   10,  56, DebugFontSize, 1.0, rl.RL_COLOR_BLACK)
    rl.text_draw_ex(ctx.mono_font, mouse_text,     10,  76, DebugFontSize, 1.0, rl.RL_COLOR_BLACK)
    rl.text_draw_ex(ctx.mono_font, platform_text,  10,  96, DebugFontSize, 1.0, rl.RL_COLOR_BLACK)
  else
    rl.text_draw_fps(10, 10)
    rl.text_draw(remaining_text, 10, 36, DebugFontSize, rl.RL_COLOR_BLACK)
    rl.text_draw(elapsed_text,   10, 56, DebugFontSize, rl.RL_COLOR_BLACK)
    rl.text_draw(mouse_text,     10, 76, DebugFontSize, rl.RL_COLOR_BLACK)
    rl.text_draw(platform_text,  10, 96, DebugFontSize, rl.RL_COLOR_BLACK)
  end

  rl.end_drawing()

  return ResultCode.OK
end

local function on_shutdown()
  rl.deinit()
end

local function on_tick_wrapper(delta_time)
  local rc = rl.tick()
  if rc == rl.RL_TICK_FAILED then return ResultCode.ERROR end
  if rc == rl.RL_TICK_WAITING then return ResultCode.OK end
  if rl.window_close_requested() then return ResultCode.QUIT end
  return on_tick(delta_time)
end

return {
  on_init     = on_init,
  on_tick     = on_tick_wrapper,
  on_shutdown = on_shutdown,
}
