local time_s = 0
local sprite3d_logo = nil
local logo_texture = nil
local gumshoe_model = nil
local bg_music = nil
local click_sound = nil
local ui_font = nil
local main_camera = nil
local accent_color = nil
local panel_color = nil
local mouse_left_was_down = false
local music_toggle_was_down = false
local last_pick_result = nil
local tracked_key = 0
local text_buffer = ""
local backspace_repeat_delay = 0.35
local backspace_repeat_interval = 0.05
local backspace_hold_time = 0.0
local backspace_repeat_time = 0.0
local initialized = false

require("input_mapping")
local Model = require("model")
local Music = require("music")
local Texture = require("texture")
local Sprite3D = require("sprite3d")
local Sound = require("sound")
local Camera3D = require("camera3d")
local Font = require("font")
local Color = require("color")

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

log("info", "lua_module: loaded lua_demo.lua")

function get_config()
  return {
    width = 800,
    height = 600,
    title = "librl + raylib + lua(C example)",
    target_fps = 60,
    flags = FLAG_MSAA_4X_HINT,
  }
end

function init()
  if initialized then
    return
  end

  sprite3d_logo = Sprite3D.load("assets/sprites/logo/wg-logo-bw-alpha.png")
  logo_texture = Texture.load("assets/sprites/logo/wg-logo-bw-alpha.png")
  gumshoe_model = Model.load("assets/models/gumshoe/gumshoe.glb")
  bg_music = Music.load("assets/music/ethernight_club.mp3")
  click_sound = Sound.load("assets/sounds/click_004.ogg")
  ui_font = Font.load("assets/fonts/Komika/KOMIKAH_.ttf", 24)
  accent_color = Color.create(221, 87, 54, 255)
  panel_color = Color.create(24, 107, 138, 255)
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

  initialized = true
end

function shutdown()
  if bg_music ~= nil then
    bg_music:stop()
    bg_music:destroy()
    bg_music = nil
  end

  if click_sound ~= nil then
    click_sound:destroy()
    click_sound = nil
  end

  if gumshoe_model ~= nil then
    gumshoe_model:destroy()
    gumshoe_model = nil
  end

  if sprite3d_logo ~= nil then
    sprite3d_logo:destroy()
    sprite3d_logo = nil
  end

  if logo_texture ~= nil then
    logo_texture:destroy()
    logo_texture = nil
  end

  if ui_font ~= nil then
    ui_font:destroy()
    ui_font = nil
  end

  if accent_color ~= nil then
    accent_color:destroy()
    accent_color = nil
  end

  if panel_color ~= nil then
    panel_color:destroy()
    panel_color = nil
  end

  main_camera = nil
  initialized = false
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
    ui_font:draw("lua-driven frame", 24, 140 + wobble, 32, 1.0, accent_color ~= nil and accent_color.handle or COLOR_DARKBLUE)
    ui_font:draw(string.format("t = %.2f  mouse=(%d, %d) buttons=(L:%s R:%s M:%s) wheel=%d", time_s, mouse_x, mouse_y, mouse_left and "down" or "up", mouse_right and "down" or "up", mouse_middle and "down" or "up", Input.mouse_wheel(mouse)), 24, 182, 20, 1.0, panel_color ~= nil and panel_color.handle or COLOR_BLUE)
    ui_font:draw(string.format("kbd space=%s arrows=(%s %s %s %s)", Input.key_down(keyboard, Input.KEY_SPACE) and "down" or "up", Input.key_down(keyboard, Input.KEY_LEFT) and "L" or "-", Input.key_down(keyboard, Input.KEY_RIGHT) and "R" or "-", Input.key_down(keyboard, Input.KEY_UP) and "U" or "-", Input.key_down(keyboard, Input.KEY_DOWN) and "D" or "-"), 24, 212, 20, 1.0, panel_color ~= nil and panel_color.handle or COLOR_BLUE)
    ui_font:draw(string.format("pressed key=%d tracked=%d down=%s char=%d counts=(%d/%d) backspace=%d", keyboard.pressed_key, tracked_key, tracked_key_down and "yes" or "no", keyboard.pressed_char, keyboard.num_pressed_keys or 0, keyboard.num_pressed_chars or 0, backspace_presses), 24, 242, 20, 1.0, panel_color ~= nil and panel_color.handle or COLOR_BLUE)
    ui_font:draw(string.format("mods shift=%s ctrl=%s alt=%s", (Input.key_down(keyboard, Input.KEY_LEFT_SHIFT) or Input.key_down(keyboard, Input.KEY_RIGHT_SHIFT)) and "down" or "up", (Input.key_down(keyboard, Input.KEY_LEFT_CONTROL) or Input.key_down(keyboard, Input.KEY_RIGHT_CONTROL)) and "down" or "up", (Input.key_down(keyboard, Input.KEY_LEFT_ALT) or Input.key_down(keyboard, Input.KEY_RIGHT_ALT)) and "down" or "up"), 24, 272, 20, 1.0, panel_color ~= nil and panel_color.handle or COLOR_BLUE)
    ui_font:draw(string.format("text: %s_", text_buffer), 24, 302, 20, 1.0, accent_color ~= nil and accent_color.handle or COLOR_DARKBLUE)
    ui_font:draw(string.format("music(M): %s", (bg_music ~= nil and bg_music:is_playing()) and "playing" or "paused"), 24, 332, 20, 1.0, accent_color ~= nil and accent_color.handle or COLOR_DARKBLUE)
    if last_pick_result ~= nil then
      if last_pick_result.hit then
        ui_font:draw(string.format("pick: hit d=%.2f @ (%.2f, %.2f, %.2f)",
                                   last_pick_result.distance,
                                   last_pick_result.point.x,
                                   last_pick_result.point.y,
                                   last_pick_result.point.z),
                     24, 362, 20, 1.0, accent_color ~= nil and accent_color.handle or COLOR_DARKBLUE)
      else
        ui_font:draw("pick: miss", 24, 362, 20, 1.0, accent_color ~= nil and accent_color.handle or COLOR_DARKBLUE)
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
    sprite3d_logo:draw(COLOR_WHITE)
  end

  if logo_texture ~= nil and logo_texture.handle ~= 0 then
    logo_texture.x = 520.0
    logo_texture.y = 36.0
    logo_texture.scale = 0.35
    logo_texture.rotation = math.sin(time_s * 1.5) * 8.0
    logo_texture:draw(COLOR_WHITE)
  end

  if gumshoe_model ~= nil and gumshoe_model.handle ~= 0 then
    gumshoe_model:draw(COLOR_WHITE)
  end
end
