#include "rl_sprite3d.h"

#include <raylib.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "internal/exports.h"
#include "internal/rl_camera3d_store.h"
#include "internal/rl_color_store.h"
#include "rl_texture.h"
#include "internal/rl_texture_store.h"

#define MAX_SPRITE3D 1024

typedef struct
{
    bool in_use;
    rl_handle_t texture;
} rl_sprite3d_t;

static rl_sprite3d_t rl_sprite3d[MAX_SPRITE3D];
static rl_handle_t rl_sprite3d_next_handle = 1;

rl_handle_t rl_sprite3d_get_next_handle(void)
{
    if (rl_sprite3d_next_handle >= MAX_SPRITE3D)
    {
        fprintf(stderr, "ERROR: MAX_SPRITE3D reached (%u)\n", rl_sprite3d_next_handle);
        return 0;
    }
    return rl_sprite3d_next_handle++;
}

static rl_sprite3d_t *rl_sprite3d_get(rl_handle_t handle)
{
    if (handle == 0 || handle >= MAX_SPRITE3D)
    {
        return NULL;
    }
    if (!rl_sprite3d[handle].in_use) {
        return NULL;
    }
    return &rl_sprite3d[handle];
}

RL_KEEP
rl_handle_t rl_sprite3d_create(const char *filename)
{
    rl_handle_t texture = rl_texture_create(filename);
    rl_handle_t handle = 0;
    if (texture == 0) {
        return 0;
    }

    handle = rl_sprite3d_get_next_handle();
    if (handle == 0)
    {
        rl_texture_destroy(texture);
        return 0;
    }

    rl_sprite3d[handle].texture = texture;
    rl_sprite3d[handle].in_use = true;

    return handle;
}

RL_KEEP
rl_handle_t rl_sprite3d_create_from_texture(rl_handle_t texture)
{
    rl_handle_t handle = 0;
    if (!rl_texture_retain(texture)) {
        fprintf(stderr, "ERROR: Invalid texture handle (%u) for rl_sprite3d_create_from_texture\n", texture);
        return 0;
    }

    handle = rl_sprite3d_get_next_handle();
    if (handle == 0) {
        rl_texture_release(texture);
        return 0;
    }

    rl_sprite3d[handle].texture = texture;
    rl_sprite3d[handle].in_use = true;
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
        fprintf(stderr, "ERROR: Invalid sprite3d handle (%u)\n", handle);
        return;
    }
    texture = rl_texture_get_ptr(sprite->texture);
    if (texture == NULL) {
        fprintf(stderr, "ERROR: Missing texture for sprite3d handle (%u)\n", handle);
        return;
    }
    if (!rl_camera3d_get_active_camera(&camera))
    {
        fprintf(stderr, "ERROR: rl_sprite3d_draw() requires an active 3D camera (call rl_begin_mode_3d first)\n");
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
}

void rl_sprite3d_init(void)
{
    for (int i = 0; i < MAX_SPRITE3D; i++)
    {
        rl_sprite3d[i].in_use = false;
        rl_sprite3d[i].texture = 0;
    }
    rl_sprite3d_next_handle = 1;
}

void rl_sprite3d_deinit(void)
{
    int unloaded = 0;
    for (rl_handle_t i = 1; i < MAX_SPRITE3D; i++)
    {
        if (rl_sprite3d[i].in_use)
        {
            rl_sprite3d_destroy(i);
            unloaded++;
        }
    }
    rl_sprite3d_next_handle = 1;
    printf("rl_sprite3d_deinit: Freed %d sprite3d textures\n", unloaded);
}
