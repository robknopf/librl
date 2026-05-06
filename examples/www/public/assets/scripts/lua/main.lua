local rl = require("rl")

rl.logger_set_level(rl.RL_LOGGER_LEVEL_DEBUG)

--[[
-- defined in boot.lua
---@enum RTResult
RTResult = {
    SUCCESS = 0,
    FAILED = -1,
    STOPPED = 1
}
--]]

-- now() function, for now, use rl.get_time()
local now = rl.get_time

local function join_failed(g)
    local t = g:failed_paths()
    if not t or #t == 0 then
        return ""
    end
    return table.concat(t, ", ")
end



local ctx = {
    mono_font_size = 24,
    small_font_size = 16,
    message = "",
    mono_font = 0,
    small_font = 0,
    model = 0,
    sprite = 0,
    bgm = 0,
    camera = 0,
    bg_color = 0,
    fps_color = 0,
    countdown = 5.0,
    --total_time = 0.0,
    --last_time = 0.0,
}

local function setup_scene()
    local music_path = "assets/music/ethernight_club.mp3"
    local music_task = rl.loader_import_asset_async(music_path)
    if music_task and music_task ~= 0 then
        rl.loader_add_task(music_task, function(path)
            ctx.bgm = rl.music_create(path)
            rl.music_set_loop(ctx.bgm, true)
            rl.music_play(ctx.bgm)
        end, nil)
    else
        rl.warn("Failed to create music import task")
    end

    ctx.bg_color = rl.color_create(245, 245, 245, 255)
    ctx.fps_color = rl.color_create(0, 121, 241, 255)
    ctx.message = "Hello, World!"

    ctx.camera = rl.camera3d_create(
        12.0, 12.0, 12.0,
        0.0, 1.0, 0.0,
        0.0, 1.0, 0.0,
        45.0,
        0
    )
    rl.enable_lighting()
    rl.set_light_direction(-0.6, -1.0, -0.5)
    rl.set_light_ambient(0.25)
    rl.camera3d_set_active(ctx.camera)

    --ctx.last_time = rl.get_time()
    ctx.countdown = 5.0

    -- draw a blank screen while loading assets
    rl.begin_drawing()
    rl.clear_background(ctx.bg_color)
    rl.end_drawing()
end

---@return RTResult
local function on_init()
    local init_rc = rl.init({
        window_width = 1024,
        window_height = 1280,
        window_title = "Hello, World! (Lua)",
        window_flags = rl.RL_WINDOW_FLAG_MSAA_4X_HINT,
        asset_host = "https://localhost:4444",
    })
    if init_rc ~= rl.RL_INIT_OK then
        error("rl.init failed: " .. tostring(init_rc))
        return RTResult.FAILED
    end

    rl.set_target_fps(60)

    -- TODO:clearing the cache here may be too early if the fs hasn't synced yet.  probably should move it to the rt_init
    --rl.loader_clear_cache()

    setup_scene()

    rl.loader_add_task(rl.loader_import_asset_async("assets/models/gumshoe/gumshoe.glb"), function(path)
        ctx.model = rl.model_create(path)
        rl.model_set_animation(ctx.model, 1)
        rl.model_set_animation_speed(ctx.model, 1.0)
        rl.model_set_animation_loop(ctx.model, true)
    end, nil)
    rl.loader_add_task(rl.loader_import_asset_async("assets/sprites/logo/wg-logo-bw-alpha.png"), function(path)
        ctx.sprite = rl.sprite3d_create(path)
    end, nil)
    rl.loader_add_task(
    rl.loader_import_asset_async("assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf"), function(path)
        ctx.mono_font = rl.font_create(path, ctx.mono_font_size)
    end, nil)
    rl.loader_add_task(rl.loader_import_asset_async("assets/fonts/Komika/KOMIKAH_.ttf"), function(path)
        ctx.small_font = rl.font_create(path, ctx.small_font_size)
    end, nil)

    return RTResult.SUCCESS
end

---@param delta_time number delta time in seconds
---@return RTResult
local function on_tick(delta_time)
    --local current = rl.get_time()
    --local delta = current - ctx.last_time
    --ctx.total_time = ctx.total_time + delta
    --ctx.last_time = current
    ctx.countdown = ctx.countdown - delta_time
    if ctx.countdown <= 0 then
        return RTResult.STOPPED
    end

    rl.music_update_all()

    rl.begin_drawing()
    rl.clear_background(ctx.bg_color)
    rl.render_begin_mode_3d()
    if ctx.model and ctx.model ~= 0 then
        rl.model_animate(ctx.model, delta_time)
        rl.model_set_transform(ctx.model, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0)
        rl.model_draw(ctx.model, rl.RL_COLOR_WHITE)
    end
    if ctx.sprite and ctx.sprite ~= 0 then
        rl.sprite3d_set_transform(ctx.sprite, 0.0, 0.0, 0.0, 1.0)
        rl.sprite3d_draw(ctx.sprite, rl.RL_COLOR_WHITE)
    end
    rl.render_end_mode_3d()

    local w, h = rl.window_get_screen_size()
    w = math.floor(w)
    h = math.floor(h)
    if ctx.mono_font and ctx.mono_font ~= 0 then
        local tw, th = rl.text_measure_ex(ctx.mono_font, ctx.message, ctx.mono_font_size, 0)
        local text_x = math.floor((w - tw) / 2)
        local text_y = math.floor((h - th) / 2)
        rl.text_draw_ex(ctx.mono_font, ctx.message, text_x, text_y, ctx.mono_font_size, 1.0, rl.RL_COLOR_BLUE)
    else
        local fallback_w = rl.text_measure(ctx.message, 16)
        local fallback_x = math.floor((w - fallback_w) / 2)
        local fallback_y = math.floor(h / 2)
        rl.text_draw(ctx.message, fallback_x, fallback_y, ctx.small_font_size, rl.RL_COLOR_BLUE)
    end

    local rem = string.format("Remaining: %.2f", ctx.countdown)
    --local el = string.format("Elapsed: %.2f", ctx.total_time)
    local mouse = rl.input_get_mouse_state()
    local mouse_text = "Mouse: ("
        .. tostring(mouse.x)
        .. ", "
        .. tostring(mouse.y)
        .. ") w:"
        .. tostring(mouse.wheel)
        .. " b:["
        .. tostring(mouse.left)
        .. ", "
        .. tostring(mouse.right)
        .. ", "
        .. tostring(mouse.middle)
        .. "]"

    if ctx.mono_font and ctx.mono_font ~= 0 then
        rl.text_draw_ex(ctx.mono_font, rem, 10, 36, 16, 1.0, rl.RL_COLOR_BLACK)
    else
        rl.text_draw(rem, 10, 36, 16, rl.RL_COLOR_BLACK)
    end
    if ctx.small_font and ctx.small_font ~= 0 then
       -- rl.text_draw_ex(ctx.small_font, el, 10, 56, ctx.small_font_size, 1.0, rl.RL_COLOR_BLACK)
        rl.text_draw_ex(ctx.small_font, mouse_text, 10, 76, ctx.small_font_size, 1.0, rl.RL_COLOR_BLACK)
        rl.text_draw_fps_ex(ctx.small_font, 10, 10, ctx.small_font_size, ctx.fps_color)
    else
       -- rl.text_draw(el, 10, 56, ctx.small_font_size, rl.RL_COLOR_BLACK)
        rl.text_draw(mouse_text, 10, 76, ctx.small_font_size, rl.RL_COLOR_BLACK)
        rl.text_draw_fps(10, 10)
    end

    rl.end_drawing()

    return RTResult.SUCCESS
end

local function on_shutdown()
    rl.disable_lighting()
    if ctx.sprite and ctx.sprite ~= 0 then
        rl.sprite3d_destroy(ctx.sprite)
    end
    if ctx.model and ctx.model ~= 0 then
        rl.model_destroy(ctx.model)
    end
    if ctx.mono_font and ctx.mono_font ~= 0 then
        rl.font_destroy(ctx.mono_font)
    end
    if ctx.small_font and ctx.small_font ~= 0 then
        rl.font_destroy(ctx.small_font)
    end
    if ctx.bgm and ctx.bgm ~= 0 then
        rl.music_destroy(ctx.bgm)
    end
    if ctx.fps_color and ctx.fps_color ~= 0 then
        rl.color_destroy(ctx.fps_color)
    end
    if ctx.bg_color and ctx.bg_color ~= 0 then
        rl.color_destroy(ctx.bg_color)
    end
    if ctx.camera and ctx.camera ~= 0 then
        rl.camera3d_destroy(ctx.camera)
    end
    rl.deinit()
end


---Initial bootstrap
---@return RTResult
local function rt_boot()
    -- do initial bootstrap setup
    return RTResult.SUCCESS
end

---@return RTResult
local function rt_init(_host_context)
    return on_init()
end


---@param delta_time number in seconds
---@return RTResult
local function rt_tick(delta_time)
    local rc = rl.tick()
    if (rc == rl.RL_TICK_FAILED) then return RTResult.FAILED end
    if (rc == rl.RL_TICK_WAITING) then return RTResult.SUCCESS end
    if (rl.window_close_requested()) then return RTResult.STOPPED end
    return on_tick(delta_time)
end

---@return nil
local function rt_shutdown()
    on_shutdown()
end


-- deprecated, we have to pump the runtime from an outside host 
-- rl.run(on_init, on_tick, on_shutdown, app_context)

-- use socket for the time module, fall back to os.clock
do
    -- for now, use libRL's time
    now = rl.get_time

    if not now then 
        local ok, socket = pcall(require, "socket")
        if ok and socket and socket.gettime then
            print("using socket.gettime for now()")
            now = socket.gettime
        else
            print("socket module unavailable, using os.clock() for now()")
            now = os.clock
        end
    end
end

return {
    rt_boot = rt_boot,
    rt_init = rt_init,
    rt_tick = rt_tick,
    rt_shutdown = rt_shutdown
}

--[[
--------------------------------------------------------------
-- act like we were hosted and simulate the lifecycle pump

local rc = rt_boot()
if rc ~= RTResult.SUCCESS then return end

rc = rt_init(nil)
if rc ~= RTResult.SUCCESS then return end

local last_time = now()
local delta_time = 0
repeat
    delta_time = now() - last_time
    rc = rt_tick(delta_time)
    last_time = now()
until rc ~= RTResult.SUCCESS
rt_shutdown()

---------------------------------------------------------------
]]--
