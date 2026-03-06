#include <raylib.h>

#include "rl.h"
#include "rl_camera3d.h"
#include "rl_color.h"
#include "rl_font.h"
#include "rl_model.h"
#include "rl_sprite3d.h"

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

int main(void)
{
    const char *asset_host = get_asset_host();
    const char *font_path = "assets/fonts/Komika/KOMIKAH_.ttf";
    const char *model_path = "assets/models/gumshoe/gumshoe.glb";
    const char *sprite_path = "assets/sprites/logo/wg-logo-bw-alpha.png";
    const float font_size = 24.0f;
    const float small_font_size = 16.0f;

    rl_init();
    if (rl_set_asset_host(asset_host) != 0) {
        fprintf(stderr, "Failed to set asset host: %s\n", asset_host);
        rl_deinit();
        return 1;
    }

    InitWindow(800, 600, "librl + raylib (C example)");
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
        DrawText(TextFormat("assetHost: %s", asset_host), 10, 10, 16, DARKGRAY);
        DrawText("Set RL_ASSET_HOST to override", 10, 30, 16, GRAY);
        rl_draw_fps_ex(komika_small, 10, 52, (int)small_font_size, RL_COLOR_BLACK);

        EndDrawing();
    }

    rl_camera3d_destroy(camera);
    rl_sprite3d_destroy(sprite);
    rl_model_destroy(gumshoe);
    rl_font_destroy(komika);
    rl_font_destroy(komika_small);
    rl_color_destroy(text_shadow);
    rl_deinit();
    CloseWindow();
    return 0;
}
