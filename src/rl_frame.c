#include "internal/exports.h"
#include "internal/rl_debug.h"
#include "raylib.h"
#include "internal/rl_color.h"

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
double rl_frame_get_time() {
    return GetTime();
}
