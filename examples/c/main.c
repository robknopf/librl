#include <raylib.h>

#include "rl.h"
#include "rl_camera3d.h"
#include "rl_color.h"
#include "rl_font.h"
#include "rl_model.h"
#include "rl_music.h"
#include "rl_sound.h"
#include "rl_sprite3d.h"
#include "lua_interop.h"
#include "logger/log.h"


#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

static const char *get_asset_host(void)
{
    const char *value = getenv("RL_ASSET_HOST");
    if (value && value[0] != '\0') {
        return value;
    }
    return "https://localhost:4444";
}

void reroute_raylib_log(int log_level, const char *text, va_list args)
{
    char msg[2048];
    va_list copy;
    int level = LOG_LEVEL_INFO;

    va_copy(copy, args);
    vsnprintf(msg, sizeof(msg), text, copy);
    va_end(copy);

    switch (log_level) {
        case LOG_TRACE:
            level = LOG_LEVEL_TRACE;
            break;
        case LOG_DEBUG:
            level = LOG_LEVEL_DEBUG;
            break;
        case LOG_INFO:
            level = LOG_LEVEL_INFO;
            break;
        case LOG_WARNING:
            level = LOG_LEVEL_WARN;
            break;
        case LOG_ERROR:
            level = LOG_LEVEL_ERROR;
            break;
        case LOG_FATAL:
            level = LOG_LEVEL_FATAL;
            break;
        default:
            level = LOG_LEVEL_INFO;
    
    }

    log_message(level, "raylib", 0, "%s", msg);
}

int main(void)
{
    SetTraceLogCallback(reroute_raylib_log);
    SetTraceLogLevel(LOG_LEVEL_DEBUG); // let raylib log everything, we'll filter it in our callback   
    log_set_log_level(LOG_LEVEL_WARN);

    const char *asset_host = get_asset_host();
    const char *font_path = "assets/fonts/Komika/KOMIKAH_.ttf";
    const char *model_path = "assets/models/gumshoe/gumshoe.glb";
    const char *sprite_path = "assets/sprites/logo/wg-logo-bw-alpha.png";
    const char *music_path = "assets/music/ethernight_club.mp3";
    const char *click_sound_path = "assets/sounds/click_004.ogg";
    const float font_size = 24.0f;
    const float small_font_size = 16.0f;
    rl_handle_t music = 0;
    rl_handle_t click_sound = 0;
    lua_interop_vm_t lua_vm = {0};

    rl_init();
    if (rl_set_asset_host(asset_host) != 0) {
        fprintf(stderr, "Failed to set asset host: %s\n", asset_host);
        rl_deinit();
        return 1;
    }

    //SetConfigFlags(FLAG_MSAA_4X_HINT);

    InitWindow(800, 600, "librl + raylib + lua(C example)");
    SetTargetFPS(60);

    rl_handle_t komika = rl_font_create(font_path, font_size);
    rl_handle_t komika_small = rl_font_create(font_path, small_font_size);
    rl_handle_t gumshoe = rl_model_create(model_path);
    rl_handle_t sprite = rl_sprite3d_create(sprite_path);
    rl_handle_t text_shadow = rl_color_create(0, 0, 0, 160);
    rl_handle_t camera = rl_camera3d_create(
        12.0f, 12.0f, 12.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        45.0f, CAMERA_PERSPECTIVE);

    if (lua_interop_init(&lua_vm, "assets/scripts") == 0) {
        (void)lua_interop_run_file(&lua_vm, "lua_demo.lua");
    } else {
        log_error("Lua interop init failed");
    }

    music = rl_music_create(music_path);
    if (music != 0) {
        (void)rl_music_set_loop(music, true);
        (void)rl_music_set_volume(music, 0.25f);
        (void)rl_music_play(music);
    } else {
        log_warn("Failed to load music stream from %s", music_path);
    }

    click_sound = rl_sound_create(click_sound_path);
    if (click_sound == 0) {
        log_warn("Failed to load click sound from %s", click_sound_path);
    }

    (void)rl_camera3d_set_active(camera);
    (void)rl_model_set_animation(gumshoe, 1);
    (void)rl_model_set_animation_speed(gumshoe, 1.0f);
    (void)rl_model_set_animation_loop(gumshoe, true);

    while (!WindowShouldClose())
    {
        const float dt = GetFrameTime();
        const int screen_w = GetScreenWidth();
        const int screen_h = GetScreenHeight();
        const char *message = "raylib loop + librl handles";
        vec2_t message_size = {0};
        int text_x = 0;
        int text_y = 0;

        if (music != 0) {
            (void)rl_music_update(music);
        }
        if (click_sound != 0 && IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
            (void)rl_sound_play(click_sound);
        }

        (void)rl_model_animate(gumshoe, dt);

        BeginDrawing();
        ClearBackground(RAYWHITE);

        rl_begin_mode_3d();
        rl_model_draw(gumshoe, 0.0f, 0.0f, 0.0f, 1.0f, RL_COLOR_WHITE);
        rl_sprite3d_draw(sprite, 0.0f, 0.0f, 0.0f, 1.0f, RL_COLOR_WHITE);
        rl_end_mode_3d();

        message_size = rl_measure_text_ex(komika, message, font_size, 1.0f);
        text_x = (int)((screen_w - message_size.x) * 0.5f);
        text_y = (int)((screen_h - message_size.y) * 0.5f);

        rl_draw_text_ex(komika, message, text_x + 2, text_y + 2, font_size, 1.0f, text_shadow);
        rl_draw_text_ex(komika, message, text_x, text_y, font_size, 1.0f, RL_COLOR_BLUE);
        rl_draw_text_ex(komika_small, TextFormat("assetHost: %s", asset_host), 10, 10, small_font_size, 1.0, RL_COLOR_DARKGRAY);
        rl_draw_text_ex(komika_small, "Set RL_ASSET_HOST to override", 10, 30, small_font_size, 1.0, RL_COLOR_GRAY);
        //DrawText("Set RL_ASSET_HOST to override", 10, 30, 16, GRAY);
        rl_draw_fps_ex(komika_small, 10, 52, (int)small_font_size, RL_COLOR_BLACK);

        EndDrawing();
    }

    rl_camera3d_destroy(camera);
    rl_sprite3d_destroy(sprite);
    rl_model_destroy(gumshoe);
    rl_font_destroy(komika);
    rl_font_destroy(komika_small);
    rl_color_destroy(text_shadow);
    if (click_sound != 0) {
        rl_sound_destroy(click_sound);
    }
    if (music != 0) {
        rl_music_destroy(music);
    }
    lua_interop_deinit(&lua_vm);
    rl_deinit();
    CloseWindow();
    return 0;
}
