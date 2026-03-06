#include <stdio.h>
#include "rl.h"
#include "internal/exports.h"
#include "raylib.h"
#include "rl_loader.h"
#include "rl_scratch.h"
#include "internal/rl_color_store.h"
#include "internal/rl_font_store.h"
#include "internal/rl_subsystems.h"


bool initialized = false;

RL_KEEP
void rl_init() {
    if (initialized) {
        return;
    }    
    rl_loader_init("cache");
    rl_scratch_area_init();
    rl_color_init();
    rl_font_init();
    rl_model_init();
    rl_camera3d_init();
    rl_texture_init();
    rl_sprite3d_init();
    initialized = true;
}

RL_KEEP
void rl_deinit() {
    if (!initialized) {
        return;
    }
    rl_camera3d_deinit();
    initialized = false;
    rl_sprite3d_deinit();
    rl_texture_deinit();
    rl_model_deinit();
    rl_font_deinit();
    rl_color_deinit();
    rl_scratch_area_deinit();
    rl_loader_deinit();
}

RL_KEEP
int rl_set_asset_host(const char *asset_host) {
    return rl_loader_set_asset_host(asset_host);
}

RL_KEEP
const char *rl_get_asset_host(void) {
    return rl_loader_get_asset_host();
}

/*
RL_KEEP
void resize_canvas(int newWidth, int newHeight)
{
    printf("Reizing canvas to %d x %d\n", newWidth, newHeight);
    // actual resizing is done in the update loop to prevent flickering
    //desiredWidth = newWidth;
    //desiredHeight = newHeight;
}
*/

RL_KEEP
void rl_init_window(int width, int height, const char *title) {
    if (!initialized) {
        fprintf(stderr, "Error: rl_init_window() called before rl_init()\n");
        return;
    }
    //rl_init();
    InitWindow(width, height, title);
}

RL_KEEP
void rl_set_window_title(const char *title) {
    SetWindowTitle(title);
}       

RL_KEEP
void rl_set_window_size(int width, int height) {
    SetWindowSize(width, height);
}

RL_KEEP
int rl_get_screen_width() {
    return GetScreenWidth();
}

RL_KEEP
int rl_get_screen_height() {
    return GetScreenHeight();
}

RL_KEEP
int rl_get_monitor_count() {
#if defined(PLATFORM_DESKTOP)
    return GetMonitorCount();
#else
    return 1;
#endif
}

RL_KEEP
int rl_get_current_monitor() {
#if defined(PLATFORM_DESKTOP)
    return GetCurrentMonitor();
#else
    return 0;
#endif
}

RL_KEEP
void rl_set_window_monitor(int monitor) {
#if defined(PLATFORM_DESKTOP)
    SetWindowMonitor(monitor);
#else
    (void)monitor;
#endif
}

RL_KEEP
void rl_get_monitor_position(int monitor) {
#if defined(PLATFORM_DESKTOP)
    const Vector2 pos = GetMonitorPosition(monitor);
    rl_scratch_area_set_vector2(pos.x, pos.y);
#else
    (void)monitor;
    rl_scratch_area_set_vector2(0.0f, 0.0f);
#endif
}

RL_KEEP
float rl_get_monitor_position_x(int monitor) {
#if defined(PLATFORM_DESKTOP)
    const Vector2 pos = GetMonitorPosition(monitor);
    return pos.x;
#else
    (void)monitor;
    return 0.0f;
#endif
}

RL_KEEP
float rl_get_monitor_position_y(int monitor) {
#if defined(PLATFORM_DESKTOP)
    const Vector2 pos = GetMonitorPosition(monitor);
    return pos.y;
#else
    (void)monitor;
    return 0.0f;
#endif
}

RL_KEEP
void rl_get_window_position() {
    const Vector2 pos = GetWindowPosition();
    rl_scratch_area_set_vector2(pos.x, pos.y);
    //return pos;
}

RL_KEEP
float rl_get_window_position_x() {
    const Vector2 pos = GetWindowPosition();
    return pos.x;
}

RL_KEEP
float rl_get_window_position_y() {
    const Vector2 pos = GetWindowPosition();
    return pos.y;
}

RL_KEEP
void rl_get_mouse() {
    const Vector2 pos = GetMousePosition();
    rl_scratch_area_set_vector2(pos.x, pos.y);
}

RL_KEEP
float rl_get_mouse_x() {
    const Vector2 pos = GetMousePosition();
    return pos.x;
}

RL_KEEP
float rl_get_mouse_y() {
    const Vector2 pos = GetMousePosition();
    return pos.y;
}

RL_KEEP
int rl_get_mouse_wheel() {
    rl_mouse_t mouse = rl_scratch_area_get_mouse();
    return mouse.wheel;
}

RL_KEEP
int rl_get_mouse_button(int button) {
    rl_mouse_t mouse = rl_scratch_area_get_mouse();
    if (button < 0 || button >= RL_SCRATCH_AREA_MAX_NUM_MOUSE_BUTTONS) {
        return 0;
    }
    return mouse.buttons[button];
}

RL_KEEP
void rl_set_window_position(int x, int y) {
    SetWindowPosition(x, y);
}

RL_KEEP
void rl_close_window() {
    if (initialized) {
        rl_deinit();
    }
    CloseWindow();
}

RL_KEEP
void rl_begin_drawing() {
    BeginDrawing();
}

RL_KEEP
void rl_end_drawing() {
    EndDrawing();
}

RL_KEEP
void rl_clear_background(rl_handle_t color) {
    Color c = rl_color_get(color);
    ClearBackground(c);
}

RL_KEEP
void rl_set_target_fps(int fps) {
    SetTargetFPS(fps);
}

RL_KEEP
void rl_draw_fps(int x, int y) {
    DrawFPS(x, y);
}

RL_KEEP
void rl_draw_fps_ex(rl_handle_t font, int x, int y, int fontSize, rl_handle_t color) {
    Color c = rl_color_get(color);
    Font f = rl_font_get(font);
    int fps = GetFPS();
    Vector2 position = {x, y};

    //if ((fps < 30) && (fps >= 15)) color = ORANGE;  // Warning FPS
    //else if (fps < 15) color = RED;             // Low FPS

    DrawTextEx(f, TextFormat("%2i FPS", fps), position, fontSize, 1.0, c);
}

RL_KEEP
void rl_draw_text(const char *text, int x, int y, int fontSize, rl_handle_t color) {
    Color c = rl_color_get(color);
    DrawText(text, x, y, fontSize, c);
}

RL_KEEP
void rl_draw_text_ex(rl_handle_t font, const char *text, int x, int y, float fontSize, float spacing, rl_handle_t color) {
    Color c = rl_color_get(color);
    Font f = rl_font_get(font);
    Vector2 position = {x, y};
    //if (spacing < 0) {
    //    spacing = 0;
    //}
    //fprintf(stderr, "DrawTextEx: %d, %s, %f, %f, %d\n", font, text, fontSize, spacing, color);
    DrawTextEx(f, text, position, fontSize, spacing, c);
}

RL_KEEP
void rl_draw_rectangle(int x, int y, int width, int height, rl_handle_t color) {
    Color c = rl_color_get(color);
    DrawRectangle(x, y, width, height, c);
}

RL_KEEP
void rl_begin_mode_2d(rl_handle_t camera) {
    (void)camera;
   // BeginMode2D(cameras[camera]);
}

RL_KEEP
void rl_end_mode_2d() {
    EndMode2D();
}

RL_KEEP
void rl_update() {
    rl_scratch_area_update();
}

RL_KEEP
double rl_get_time() {
    return GetTime();
}
 
int rl_measure_text(const char *text, int fontSize) {
    return MeasureText(text, fontSize);
}

void rl_measure_text_ex(rl_handle_t font, const char *text, float fontSize, float spacing) {
    //fprintf(stderr, "MeasureTextEx: %d, %s, %f, %f\n", font, text, fontSize, spacing);
    Vector2 result = MeasureTextEx(rl_font_get(font), text, fontSize, spacing);
    //fprintf(stderr, "MeasureTextEx: (%f, %f)\n", result.x, result.y);
    rl_scratch_area_set_vector2(result.x, result.y);
    return;
}
