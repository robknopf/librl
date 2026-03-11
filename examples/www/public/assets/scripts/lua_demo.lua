local time_s = 0
local sprite3d_logo = nil
local click_sound = nil
local mouse_left_was_down = false

log("info", "lua_module: loaded lua_demo.lua")

sprite3d_logo = load_sprite3d("assets/sprites/logo/wg-logo-bw-alpha.png")
click_sound = load_sound("assets/sounds/click_004.ogg")

function update(dt, mouse_x, mouse_y, mouse_left)
  local wobble = math.sin(time_s * 2.0) * 24.0

  time_s = time_s + dt

  if mouse_left and not mouse_left_was_down and click_sound ~= nil and click_sound ~= 0 then
    play_sound(click_sound)
  end
  mouse_left_was_down = mouse_left

  clear(COLOR_RAYWHITE)
  draw_text(FONT_DEFAULT, "lua-driven frame", 24, 140 + wobble, 32, 1.0, COLOR_DARKBLUE)
  draw_text(FONT_DEFAULT, string.format("t = %.2f  mouse=(%.0f, %.0f) left=%s", time_s, mouse_x, mouse_y, mouse_left and "down" or "up"), 24, 182, 20, 1.0, COLOR_BLUE)

  if sprite3d_logo ~= nil and sprite3d_logo ~= 0 then
    local bob = 1.0 + math.sin(time_s * 3.0) * 0.15
    local size = mouse_left and 1.5 or 1.0
    draw_sprite3d(sprite3d_logo, 0.0, bob, 0.0, size, COLOR_WHITE)
  end
end
