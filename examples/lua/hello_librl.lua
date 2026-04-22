
local rl = require("rl")

print("Loaded librl Lua module.")
rl.init()
rl.window_open(1024, 1280, "Hello, librl (using rl.so lua library)", rl.RL_WINDOW_FLAG_MSAA_4X_HINT);
rl.set_target_fps(60);
local bg = rl.color_create(20, 20, 24, 255)
local t0 = rl.get_time()

local function draw()
    rl.begin_drawing()
    rl.clear_background(rl.RL_COLOR_YELLOW)
    rl.end_drawing()
end

rl.run(nil, function()
    draw()
    if rl.get_time() - t0 >= 8.0 then
        rl.stop()
    end
end, nil, nil)

rl.color_destroy(bg)
rl.window_close()
rl.deinit()
