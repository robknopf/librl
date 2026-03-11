local time_s = 0
local sprite3d_logo = nil
local gumshoe_model = nil
local bg_music = nil
local click_sound = nil
local ui_font = nil
local mouse_left_was_down = false
local music_toggle_was_down = false
local tracked_key = 0
local text_buffer = ""
local backspace_repeat_delay = 0.35
local backspace_repeat_interval = 0.05
local backspace_hold_time = 0.0
local backspace_repeat_time = 0.0
local gumshoe_animation_index = 1
local gumshoe_animation_fps = 60.0

require("input_mapping")

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

sprite3d_logo = load_sprite3d("assets/sprites/logo/wg-logo-bw-alpha.png")
gumshoe_model = load_model("assets/models/gumshoe/gumshoe.glb")
bg_music = load_music("assets/music/ethernight_club.mp3")
click_sound = load_sound("assets/sounds/click_004.ogg")
ui_font = load_font("assets/fonts/Komika/KOMIKAH_.ttf", 24)

if bg_music ~= nil and bg_music ~= 0 then
  set_music_loop(bg_music, true)
  set_music_volume(bg_music, 0.25)
  play_music(bg_music)
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

  if mouse_left and not mouse_left_was_down and click_sound ~= nil and click_sound ~= 0 then
    play_sound(click_sound)
  end
  mouse_left_was_down = mouse_left

  if music_toggle_down and not music_toggle_was_down and bg_music ~= nil and bg_music ~= 0 then
    if is_music_playing(bg_music) then
      pause_music(bg_music)
    else
      play_music(bg_music)
    end
  end
  music_toggle_was_down = music_toggle_down

  clear(COLOR_RAYWHITE)
  draw_text(ui_font, "lua-driven frame", 24, 140 + wobble, 32, 1.0, COLOR_DARKBLUE)
  draw_text(ui_font, string.format("t = %.2f  mouse=(%d, %d) buttons=(L:%s R:%s M:%s) wheel=%d", time_s, mouse_x, mouse_y, mouse_left and "down" or "up", mouse_right and "down" or "up", mouse_middle and "down" or "up", Input.mouse_wheel(mouse)), 24, 182, 20, 1.0, COLOR_BLUE)
  draw_text(ui_font, string.format("kbd space=%s arrows=(%s %s %s %s)", Input.key_down(keyboard, Input.KEY_SPACE) and "down" or "up", Input.key_down(keyboard, Input.KEY_LEFT) and "L" or "-", Input.key_down(keyboard, Input.KEY_RIGHT) and "R" or "-", Input.key_down(keyboard, Input.KEY_UP) and "U" or "-", Input.key_down(keyboard, Input.KEY_DOWN) and "D" or "-"), 24, 212, 20, 1.0, COLOR_BLUE)
  draw_text(ui_font, string.format("pressed key=%d tracked=%d down=%s char=%d counts=(%d/%d) backspace=%d", keyboard.pressed_key, tracked_key, tracked_key_down and "yes" or "no", keyboard.pressed_char, keyboard.num_pressed_keys or 0, keyboard.num_pressed_chars or 0, backspace_presses), 24, 242, 20, 1.0, COLOR_BLUE)
  draw_text(ui_font, string.format("mods shift=%s ctrl=%s alt=%s", (Input.key_down(keyboard, Input.KEY_LEFT_SHIFT) or Input.key_down(keyboard, Input.KEY_RIGHT_SHIFT)) and "down" or "up", (Input.key_down(keyboard, Input.KEY_LEFT_CONTROL) or Input.key_down(keyboard, Input.KEY_RIGHT_CONTROL)) and "down" or "up", (Input.key_down(keyboard, Input.KEY_LEFT_ALT) or Input.key_down(keyboard, Input.KEY_RIGHT_ALT)) and "down" or "up"), 24, 272, 20, 1.0, COLOR_BLUE)
  draw_text(ui_font, string.format("text: %s_", text_buffer), 24, 302, 20, 1.0, COLOR_DARKBLUE)
  draw_text(ui_font, string.format("music(M): %s", (bg_music ~= nil and bg_music ~= 0 and is_music_playing(bg_music)) and "playing" or "paused"), 24, 332, 20, 1.0, COLOR_DARKBLUE)

  if sprite3d_logo ~= nil and sprite3d_logo ~= 0 then
    local bob = 1.0 + math.sin(time_s * 3.0) * 0.15
    local size = mouse_left and 1.5 or 1.0
    if Input.key_down(keyboard, Input.KEY_SPACE) then
      size = size + 0.5
    end
    draw_sprite3d(sprite3d_logo, 0.0, bob, 0.0, size, COLOR_WHITE)
  end

  if gumshoe_model ~= nil and gumshoe_model ~= 0 then
    local animation_frame = math.floor(time_s * gumshoe_animation_fps)
    draw_model(gumshoe_model, 2.5, 0.0, 0.0, 1.0, COLOR_WHITE, gumshoe_animation_index, animation_frame)
  end
end
