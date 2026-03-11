local time_s = 0
local sprite3d_logo = nil
local logo_texture = nil
local blob_shadow_texture = nil
local gumshoe_model = nil
local bg_music = nil
local click_sound = nil
local ui_font = nil
local main_camera = nil
local accent_color = nil
local panel_color = nil
local shadow_color = nil
local mouse_left_was_down = false
local music_toggle_was_down = false
local last_pick_result = nil
local tracked_key = 0
local text_buffer = ""
local backspace_repeat_delay = 0.35
local backspace_repeat_interval = 0.05
local backspace_hold_time = 0.0
local backspace_repeat_time = 0.0
local constructor_runs = 0
local load_generation = 0
local IDEAL_W = 1024
local IDEAL_H = 1280


require("input_mapping")
local Model = require("model")
local Music = require("music")
local Texture = require("texture")
local Sprite3D = require("sprite3d")
local Sound = require("sound")
local Camera3D = require("camera3d")
local Font = require("font")
local Color = require("color")
local Shadow = require("shadow")

local function append_pressed_char(buffer, ch)
  if ch == nil or ch < 32 or ch > 255 then
    return buffer
  end
  return buffer .. string.char(ch)
end

local function pop_last_char(buffer)
  if #buffer == 0 then
    return buffer
  end
  return string.sub(buffer, 1, #buffer - 1)
end

local function delete_last_char()
  if #text_buffer > 0 then
    text_buffer = pop_last_char(text_buffer)
  end
end

local function layout_metrics(frame)
  local screen_w = frame.screen_w or IDEAL_W
  local screen_h = frame.screen_h or IDEAL_H
  local sx = screen_w / IDEAL_W
  local sy = screen_h / IDEAL_H
  local su = math.min(sx, sy)

  return screen_w, screen_h, sx, sy, su
end

local function lx(x, sx)
  return x * sx
end

local function ly(y, sy)
  return y * sy
end

log("info", "lua_module: loaded lua_demo.lua")
function get_config()
  return {
    width = IDEAL_W,
    height = IDEAL_H,
    title = "librl + raylib + lua(C example)",
    target_fps = 60,
    flags = FLAG_MSAA_4X_HINT,
  }
end

function init()
  constructor_runs = 1
  log("info", "lua_demo: init() constructor")
end

function load()
  sprite3d_logo = Sprite3D.load("assets/sprites/logo/wg-logo-bw-alpha.png")
  logo_texture = Texture.load("assets/sprites/logo/wg-logo-bw-alpha.png")
  blob_shadow_texture = Texture.load("assets/textures/blobshadow.png")
  gumshoe_model = Model.load("assets/models/gumshoe/gumshoe.glb")
  bg_music = Music.load("assets/music/ethernight_club.mp3")
  click_sound = Sound.load("assets/sounds/click_004.ogg")
  ui_font = Font.load("assets/fonts/Komika/KOMIKAH_.ttf", 24)
  accent_color = Color.create(221, 87, 54, 255)
  panel_color = Color.create(24, 107, 138, 255)
  shadow_color = Color.create(0, 0, 0, 64)
  main_camera = Camera3D.create(12.0, 12.0, 12.0,
                                0.0, 1.0, 0.0,
                                0.0, 1.0, 0.0,
                                45.0, CAMERA_PERSPECTIVE)

  if bg_music ~= nil then
    bg_music:set_loop(true)
    bg_music:set_volume(0.25)
    bg_music:play()
  end

  if main_camera ~= nil then
    main_camera:set_active()
  end

  if gumshoe_model ~= nil then
    gumshoe_model.animation_index = 1
    gumshoe_model.animation_fps = 60.0
  end
  
  load_generation = load_generation + 1
  log("info", "lua_demo: load()")
end

function serialize()
  local music_playing = false

  if bg_music ~= nil then
    music_playing = bg_music:is_playing()
  end

  return {
    time_s = time_s,
    mouse_left_was_down = mouse_left_was_down,
    music_toggle_was_down = music_toggle_was_down,
    last_pick_result = last_pick_result,
    tracked_key = tracked_key,
    text_buffer = text_buffer,
    backspace_hold_time = backspace_hold_time,
    backspace_repeat_time = backspace_repeat_time,
    constructor_runs = constructor_runs,
    load_generation = load_generation,
    music_playing = music_playing,
  }
end

function unserialize(state)
  if state == nil then
    return
  end

  time_s = state.time_s or time_s
  mouse_left_was_down = state.mouse_left_was_down or false
  music_toggle_was_down = state.music_toggle_was_down or false
  last_pick_result = state.last_pick_result
  tracked_key = state.tracked_key or 0
  text_buffer = state.text_buffer or ""
  backspace_hold_time = state.backspace_hold_time or 0.0
  backspace_repeat_time = state.backspace_repeat_time or 0.0
  constructor_runs = state.constructor_runs or constructor_runs
  load_generation = (state.load_generation or 0) + 1

  if bg_music ~= nil then
    if state.music_playing then
      bg_music:play()
    else
      bg_music:pause()
    end
  end
end

function unload()
  if bg_music ~= nil then
    bg_music:stop()
  end

  sprite3d_logo = nil
  logo_texture = nil
  blob_shadow_texture = nil
  gumshoe_model = nil
  bg_music = nil
  click_sound = nil
  ui_font = nil
  main_camera = nil
  accent_color = nil
  panel_color = nil
  shadow_color = nil
end

function shutdown()
  log("info", "lua_demo: shutdown() destructor")
end

function update(frame)
  local dt = frame.dt
  local mouse = frame.mouse
  local keyboard = frame.keyboard
  local mouse_x, mouse_y = Input.mouse_position(mouse)
  local mouse_left = Input.mouse_button_down(mouse, Input.MOUSE_BUTTON_LEFT)
  local mouse_right = Input.mouse_button_down(mouse, Input.MOUSE_BUTTON_RIGHT)
  local mouse_middle = Input.mouse_button_down(mouse, Input.MOUSE_BUTTON_MIDDLE)
  local backspace_down = Input.key_down(keyboard, Input.KEY_BACKSPACE)
  local tracked_key_down = false
  local music_toggle_down = Input.key_down(keyboard, Input.KEY_M)
  local wobble = math.sin(time_s * 2.0) * 24.0
  local gumshoe_orbit = time_s * 0.9
  local gumshoe_radius = 3.5
  local gumshoe_vx = -math.sin(gumshoe_orbit)
  local gumshoe_vz = math.cos(gumshoe_orbit)
  local screen_w, screen_h, sx, sy, su = layout_metrics(frame)

  time_s = time_s + dt

  if keyboard.pressed_key ~= nil and keyboard.pressed_key > 0 then
    tracked_key = keyboard.pressed_key
  end

  local backspace_presses = 0

  if keyboard.pressed_keys ~= nil then
    for i = 1, (keyboard.num_pressed_keys or 0) do
      local keycode = keyboard.pressed_keys[i]
      if keycode == Input.KEY_BACKSPACE then
        backspace_presses = backspace_presses + 1
      end
    end
  end

  if keyboard.pressed_chars ~= nil then
    for i = 1, (keyboard.num_pressed_chars or 0) do
      local ch = keyboard.pressed_chars[i]
      text_buffer = append_pressed_char(text_buffer, ch)
    end
  end

  for _ = 1, backspace_presses do
    delete_last_char()
  end

  if backspace_down then
    backspace_hold_time = backspace_hold_time + dt
    if backspace_presses > 0 then
      backspace_repeat_time = 0.0
    elseif backspace_hold_time >= backspace_repeat_delay then
      backspace_repeat_time = backspace_repeat_time + dt
      while backspace_repeat_time >= backspace_repeat_interval do
        delete_last_char()
        backspace_repeat_time = backspace_repeat_time - backspace_repeat_interval
      end
    end
  else
    backspace_hold_time = 0.0
    backspace_repeat_time = 0.0
  end

  if tracked_key ~= nil and tracked_key > 0 then
    tracked_key_down = Input.key_down(keyboard, tracked_key)
    if not tracked_key_down then
      tracked_key = 0
    end
  end

  if mouse_left and not mouse_left_was_down and click_sound ~= nil then
    click_sound:play()
  end

  if gumshoe_model ~= nil and gumshoe_model.handle ~= 0 then
    gumshoe_model.x = math.cos(gumshoe_orbit) * gumshoe_radius
    gumshoe_model.y = 0.0
    gumshoe_model.z = math.sin(gumshoe_orbit) * gumshoe_radius
    gumshoe_model.scale = 1.0
    gumshoe_model.rot_x = 0.0
    gumshoe_model.rot_y = math.deg(math.atan2(gumshoe_vx, gumshoe_vz))
    gumshoe_model.rot_z = 0.0
    gumshoe_model.animation_frame = math.floor(time_s * (gumshoe_model.animation_fps or 60.0))
  end

  if mouse_left and not mouse_left_was_down and gumshoe_model ~= nil and gumshoe_model.handle ~= 0 then
    last_pick_result = gumshoe_model:pick(mouse_x, mouse_y)
  end
  mouse_left_was_down = mouse_left

  if music_toggle_down and not music_toggle_was_down and bg_music ~= nil then
    if bg_music:is_playing() then
      bg_music:pause()
    else
      bg_music:play()
    end
  end
  music_toggle_was_down = music_toggle_down

  if main_camera ~= nil and main_camera.handle ~= 0 then
    main_camera.position.x = 12.0
    main_camera.position.y = 10.0
    main_camera.position.z = 12.0
    main_camera.target.x = 0.0
    main_camera.target.y = 1.0
    main_camera.target.z = 0.0
    main_camera.up.x = 0.0
    main_camera.up.y = 1.0
    main_camera.up.z = 0.0
    main_camera.fovy = 45.0
    main_camera.projection = CAMERA_PERSPECTIVE
    main_camera:apply()
    main_camera:set_active()
  end

  clear(COLOR_RAYWHITE)
  if ui_font ~= nil and ui_font.handle ~= 0 then
    ui_font:draw("lua-driven frame", lx(24, sx), ly(140, sy) + wobble * sy, 32 * su, su, accent_color ~= nil and accent_color.handle or COLOR_DARKBLUE)
    ui_font:draw(string.format("constructor=%d load_generation=%d", constructor_runs, load_generation), lx(24, sx), ly(170, sy), 20 * su, su, accent_color ~= nil and accent_color.handle or COLOR_DARKBLUE)
    ui_font:draw(string.format("screen=(%d, %d) t=%.2f mouse=(%d, %d) buttons=(L:%s R:%s M:%s) wheel=%d", screen_w, screen_h, time_s, mouse_x, mouse_y, mouse_left and "down" or "up", mouse_right and "down" or "up", mouse_middle and "down" or "up", Input.mouse_wheel(mouse)), lx(24, sx), ly(200, sy), 20 * su, su, panel_color ~= nil and panel_color.handle or COLOR_BLUE)
    ui_font:draw(string.format("kbd space=%s arrows=(%s %s %s %s)", Input.key_down(keyboard, Input.KEY_SPACE) and "down" or "up", Input.key_down(keyboard, Input.KEY_LEFT) and "L" or "-", Input.key_down(keyboard, Input.KEY_RIGHT) and "R" or "-", Input.key_down(keyboard, Input.KEY_UP) and "U" or "-", Input.key_down(keyboard, Input.KEY_DOWN) and "D" or "-"), lx(24, sx), ly(230, sy), 20 * su, su, panel_color ~= nil and panel_color.handle or COLOR_BLUE)
    ui_font:draw(string.format("pressed key=%d tracked=%d down=%s char=%d counts=(%d/%d) backspace=%d", keyboard.pressed_key, tracked_key, tracked_key_down and "yes" or "no", keyboard.pressed_char, keyboard.num_pressed_keys or 0, keyboard.num_pressed_chars or 0, backspace_presses), lx(24, sx), ly(260, sy), 20 * su, su, panel_color ~= nil and panel_color.handle or COLOR_BLUE)
    ui_font:draw(string.format("mods shift=%s ctrl=%s alt=%s", (Input.key_down(keyboard, Input.KEY_LEFT_SHIFT) or Input.key_down(keyboard, Input.KEY_RIGHT_SHIFT)) and "down" or "up", (Input.key_down(keyboard, Input.KEY_LEFT_CONTROL) or Input.key_down(keyboard, Input.KEY_RIGHT_CONTROL)) and "down" or "up", (Input.key_down(keyboard, Input.KEY_LEFT_ALT) or Input.key_down(keyboard, Input.KEY_RIGHT_ALT)) and "down" or "up"), lx(24, sx), ly(290, sy), 20 * su, su, panel_color ~= nil and panel_color.handle or COLOR_BLUE)
    ui_font:draw(string.format("text: %s_", text_buffer), lx(24, sx), ly(320, sy), 20 * su, su, accent_color ~= nil and accent_color.handle or COLOR_DARKBLUE)
    ui_font:draw(string.format("music(M): %s", (bg_music ~= nil and bg_music:is_playing()) and "playing" or "paused"), lx(24, sx), ly(350, sy), 20 * su, su, accent_color ~= nil and accent_color.handle or COLOR_DARKBLUE)
    if last_pick_result ~= nil then
      if last_pick_result.hit then
        ui_font:draw(string.format("pick: hit d=%.2f @ (%.2f, %.2f, %.2f)",
                                   last_pick_result.distance,
                                   last_pick_result.point.x,
                                   last_pick_result.point.y,
                                   last_pick_result.point.z),
                     lx(24, sx), ly(380, sy), 20 * su, su, accent_color ~= nil and accent_color.handle or COLOR_DARKBLUE)
      else
        ui_font:draw("pick: miss", lx(24, sx), ly(380, sy), 20 * su, su, accent_color ~= nil and accent_color.handle or COLOR_DARKBLUE)
      end
    end
  end

  if sprite3d_logo ~= nil and sprite3d_logo.handle ~= 0 then
    local bob = 1.0 + math.sin(time_s * 3.0) * 0.15
    local size = mouse_left and 1.5 or 1.0
    if Input.key_down(keyboard, Input.KEY_SPACE) then
      size = size + 0.5
    end
    sprite3d_logo.x = 0.0
    sprite3d_logo.y = bob
    sprite3d_logo.z = 0.0
    sprite3d_logo.size = size
    if blob_shadow_texture ~= nil and blob_shadow_texture.handle ~= 0 and
       shadow_color ~= nil and shadow_color.handle ~= 0 then
      Shadow.draw_blob(blob_shadow_texture, sprite3d_logo, 1.35, shadow_color.handle, 0.0)
    end
    sprite3d_logo:draw(COLOR_WHITE)
  end

  if logo_texture ~= nil and logo_texture.handle ~= 0 then
    logo_texture.x = lx(520.0, sx)
    logo_texture.y = ly(36.0, sy)
    logo_texture.scale = 0.35 * su
    logo_texture.rotation = math.sin(time_s * 1.5) * 8.0
    logo_texture:draw(COLOR_WHITE)
  end

  if gumshoe_model ~= nil and gumshoe_model.handle ~= 0 then
    gumshoe_model:draw(COLOR_WHITE)
  end
end
