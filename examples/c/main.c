#include <raylib.h>

#include "rl.h"

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct addon_runtime_t {
    const rl_addon_api_t *api;
    void *state;
} addon_runtime_t;

static const char *get_asset_host(void)
{
    const char *value = getenv("RL_ASSET_HOST");
    if (value && value[0] != '\0') {
        return value;
    }
    return "https://localhost:4444";
}

static void addon_log(void *user_data, int level, const char *message)
{
    (void)user_data;
    log_message(level, "addon", 0, "%s", message != NULL ? message : "(null)");
}

static int addon_event_on(void *host_user_data, const char *event_name,
                          rl_addon_event_listener_fn listener, void *listener_user_data)
{
    (void)host_user_data;
    return rl_event_on(event_name, listener, listener_user_data);
}

static int addon_event_off(void *host_user_data, const char *event_name,
                           rl_addon_event_listener_fn listener, void *listener_user_data)
{
    (void)host_user_data;
    return rl_event_off(event_name, listener, listener_user_data);
}

static int addon_event_emit(void *host_user_data, const char *event_name, void *payload)
{
    (void)host_user_data;
    return rl_event_emit(event_name, payload);
}

static void on_lua_ready(void *payload, void *user_data)
{
    bool *ready = (bool *)user_data;
    (void)payload;
    if (ready != NULL) {
        *ready = true;
    }
    log_info("Lua addon ready");
}

static void on_lua_ok(void *payload, void *user_data)
{
    int *ok_count = (int *)user_data;
    (void)payload;
    if (ok_count != NULL) {
        (*ok_count)++;
    }
}

static void on_lua_error(void *payload, void *user_data)
{
    const char *error = (const char *)payload;
    int *error_count = (int *)user_data;
    if (error_count != NULL) {
        (*error_count)++;
    }
    log_error("Lua addon error: %s", error != NULL ? error : "(unknown)");
}

int main(void)
{
    SetTraceLogLevel(LOG_LEVEL_DEBUG); // let raylib log everything, we'll filter it in our callback   
    log_set_log_level(LOG_LEVEL_INFO);

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
    rl_pick_result_t last_pick = {0};
    bool has_pick = false;
    bool lua_ready = false;
    int lua_ok_count = 0;
    int lua_error_count = 0;
    addon_runtime_t lua_addon = {0};
    rl_addon_host_api_t addon_host = {0};
    char addon_error[256] = {0};

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

    (void)rl_event_on("lua.ready", on_lua_ready, &lua_ready);
    (void)rl_event_on("lua.ok", on_lua_ok, &lua_ok_count);
    (void)rl_event_on("lua.error", on_lua_error, &lua_error_count);

    addon_host.log = addon_log;
    addon_host.event_on = addon_event_on;
    addon_host.event_off = addon_event_off;
    addon_host.event_emit = addon_event_emit;

    if (rl_addon_init("lua", &addon_host, &lua_addon.api, &lua_addon.state, addon_error, sizeof(addon_error)) == 0) {
        if (rl_loader_cache_file("assets/scripts/lua_demo.lua") == 0) {
            (void)rl_event_emit("lua.do_file", "assets/scripts/lua_demo.lua");
        } else {
            log_warn("Failed to cache lua_demo.lua before lua.do_file");
        }
    } else {
        log_warn("Lua addon init failed: %s", addon_error);
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
        if (lua_addon.api != NULL && lua_addon.api->update != NULL) {
            (void)lua_addon.api->update(lua_addon.state, dt);
        }
        if (click_sound != 0 && IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
            Vector2 mouse = GetMousePosition();
            last_pick = rl_pick_model(camera, gumshoe, mouse.x, mouse.y, 0.0f, 0.0f, 0.0f, 1.0f);
            has_pick = true;
            (void)rl_sound_play(click_sound);
            if (last_pick.hit) {
                log_info("Picked gumshoe: distance=%.3f point=(%.2f, %.2f, %.2f)",
                         last_pick.distance,
                         last_pick.point.x, last_pick.point.y, last_pick.point.z);
            } else {
                log_info("Pick miss on gumshoe");
            }
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
        rl_draw_text_ex(komika_small,
                        TextFormat("lua ready: %s ok:%d err:%d", lua_ready ? "yes" : "no", lua_ok_count, lua_error_count),
                        10, 96, small_font_size, 1.0, RL_COLOR_DARKBLUE);
        if (has_pick) {
            if (last_pick.hit) {
                rl_draw_text_ex(komika_small,
                                TextFormat("Pick hit: d=%.2f @ (%.2f, %.2f, %.2f)",
                                           last_pick.distance, last_pick.point.x, last_pick.point.y, last_pick.point.z),
                                10, 52, small_font_size, 1.0, RL_COLOR_DARKGREEN);
            } else {
                rl_draw_text_ex(komika_small, "Pick miss", 10, 52, small_font_size, 1.0, RL_COLOR_MAROON);
            }
            rl_draw_fps_ex(komika_small, 10, 74, (int)small_font_size, RL_COLOR_BLACK);
        } else {
            rl_draw_fps_ex(komika_small, 10, 52, (int)small_font_size, RL_COLOR_BLACK);
        }
        //DrawText("Set RL_ASSET_HOST to override", 10, 30, 16, GRAY);

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
    if (lua_addon.api != NULL) {
        rl_addon_deinit_instance(lua_addon.api, lua_addon.state);
    }
    (void)rl_event_off("lua.ready", on_lua_ready, &lua_ready);
    (void)rl_event_off("lua.ok", on_lua_ok, &lua_ok_count);
    (void)rl_event_off("lua.error", on_lua_error, &lua_error_count);
    rl_deinit();
    CloseWindow();
    return 0;
}
