#include "rl_sprite3d.h"

#include <raylib.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "internal/exports.h"
#include "internal/rl_camera3d_store.h"
#include "internal/rl_color_store.h"
#include "internal/rl_handle_pool.h"
#include "logger/log.h"
#include "rl_texture.h"
#include "internal/rl_texture_store.h"

#define MAX_SPRITE3D 1024

typedef struct
{
    bool in_use;
    rl_handle_t texture;
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
        return NULL;
    }
    if (!rl_sprite3d[index].in_use) {
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
    rl_sprite3d[index].in_use = true;
    return handle;
}

RL_KEEP
void rl_sprite3d_draw(rl_handle_t handle, float position_x, float position_y,
                      float position_z, float size, rl_handle_t tint)
{
    rl_sprite3d_t *sprite = rl_sprite3d_get(handle);
    Texture2D *texture = NULL;
    Camera3D camera = {0};
    if (sprite == NULL)
    {
        log_error("Invalid sprite3d handle (%u)", handle);
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

    DrawBillboard(camera, *texture, (Vector3){position_x, position_y, position_z}, size, rl_color_get(tint));
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
