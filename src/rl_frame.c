#include "rl.h"
#include "internal/exports.h"
#include "internal/rl_subsystems.h"
#include "raylib.h"
#include "internal/rl_color_store.h"

RL_KEEP
void rl_frame_begin() {
    BeginDrawing();
}

RL_KEEP
void rl_frame_end() {
    rl_debug_draw();
    EndDrawing();
}

RL_KEEP
void rl_frame_clear_background(rl_handle_t color) {
    Color c = rl_color_get(color);
    ClearBackground(c);
}

RL_KEEP
float rl_frame_get_delta_time() {
    return GetFrameTime();
}

RL_KEEP
void rl_frame_begin_mode_2d(rl_handle_t camera) {
    (void)camera;
}

RL_KEEP
void rl_frame_end_mode_2d() {
    EndMode2D();
}

RL_KEEP
void rl_frame_draw_rectangle(int x, int y, int width, int height,
                             rl_handle_t color) {
    Color c = rl_color_get(color);
    DrawRectangle(x, y, width, height, c);
}

RL_KEEP
double rl_frame_get_time() {
    return GetTime();
}
