#include <math.h>
#include <stdbool.h>
#include <stdio.h>

#include "raylib.h"
#include "rl.h"
#include "rl_camera3d.h"
//#include "rl_color.h"
#include "internal/exports.h"
#include "internal/rl_camera3d_store.h"
#include "internal/rl_color_store.h"
#include "internal/rl_handle_pool.h"

// This module owns 3D camera tracking used by sprite3d and all simple lighting state.
// Public API remains in rl.h; rl.c just delegates lifecycle via rl_camera3d_init/deinit.

static bool rl_lighting_enabled = false;
static bool rl_lighting_ready = false;
static Shader rl_lighting_shader = {0};
static int rl_light_dir_loc = -1;
static int rl_light_ambient_loc = -1;
static int rl_light_tint_loc = -1;
static Vector3 rl_light_direction = {-0.6f, -1.0f, -0.5f};
static float rl_light_ambient = 0.25f;
static Camera3D rl_active_camera = {0};
static bool rl_has_active_camera = false;
static rl_handle_t rl_active_camera_handle = 0;

#define MAX_CAMERAS 256

typedef struct
{
    bool in_use;
    Camera3D camera;
} rl_camera3d_entry_t;

static rl_camera3d_entry_t rl_cameras[MAX_CAMERAS];
static rl_handle_pool_t rl_camera3d_pool;
static uint16_t rl_camera3d_free_indices[MAX_CAMERAS];
static uint16_t rl_camera3d_generations[MAX_CAMERAS];
static unsigned char rl_camera3d_occupied[MAX_CAMERAS];

const rl_handle_t RL_CAMERA3D_DEFAULT = RL_HANDLE_MAKE(1u, 1u);

static Camera3D rl_camera3d_build(float position_x, float position_y, float position_z,
                                  float target_x, float target_y, float target_z,
                                  float up_x, float up_y, float up_z,
                                  float fovy, int projection)
{
    Camera3D camera = {0};
    camera.position = (Vector3){position_x, position_y, position_z};
    camera.target = (Vector3){target_x, target_y, target_z};
    camera.up = (Vector3){up_x, up_y, up_z};
    camera.fovy = fovy;
    camera.projection = projection;
    return camera;
}

static rl_camera3d_entry_t *rl_camera3d_get_entry(rl_handle_t handle)
{
    uint16_t index = 0;
    if (!rl_handle_pool_resolve(&rl_camera3d_pool, handle, &index)) {
        return NULL;
    }
    if (!rl_cameras[index].in_use) {
        return NULL;
    }
    return &rl_cameras[index];
}

static void rl_set_active_camera_internal(Camera3D camera, rl_handle_t handle)
{
    rl_active_camera = camera;
    rl_has_active_camera = true;
    rl_active_camera_handle = handle;
}

static Vector3 rl_vec3_normalized(Vector3 v)
{
    float length = sqrtf(v.x * v.x + v.y * v.y + v.z * v.z);
    if (length <= 0.00001f) {
        return (Vector3){0.0f, -1.0f, 0.0f};
    }

    float inv_length = 1.0f / length;
    return (Vector3){v.x * inv_length, v.y * inv_length, v.z * inv_length};
}

static bool rl_lighting_try_init(void)
{
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

bool rl_camera3d_get_active_camera(Camera3D *camera)
{
    if (!rl_has_active_camera || camera == NULL) {
        return false;
    }
    *camera = rl_active_camera;
    return true;
}

static void rl_clear_active_camera(void)
{
    rl_has_active_camera = false;
    rl_active_camera = (Camera3D){0};
    rl_active_camera_handle = 0;
}

RL_KEEP
rl_handle_t rl_camera3d_create(float position_x, float position_y, float position_z,
                               float target_x, float target_y, float target_z,
                               float up_x, float up_y, float up_z,
                               float fovy, int projection)
{
    rl_handle_t handle = rl_handle_pool_alloc(&rl_camera3d_pool);
    uint16_t index = 0;
    if (handle == 0) {
        fprintf(stderr, "ERROR: MAX_CAMERAS reached (%d)\n", MAX_CAMERAS);
        return 0;
    }
    rl_handle_pool_resolve(&rl_camera3d_pool, handle, &index);

    rl_cameras[index].in_use = true;
    rl_cameras[index].camera = rl_camera3d_build(position_x, position_y, position_z,
                                                 target_x, target_y, target_z,
                                                 up_x, up_y, up_z,
                                                 fovy, projection);
    return handle;
}

RL_KEEP
rl_handle_t rl_camera3d_get_default(void)
{
    return RL_CAMERA3D_DEFAULT;
}

RL_KEEP
bool rl_camera3d_set(rl_handle_t handle,
                     float position_x, float position_y, float position_z,
                     float target_x, float target_y, float target_z,
                     float up_x, float up_y, float up_z,
                     float fovy, int projection)
{
    rl_camera3d_entry_t *entry = rl_camera3d_get_entry(handle);
    if (entry == NULL) {
        return false;
    }

    entry->camera = rl_camera3d_build(position_x, position_y, position_z,
                                      target_x, target_y, target_z,
                                      up_x, up_y, up_z,
                                      fovy, projection);

    if (rl_active_camera_handle == handle) {
        rl_set_active_camera_internal(entry->camera, handle);
    }

    return true;
}

RL_KEEP
bool rl_camera3d_set_active(rl_handle_t handle)
{
    rl_camera3d_entry_t *entry = rl_camera3d_get_entry(handle);
    if (entry == NULL) {
        return false;
    }

    rl_set_active_camera_internal(entry->camera, handle);
    return true;
}

RL_KEEP
rl_handle_t rl_camera3d_get_active(void)
{
    return rl_active_camera_handle;
}

RL_KEEP
void rl_camera3d_destroy(rl_handle_t handle)
{
    rl_camera3d_entry_t *entry = rl_camera3d_get_entry(handle);
    if (entry == NULL) {
        return;
    }
    if (handle == RL_CAMERA3D_DEFAULT) {
        return;
    }

    if (rl_active_camera_handle == handle) {
        rl_clear_active_camera();
    }

    entry->in_use = false;
    entry->camera = (Camera3D){0};
    rl_handle_pool_free(&rl_camera3d_pool, handle);
}

RL_KEEP
void rl_begin_mode_3d(void)
{
    if (!rl_has_active_camera)
    {
        rl_camera3d_entry_t *default_entry = rl_camera3d_get_entry(RL_CAMERA3D_DEFAULT);
        if (default_entry == NULL) {
            fprintf(stderr, "ERROR: Missing default camera entry\n");
            return;
        }
        rl_set_active_camera_internal(default_entry->camera, RL_CAMERA3D_DEFAULT);
    }

    BeginMode3D(rl_active_camera);
}

RL_KEEP
void rl_end_mode_3d(void)
{
    EndMode3D();
}

RL_KEEP
void rl_enable_lighting(void)
{
    rl_lighting_enabled = true;
    rl_lighting_try_init();
}

RL_KEEP
void rl_disable_lighting(void)
{
    rl_lighting_enabled = false;
}

RL_KEEP
int rl_is_lighting_enabled(void)
{
    return rl_lighting_enabled ? 1 : 0;
}

RL_KEEP
void rl_set_light_direction(float x, float y, float z)
{
    rl_light_direction = rl_vec3_normalized((Vector3){x, y, z});
}

RL_KEEP
void rl_set_light_ambient(float ambient)
{
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
                  float width, float height, float length, rl_handle_t color)
{
    Color c = rl_color_get(color);
    if (!rl_lighting_enabled || !rl_lighting_try_init()) {
        DrawCube((Vector3){position_x, position_y, position_z}, width, height, length, c);
        return;
    }

    float direction[3] = {rl_light_direction.x, rl_light_direction.y, rl_light_direction.z};
    float tint[4] = {c.r / 255.0f, c.g / 255.0f, c.b / 255.0f, c.a / 255.0f};
    SetShaderValue(rl_lighting_shader, rl_light_dir_loc, direction, SHADER_UNIFORM_VEC3);
    SetShaderValue(rl_lighting_shader, rl_light_ambient_loc, &rl_light_ambient, SHADER_UNIFORM_FLOAT);
    SetShaderValue(rl_lighting_shader, rl_light_tint_loc, tint, SHADER_UNIFORM_VEC4);

    BeginShaderMode(rl_lighting_shader);
    DrawCube((Vector3){position_x, position_y, position_z}, width, height, length, WHITE);
    EndShaderMode();
}

void rl_camera3d_init(void)
{
    // Reset to deterministic defaults so repeated rl_init/rl_deinit cycles are safe.
    rl_lighting_enabled = false;
    rl_lighting_ready = false;
    rl_lighting_shader = (Shader){0};
    rl_light_dir_loc = -1;
    rl_light_ambient_loc = -1;
    rl_light_tint_loc = -1;
    rl_light_direction = (Vector3){-0.6f, -1.0f, -0.5f};
    rl_light_ambient = 0.25f;
    rl_clear_active_camera();

    rl_handle_pool_init(&rl_camera3d_pool,
                        MAX_CAMERAS,
                        rl_camera3d_free_indices,
                        MAX_CAMERAS,
                        rl_camera3d_generations,
                        rl_camera3d_occupied);

    for (int i = 0; i < MAX_CAMERAS; i++) {
        rl_cameras[i].in_use = false;
        rl_cameras[i].camera = (Camera3D){0};
    }

    {
        rl_handle_t default_handle = rl_handle_pool_alloc(&rl_camera3d_pool);
        uint16_t default_index = 0;
        if (default_handle != RL_CAMERA3D_DEFAULT ||
            !rl_handle_pool_resolve(&rl_camera3d_pool, default_handle, &default_index)) {
            fprintf(stderr, "ERROR: Failed to initialize default camera handle\n");
            return;
        }

        rl_cameras[default_index].in_use = true;
        rl_cameras[default_index].camera = rl_camera3d_build(
        4.0f, 4.0f, 4.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        45.0f, CAMERA_PERSPECTIVE);
    }
}

void rl_camera3d_deinit(void)
{
    // Shader is owned here and must be released before global teardown finishes.
    if (rl_lighting_ready) {
        UnloadShader(rl_lighting_shader);
    }
    rl_lighting_enabled = false;
    rl_lighting_ready = false;
    rl_lighting_shader = (Shader){0};
    rl_light_dir_loc = -1;
    rl_light_ambient_loc = -1;
    rl_light_tint_loc = -1;
    rl_clear_active_camera();

    for (int i = 0; i < MAX_CAMERAS; i++) {
        rl_cameras[i].in_use = false;
        rl_cameras[i].camera = (Camera3D){0};
    }
    rl_handle_pool_reset(&rl_camera3d_pool);
}
