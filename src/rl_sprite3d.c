#include "rl_sprite3d.h"

#include <raylib.h>
#include <raymath.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#include "internal/exports.h"
#include "internal/rl_camera3d.h"
#include "internal/rl_color.h"
#include "internal/rl_handle_pool.h"
#include "internal/rl_sprite3d.h"
#include "logger/logger.h"
#include "rl_texture.h"
#include "internal/rl_texture.h"

#define MAX_SPRITE3D 1024

typedef struct
{
    bool in_use;
    rl_handle_t texture;
    float position_x;
    float position_y;
    float position_z;
    float size;
} rl_sprite3d_t;

static rl_sprite3d_t rl_sprite3d[MAX_SPRITE3D];
static rl_handle_pool_t rl_sprite3d_pool;
static uint16_t rl_sprite3d_free_indices[MAX_SPRITE3D];
static uint16_t rl_sprite3d_generations[MAX_SPRITE3D];
static unsigned char rl_sprite3d_occupied[MAX_SPRITE3D];

static rl_sprite3d_t *rl_sprite3d_get(rl_handle_t handle)
{
    uint16_t index = 0;
    if (!rl_handle_pool_resolve(&rl_sprite3d_pool, handle, &index)) {
        log_error("Invalid sprite3d handle (%u)", (unsigned int)handle);
        return NULL;
    }
    if (!rl_sprite3d[index].in_use) {
        log_error("Stale sprite3d handle (%u)", (unsigned int)handle);
        return NULL;
    }
    return &rl_sprite3d[index];
}

RL_KEEP
rl_handle_t rl_sprite3d_create(const char *filename)
{
    rl_handle_t texture = rl_texture_create(filename);
    rl_handle_t handle = 0;
    uint16_t index = 0;
    if (texture == 0) {
        return 0;
    }

    handle = rl_handle_pool_alloc(&rl_sprite3d_pool);
    if (handle == 0)
    {
        log_error("MAX_SPRITE3D reached (%u)", MAX_SPRITE3D);
        rl_texture_destroy(texture);
        return 0;
    }
    rl_handle_pool_resolve(&rl_sprite3d_pool, handle, &index);

    rl_sprite3d[index].texture = texture;
    rl_sprite3d[index].position_x = 0.0f;
    rl_sprite3d[index].position_y = 0.0f;
    rl_sprite3d[index].position_z = 0.0f;
    rl_sprite3d[index].size = 1.0f;
    rl_sprite3d[index].in_use = true;

    return handle;
}

RL_KEEP
rl_handle_t rl_sprite3d_create_from_texture(rl_handle_t texture)
{
    rl_handle_t handle = 0;
    uint16_t index = 0;
    if (!rl_texture_retain(texture)) {
        log_error("Invalid texture handle (%u) for rl_sprite3d_create_from_texture", texture);
        return 0;
    }

    handle = rl_handle_pool_alloc(&rl_sprite3d_pool);
    if (handle == 0) {
        log_error("MAX_SPRITE3D reached (%u)", MAX_SPRITE3D);
        rl_texture_release(texture);
        return 0;
    }
    rl_handle_pool_resolve(&rl_sprite3d_pool, handle, &index);

    rl_sprite3d[index].texture = texture;
    rl_sprite3d[index].position_x = 0.0f;
    rl_sprite3d[index].position_y = 0.0f;
    rl_sprite3d[index].position_z = 0.0f;
    rl_sprite3d[index].size = 1.0f;
    rl_sprite3d[index].in_use = true;
    return handle;
}

RL_KEEP
bool rl_sprite3d_set_transform(rl_handle_t handle,
                               float position_x, float position_y,
                               float position_z, float size)
{
    rl_sprite3d_t *sprite = rl_sprite3d_get(handle);

    if (sprite == NULL) {
        return false;
    }

    sprite->position_x = position_x;
    sprite->position_y = position_y;
    sprite->position_z = position_z;
    sprite->size = size;
    return true;
}

RL_KEEP
void rl_sprite3d_draw(rl_handle_t handle, rl_handle_t tint)
{
    rl_sprite3d_t *sprite = rl_sprite3d_get(handle);
    Texture2D *texture = NULL;
    Camera3D camera = {0};
    if (sprite == NULL)
    {
        return;
    }
    texture = rl_texture_get_ptr(sprite->texture);
    if (texture == NULL) {
        log_error("Missing texture for sprite3d handle (%u)", handle);
        return;
    }
    if (!rl_camera3d_get_active_camera(&camera))
    {
        log_error("rl_sprite3d_draw() requires an active 3D camera (call rl_begin_mode_3d first)");
        return;
    }

    DrawBillboard(camera,
                  *texture,
                  (Vector3){sprite->position_x, sprite->position_y, sprite->position_z},
                  sprite->size,
                  rl_color_get(tint));
}

RL_KEEP
void rl_sprite3d_destroy(rl_handle_t handle)
{
    rl_sprite3d_t *sprite = rl_sprite3d_get(handle);
    if (sprite == NULL)
    {
        return;
    }
    rl_texture_release(sprite->texture);
    sprite->texture = 0;
    sprite->in_use = false;
    rl_handle_pool_free(&rl_sprite3d_pool, handle);
}

bool rl_sprite3d_get_ray_collision_ex(rl_handle_t handle,
                                      Camera3D camera,
                                      Ray ray,
                                      float position_x,
                                      float position_y,
                                      float position_z,
                                      float size,
                                      RayCollision *collision,
                                      bool *broadphase_tested,
                                      bool *broadphase_rejected,
                                      bool *narrowphase_ran)
{
    rl_sprite3d_t *sprite = rl_sprite3d_get(handle);
    Texture2D *texture = NULL;
    Vector2 billboard_size = {0};
    Vector3 up = {0.0f, 1.0f, 0.0f};
    Vector2 origin = {0};
    Matrix mat_view = {0};
    Vector3 right = {0};
    Vector3 up_scaled = {0};
    Vector3 origin3d = {0};
    Vector3 position = {position_x, position_y, position_z};
    Vector3 points[4] = {0};

    if (collision == NULL) {
        return false;
    }
    if (broadphase_tested != NULL) *broadphase_tested = false;
    if (broadphase_rejected != NULL) *broadphase_rejected = false;
    if (narrowphase_ran != NULL) *narrowphase_ran = false;
    *collision = (RayCollision){0};

    if (sprite == NULL) {
        return false;
    }

    texture = rl_texture_get_ptr(sprite->texture);
    if (texture == NULL || texture->height == 0 || fabsf(size) <= 0.00001f) {
        return false;
    }

    billboard_size = (Vector2){size * fabsf((float)texture->width / (float)texture->height), size};
    {
        float half_width = fabsf(billboard_size.x) * 0.5f;
        float half_height = fabsf(billboard_size.y) * 0.5f;
        float radius = sqrtf((half_width * half_width) + (half_height * half_height));
        if (broadphase_tested != NULL) *broadphase_tested = true;
        RayCollision broad_hit = GetRayCollisionSphere(ray, position, radius);
        if (!broad_hit.hit) {
            if (broadphase_rejected != NULL) *broadphase_rejected = true;
            return true;
        }
    }

    origin = Vector2Scale(billboard_size, 0.5f);

    mat_view = MatrixLookAt(camera.position, camera.target, camera.up);
    right = (Vector3){mat_view.m0, mat_view.m4, mat_view.m8};
    right = Vector3Scale(right, billboard_size.x);
    up_scaled = Vector3Scale(up, billboard_size.y);

    origin3d = Vector3Add(
        Vector3Scale(Vector3Normalize(right), origin.x),
        Vector3Scale(Vector3Normalize(up_scaled), origin.y)
    );

    points[0] = Vector3Zero();
    points[1] = right;
    points[2] = Vector3Add(up_scaled, right);
    points[3] = up_scaled;

    for (int i = 0; i < 4; i++) {
        points[i] = Vector3Subtract(points[i], origin3d);
        points[i] = Vector3Add(points[i], position);
    }

    if (narrowphase_ran != NULL) *narrowphase_ran = true;
    *collision = GetRayCollisionQuad(ray, points[0], points[1], points[2], points[3]);
    return true;
}

bool rl_sprite3d_get_ray_collision(rl_handle_t handle,
                                   Camera3D camera,
                                   Ray ray,
                                   float position_x,
                                   float position_y,
                                   float position_z,
                                   float size,
                                   RayCollision *collision)
{
    return rl_sprite3d_get_ray_collision_ex(handle,
                                            camera,
                                            ray,
                                            position_x,
                                            position_y,
                                            position_z,
                                            size,
                                            collision,
                                            NULL,
                                            NULL,
                                            NULL);
}

void rl_sprite3d_init(void)
{
    rl_handle_pool_init(&rl_sprite3d_pool,
                        MAX_SPRITE3D,
                        rl_sprite3d_free_indices,
                        MAX_SPRITE3D,
                        rl_sprite3d_generations,
                        rl_sprite3d_occupied);
    for (int i = 0; i < MAX_SPRITE3D; i++)
    {
        rl_sprite3d[i].in_use = false;
        rl_sprite3d[i].texture = 0;
        rl_sprite3d[i].position_x = 0.0f;
        rl_sprite3d[i].position_y = 0.0f;
        rl_sprite3d[i].position_z = 0.0f;
        rl_sprite3d[i].size = 1.0f;
    }
}

void rl_sprite3d_deinit(void)
{
    int unloaded = 0;
    for (uint16_t i = 1; i < MAX_SPRITE3D; i++)
    {
        if (!rl_sprite3d[i].in_use) {
            continue;
        }
        {
            rl_handle_t handle = rl_handle_pool_handle_from_index(&rl_sprite3d_pool, i);
            if (handle == 0) {
                continue;
            }
            rl_sprite3d_destroy(handle);
            unloaded++;
        }
    }
    rl_handle_pool_reset(&rl_sprite3d_pool);
    log_info("rl_sprite3d_deinit: Freed %d sprite3d textures", unloaded);
}
