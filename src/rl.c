#include <stdio.h>
#include <math.h>
#include "rl.h"
#include "exports.h"
#include "raylib.h"
#include "rl_handle.h"
#include "rl_color.h"
#include "rl_font.h"
#include "rl_loader.h"
#include "rl_model.h"
#include "rl_scratch.h"


bool initialized = false;
static bool rl_lighting_enabled = false;
static bool rl_lighting_ready = false;
static Shader rl_lighting_shader = {0};
static int rl_light_dir_loc = -1;
static int rl_light_ambient_loc = -1;
static int rl_light_tint_loc = -1;
static Vector3 rl_light_direction = { -0.6f, -1.0f, -0.5f };
static float rl_light_ambient = 0.25f;

Color rl_color_get(rl_handle_t color);
Font rl_font_get(rl_handle_t handle) ;

static Vector3 rl_vec3_normalized(Vector3 v) {
    float length = sqrtf(v.x * v.x + v.y * v.y + v.z * v.z);
    if (length <= 0.00001f) {
        return (Vector3){0.0f, -1.0f, 0.0f};
    }
    float inv_length = 1.0f / length;
    return (Vector3){v.x * inv_length, v.y * inv_length, v.z * inv_length};
}

static bool rl_lighting_try_init() {
    if (rl_lighting_ready) {
        return true;
    }
    if (!IsWindowReady()) {
        return false;
    }

#if defined(PLATFORM_WEB)
    const char *vertex_shader_source =
        "attribute vec3 vertexPosition;\n"
        "attribute vec3 vertexNormal;\n"
        "uniform mat4 mvp;\n"
        "varying vec3 fragNormal;\n"
        "void main() {\n"
        "  fragNormal = normalize(vertexNormal);\n"
        "  gl_Position = mvp * vec4(vertexPosition, 1.0);\n"
        "}\n";

    const char *fragment_shader_source =
        "precision mediump float;\n"
        "varying vec3 fragNormal;\n"
        "uniform vec3 lightDirection;\n"
        "uniform float ambient;\n"
        "uniform vec4 tintColor;\n"
        "void main() {\n"
        "  vec3 n = normalize(fragNormal);\n"
        "  vec3 l = normalize(-lightDirection);\n"
        "  float diffuse = max(dot(n, l), 0.0);\n"
        "  float intensity = clamp(ambient + diffuse, 0.0, 1.0);\n"
        "  gl_FragColor = vec4(tintColor.rgb * intensity, tintColor.a);\n"
        "}\n";
#else
    const char *vertex_shader_source =
        "#version 330\n"
        "in vec3 vertexPosition;\n"
        "in vec3 vertexNormal;\n"
        "uniform mat4 mvp;\n"
        "out vec3 fragNormal;\n"
        "void main() {\n"
        "  fragNormal = normalize(vertexNormal);\n"
        "  gl_Position = mvp * vec4(vertexPosition, 1.0);\n"
        "}\n";

    const char *fragment_shader_source =
        "#version 330\n"
        "in vec3 fragNormal;\n"
        "uniform vec3 lightDirection;\n"
        "uniform float ambient;\n"
        "uniform vec4 tintColor;\n"
        "out vec4 finalColor;\n"
        "void main() {\n"
        "  vec3 n = normalize(fragNormal);\n"
        "  vec3 l = normalize(-lightDirection);\n"
        "  float diffuse = max(dot(n, l), 0.0);\n"
        "  float intensity = clamp(ambient + diffuse, 0.0, 1.0);\n"
        "  finalColor = vec4(tintColor.rgb * intensity, tintColor.a);\n"
        "}\n";
#endif

    rl_lighting_shader = LoadShaderFromMemory(vertex_shader_source, fragment_shader_source);
    if (rl_lighting_shader.id == 0) {
        return false;
    }

    rl_light_dir_loc = GetShaderLocation(rl_lighting_shader, "lightDirection");
    rl_light_ambient_loc = GetShaderLocation(rl_lighting_shader, "ambient");
    rl_light_tint_loc = GetShaderLocation(rl_lighting_shader, "tintColor");
    rl_lighting_ready = (rl_light_dir_loc >= 0 && rl_light_ambient_loc >= 0 && rl_light_tint_loc >= 0);

    if (!rl_lighting_ready) {
        UnloadShader(rl_lighting_shader);
        rl_lighting_shader = (Shader){0};
        rl_light_dir_loc = -1;
        rl_light_ambient_loc = -1;
        rl_light_tint_loc = -1;
        return false;
    }

    return true;
}

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
    rl_lighting_enabled = false;
    rl_lighting_ready = false;
    rl_lighting_shader = (Shader){0};
    rl_light_dir_loc = -1;
    rl_light_ambient_loc = -1;
    rl_light_tint_loc = -1;
    rl_light_direction = (Vector3){ -0.6f, -1.0f, -0.5f };
    rl_light_ambient = 0.25f;
    initialized = true;
}

RL_KEEP
void rl_deinit() {
    if (!initialized) {
        return;
    }
    if (rl_lighting_ready) {
        UnloadShader(rl_lighting_shader);
    }
    rl_lighting_enabled = false;
    rl_lighting_ready = false;
    rl_lighting_shader = (Shader){0};
    rl_light_dir_loc = -1;
    rl_light_ambient_loc = -1;
    rl_light_tint_loc = -1;
    initialized = false;
    rl_model_deinit();
    rl_font_deinit();
    rl_color_deinit();
    rl_scratch_area_deinit();
    rl_loader_deinit();
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
void rl_begin_mode_3d(float position_x, float position_y, float position_z,
                      float target_x, float target_y, float target_z,
                      float up_x, float up_y, float up_z,
                      float fovy, int projection) {
    Camera3D camera = {0};
    camera.position = (Vector3){position_x, position_y, position_z};
    camera.target = (Vector3){target_x, target_y, target_z};
    camera.up = (Vector3){up_x, up_y, up_z};
    camera.fovy = fovy;
    camera.projection = projection;
    BeginMode3D(camera);
}

RL_KEEP
void rl_end_mode_3d() {
    EndMode3D();
}

RL_KEEP
void rl_enable_lighting() {
    rl_lighting_enabled = true;
    rl_lighting_try_init();
}

RL_KEEP
void rl_disable_lighting() {
    rl_lighting_enabled = false;
}

RL_KEEP
int rl_is_lighting_enabled() {
    return rl_lighting_enabled ? 1 : 0;
}

RL_KEEP
void rl_set_light_direction(float x, float y, float z) {
    rl_light_direction = rl_vec3_normalized((Vector3){x, y, z});
}

RL_KEEP
void rl_set_light_ambient(float ambient) {
    if (ambient < 0.0f) {
        ambient = 0.0f;
    }
    if (ambient > 1.0f) {
        ambient = 1.0f;
    }
    rl_light_ambient = ambient;
}

RL_KEEP
void rl_draw_cube(float position_x, float position_y, float position_z,
                  float width, float height, float length, rl_handle_t color) {
    Color c = rl_color_get(color);
    if (!rl_lighting_enabled || !rl_lighting_try_init()) {
        DrawCube((Vector3){position_x, position_y, position_z}, width, height, length, c);
        return;
    }

    float direction[3] = { rl_light_direction.x, rl_light_direction.y, rl_light_direction.z };
    float tint[4] = { c.r / 255.0f, c.g / 255.0f, c.b / 255.0f, c.a / 255.0f };
    SetShaderValue(rl_lighting_shader, rl_light_dir_loc, direction, SHADER_UNIFORM_VEC3);
    SetShaderValue(rl_lighting_shader, rl_light_ambient_loc, &rl_light_ambient, SHADER_UNIFORM_FLOAT);
    SetShaderValue(rl_lighting_shader, rl_light_tint_loc, tint, SHADER_UNIFORM_VEC4);

    BeginShaderMode(rl_lighting_shader);
    DrawCube((Vector3){position_x, position_y, position_z}, width, height, length, WHITE);
    EndShaderMode();
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
