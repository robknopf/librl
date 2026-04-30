
local rl = require("rl")

rl.logger_set_level(rl.RL_LOGGER_LEVEL_DEBUG)

local function join_failed(g)
    local t = g:failed_paths()
    if not t or #t == 0 then
        return ""
    end
    return table.concat(t, ", ")
end

local app_context = {
    loading_group = nil,
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
    total_time = 0.0,
    last_time = 0.0,
}

local function setup_scene(ctx)
    local music_path = "assets/music/ethernight_club.mp3"
    local music_task = rl.loader_import_asset_async(music_path)
    if music_task and music_task ~= 0 then
        rl.loader_add_task(music_task, music_path, function(path)
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

    ctx.last_time = rl.get_time()
    ctx.countdown = 5.0

    -- draw a blank screen while loading assets
    rl.begin_drawing()
    rl.clear_background(ctx.bg_color)
    rl.end_drawing()
end

local function on_init(ctx)
    rl.set_target_fps(60)
    setup_scene(ctx)

    ctx.loading_group = rl.loader_create_task_group(
        function(_, loaded)
            loaded.loading_group = nil
        end,
        function(grp, loaded)
            rl.error("asset import failed: " .. join_failed(grp))
            loaded.loading_group = nil
            rl.stop()
        end,
        ctx
    )

    ctx.loading_group:add_import_task("assets/models/gumshoe/gumshoe.glb", function(path, loaded)
        loaded.model = rl.model_create(path)
        rl.model_set_animation(loaded.model, 1)
        rl.model_set_animation_speed(loaded.model, 1.0)
        rl.model_set_animation_loop(loaded.model, true)
    end)
    ctx.loading_group:add_import_task("assets/sprites/logo/wg-logo-bw-alpha.png", function(path, loaded)
        loaded.sprite = rl.sprite3d_create(path)
    end)
    ctx.loading_group:add_import_task("assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf", function(path, loaded)
        loaded.mono_font = rl.font_create(path, loaded.mono_font_size)
    end)
    ctx.loading_group:add_import_task("assets/fonts/Komika/KOMIKAH_.ttf", function(path, loaded)
        loaded.small_font = rl.font_create(path, loaded.small_font_size)
    end)
end

local function on_tick(ctx)
    if ctx.loading_group and ctx.loading_group:process() > 0 then
        return
    end

    local current = rl.get_time()
    local delta = current - ctx.last_time
    ctx.total_time = ctx.total_time + delta
    ctx.last_time = current
    ctx.countdown = ctx.countdown - delta
    if ctx.countdown <= 0 then
        rl.stop()
        return
    end

    rl.music_update_all()

    rl.begin_drawing()
    rl.clear_background(ctx.bg_color)
    rl.render_begin_mode_3d()
    if ctx.model and ctx.model ~= 0 then
        rl.model_animate(ctx.model, delta)
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
    local el = string.format("Elapsed: %.2f", ctx.total_time)
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
        rl.text_draw_ex(ctx.small_font, el, 10, 56, ctx.small_font_size, 1.0, rl.RL_COLOR_BLACK)
        rl.text_draw_ex(ctx.small_font, mouse_text, 10, 76, ctx.small_font_size, 1.0, rl.RL_COLOR_BLACK)
        rl.text_draw_fps_ex(ctx.small_font, 10, 10, ctx.small_font_size, ctx.fps_color)
    else
        rl.text_draw(el, 10, 56, ctx.small_font_size, rl.RL_COLOR_BLACK)
        rl.text_draw(mouse_text, 10, 76, ctx.small_font_size, rl.RL_COLOR_BLACK)
        rl.text_draw_fps(10, 10)
    end

    rl.end_drawing()
end

local function on_shutdown(c)
    rl.disable_lighting()
    if c.sprite and c.sprite ~= 0 then
        rl.sprite3d_destroy(c.sprite)
    end
    if c.model and c.model ~= 0 then
        rl.model_destroy(c.model)
    end
    if c.mono_font and c.mono_font ~= 0 then
        rl.font_destroy(c.mono_font)
    end
    if c.small_font and c.small_font ~= 0 then
        rl.font_destroy(c.small_font)
    end
    if c.bgm and c.bgm ~= 0 then
        rl.music_destroy(c.bgm)
    end
    if c.fps_color and c.fps_color ~= 0 then
        rl.color_destroy(c.fps_color)
    end
    if c.bg_color and c.bg_color ~= 0 then
        rl.color_destroy(c.bg_color)
    end
    if c.camera and c.camera ~= 0 then
        rl.camera3d_destroy(c.camera)
    end
    rl.deinit()
end

local init_rc = rl.init({
    window_width = 1024,
    window_height = 1280,
    window_title = "Hello, World! (Lua)",
    window_flags = rl.RL_WINDOW_FLAG_MSAA_4X_HINT,
    asset_host = "https://localhost:4444",
})
if init_rc == rl.RL_INIT_OK then
    rl.loader_clear_cache()
    rl.log("Loaded librl Lua module.")
elseif init_rc == rl.RL_INIT_ERR_ALREADY_INITIALIZED then
    rl.log("librl runtime already initialized by host.")
else
    error("rl.init failed: " .. tostring(init_rc))
end

rl.run(on_init, on_tick, on_shutdown, app_context)
