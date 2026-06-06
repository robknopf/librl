#include "rl_shape.h"

#include <stdlib.h>
#include <string.h>

#include "internal/exports.h"
#include "internal/rl_color.h"
#include "internal/rl_handle_pool.h"
#include "internal/rl_render_pass.h"
#include "internal/rl_scene.h"
#include "internal/rl_shape.h"
#include "raylib.h"

#define MAX_SHAPES 256

typedef struct
{
    float start_x;
    float start_y;
    float start_z;
    float end_x;
    float end_y;
    float end_z;
} rl_shape_line_3d_t;

typedef struct
{
    float *points;
    int point_count;
} rl_shape_line_strip_3d_t;

typedef union
{
    rl_shape_line_3d_t line_3d;
    rl_shape_line_strip_3d_t line_strip_3d;
} rl_shape_geometry_t;

typedef struct
{
    bool in_use;
    bool visible;
    rl_handle_t color;
    rl_shape_kind_t kind;
    rl_shape_geometry_t geometry;
} rl_shape_instance_t;

static rl_shape_instance_t rl_shapes[MAX_SHAPES];
static rl_handle_pool_t rl_shape_pool;
static uint16_t rl_shape_free_indices[MAX_SHAPES];
static uint16_t rl_shape_generations[MAX_SHAPES];
static unsigned char rl_shape_occupied[MAX_SHAPES];

static rl_shape_instance_t *resolve_shape_instance(rl_handle_t shape)
{
    uint16_t index = 0;

    if (!rl_handle_pool_resolve(&rl_shape_pool, shape, &index)) {
        return NULL;
    }
    if (!rl_shapes[index].in_use) {
        return NULL;
    }
    return &rl_shapes[index];
}

static void release_shape_geometry(rl_shape_instance_t *instance)
{
    if (instance == NULL) {
        return;
    }

    if (instance->kind == RL_SHAPE_KIND_LINE_STRIP_3D) {
        free(instance->geometry.line_strip_3d.points);
        instance->geometry.line_strip_3d.points = NULL;
        instance->geometry.line_strip_3d.point_count = 0;
    }
}

static void draw_line_strip_3d_points(const float *points, int point_count, Color color)
{
    int i = 0;

    if (points == NULL || point_count < 2) {
        return;
    }

    for (i = 0; i < point_count - 1; i++) {
        Vector3 start = {
            points[i * 3],
            points[i * 3 + 1],
            points[i * 3 + 2]
        };
        Vector3 end = {
            points[(i + 1) * 3],
            points[(i + 1) * 3 + 1],
            points[(i + 1) * 3 + 2]
        };
        DrawLine3D(start, end, color);
    }
}

static void draw_shape_instance(const rl_shape_instance_t *instance)
{
    Color color = {0};

    if (instance == NULL || !instance->visible) {
        return;
    }

    color = rl_color_get(instance->color);

    switch (instance->kind) {
    case RL_SHAPE_KIND_LINE_3D:
        DrawLine3D(
            (Vector3){
                instance->geometry.line_3d.start_x,
                instance->geometry.line_3d.start_y,
                instance->geometry.line_3d.start_z
            },
            (Vector3){
                instance->geometry.line_3d.end_x,
                instance->geometry.line_3d.end_y,
                instance->geometry.line_3d.end_z
            },
            color
        );
        break;
    case RL_SHAPE_KIND_LINE_STRIP_3D:
        draw_line_strip_3d_points(
            instance->geometry.line_strip_3d.points,
            instance->geometry.line_strip_3d.point_count,
            color
        );
        break;
    default:
        break;
    }
}

void rl_shape_init(void)
{
    rl_handle_pool_init(&rl_shape_pool,
                        RL_HANDLE_KIND_SHAPE,
                        MAX_SHAPES,
                        rl_shape_free_indices,
                        MAX_SHAPES,
                        rl_shape_generations,
                        rl_shape_occupied);
    memset(rl_shapes, 0, sizeof(rl_shapes));
}

void rl_shape_deinit(void)
{
    int i = 0;

    for (i = 0; i < MAX_SHAPES; i++) {
        if (!rl_shapes[i].in_use) {
            continue;
        }
        release_shape_geometry(&rl_shapes[i]);
        memset(&rl_shapes[i], 0, sizeof(rl_shapes[i]));
    }

    rl_handle_pool_reset(&rl_shape_pool);
}

bool rl_shape_is_valid(rl_handle_t handle)
{
    return resolve_shape_instance(handle) != NULL;
}

bool rl_shape_has_render_pass(rl_handle_t handle, rl_render_pass_t pass)
{
    rl_shape_instance_t *instance = resolve_shape_instance(handle);

    if (instance == NULL) {
        return false;
    }

    return pass == RL_RENDER_PASS_OPAQUE_3D &&
           instance->kind != RL_SHAPE_KIND_NONE;
}

void rl_shape_draw_pass(rl_handle_t handle, rl_render_pass_t pass)
{
    rl_shape_instance_t *instance = resolve_shape_instance(handle);

    if (instance == NULL || pass != RL_RENDER_PASS_OPAQUE_3D) {
        return;
    }

    draw_shape_instance(instance);
}

RL_KEEP
rl_handle_t rl_shape_create(void)
{
    rl_handle_t handle = rl_handle_pool_alloc(&rl_shape_pool);
    uint16_t index = 0;

    if (handle == 0) {
        return 0;
    }

    rl_handle_pool_resolve(&rl_shape_pool, handle, &index);
    memset(&rl_shapes[index], 0, sizeof(rl_shapes[index]));
    rl_shapes[index].in_use = true;
    rl_shapes[index].visible = true;
    rl_shapes[index].color = 0;
    rl_shapes[index].kind = RL_SHAPE_KIND_NONE;
    return handle;
}

RL_KEEP
void rl_shape_destroy(rl_handle_t shape)
{
    rl_shape_instance_t *instance = resolve_shape_instance(shape);

    if (instance == NULL) {
        return;
    }

    rl_scene_on_drawable_destroy(shape);
    release_shape_geometry(instance);
    memset(instance, 0, sizeof(*instance));
    rl_handle_pool_free(&rl_shape_pool, shape);
}

RL_KEEP
bool rl_shape_set_visible(rl_handle_t shape, bool visible)
{
    rl_shape_instance_t *instance = resolve_shape_instance(shape);

    if (instance == NULL) {
        return false;
    }

    instance->visible = visible;
    return true;
}

RL_KEEP
bool rl_shape_is_visible(rl_handle_t shape)
{
    rl_shape_instance_t *instance = resolve_shape_instance(shape);

    if (instance == NULL) {
        return false;
    }

    return instance->visible;
}

RL_KEEP
bool rl_shape_set_stroke_color(rl_handle_t shape, rl_handle_t color)
{
    rl_shape_instance_t *instance = resolve_shape_instance(shape);

    if (instance == NULL) {
        return false;
    }

    instance->color = color;
    return true;
}

RL_KEEP
bool rl_shape_set_line_3d(rl_handle_t shape,
                          float start_x, float start_y, float start_z,
                          float end_x, float end_y, float end_z)
{
    rl_shape_instance_t *instance = resolve_shape_instance(shape);

    if (instance == NULL) {
        return false;
    }

    release_shape_geometry(instance);
    instance->kind = RL_SHAPE_KIND_LINE_3D;
    instance->geometry.line_3d.start_x = start_x;
    instance->geometry.line_3d.start_y = start_y;
    instance->geometry.line_3d.start_z = start_z;
    instance->geometry.line_3d.end_x = end_x;
    instance->geometry.line_3d.end_y = end_y;
    instance->geometry.line_3d.end_z = end_z;
    return true;
}

RL_KEEP
bool rl_shape_set_line_strip_3d(rl_handle_t shape,
                                const float *points,
                                int point_count)
{
    rl_shape_instance_t *instance = resolve_shape_instance(shape);
    float *copy = NULL;
    size_t value_count = 0;

    if (instance == NULL || point_count < 0) {
        return false;
    }
    if (point_count > 0 && points == NULL) {
        return false;
    }

    value_count = (size_t)point_count * 3u;
    if (value_count > 0u) {
        copy = (float *)malloc(value_count * sizeof(float));
        if (copy == NULL) {
            return false;
        }
        memcpy(copy, points, value_count * sizeof(float));
    }

    release_shape_geometry(instance);
    instance->kind = RL_SHAPE_KIND_LINE_STRIP_3D;
    instance->geometry.line_strip_3d.points = copy;
    instance->geometry.line_strip_3d.point_count = point_count;
    return true;
}

RL_KEEP
void rl_shape_draw(rl_handle_t shape)
{
    draw_shape_instance(resolve_shape_instance(shape));
}

RL_KEEP
void rl_shape_draw_rectangle(int x, int y, int width, int height,
                             rl_handle_t color)
{
    Color c = rl_color_get(color);
    DrawRectangle(x, y, width, height, c);
}

RL_KEEP
void rl_shape_draw_cube(float position_x, float position_y, float position_z,
                        float width, float height, float length,
                        rl_handle_t color)
{
    Color c = rl_color_get(color);
    DrawCube((Vector3){position_x, position_y, position_z}, width, height, length, c);
}

RL_KEEP
void rl_shape_draw_circle_3d(float center_x, float center_y, float center_z,
                             float radius,
                             float rotation_axis_x, float rotation_axis_y, float rotation_axis_z,
                             float rotation_angle,
                             rl_handle_t color)
{
    Color c = rl_color_get(color);
    DrawCircle3D(
        (Vector3){center_x, center_y, center_z},
        radius,
        (Vector3){rotation_axis_x, rotation_axis_y, rotation_axis_z},
        rotation_angle,
        c
    );
}

RL_KEEP
void rl_shape_draw_line_3d(float start_x, float start_y, float start_z,
                           float end_x, float end_y, float end_z,
                           rl_handle_t color)
{
    Color c = rl_color_get(color);
    DrawLine3D(
        (Vector3){start_x, start_y, start_z},
        (Vector3){end_x, end_y, end_z},
        c
    );
}

RL_KEEP
void rl_shape_draw_line_strip_3d(const float* points, int point_count,
                                 rl_handle_t color)
{
    draw_line_strip_3d_points(points, point_count, rl_color_get(color));
}
