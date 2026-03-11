#include "rl_texture.h"

#include <raylib.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#include "internal/exports.h"
#include "internal/rl_handle_pool.h"
#include "internal/rl_texture_store.h"
#include "logger/log.h"
#include "path/path.h"

#define MAX_TEXTURES 1024
#define RL_TEXTURE_PLACEHOLDER_KEY "<placeholder:magenta>"

typedef struct
{
    bool in_use;
    Texture2D texture;
    unsigned int ref_count;
    char path[256];
} rl_texture_entry_t;

// Texture handles are shared assets:
// - same normalized path returns the same handle
// - retain/release refcount controls GPU texture lifetime
// This avoids duplicate GPU allocations when multiple systems reuse a texture.

static rl_texture_entry_t rl_textures[MAX_TEXTURES];
static rl_handle_pool_t rl_texture_pool;
static uint16_t rl_texture_free_indices[MAX_TEXTURES];
static uint16_t rl_texture_generations[MAX_TEXTURES];
static unsigned char rl_texture_occupied[MAX_TEXTURES];

static rl_texture_entry_t *rl_texture_get_entry(rl_handle_t handle)
{
    uint16_t index = 0;
    if (!rl_handle_pool_resolve(&rl_texture_pool, handle, &index)) {
        log_error("Invalid texture handle (%u)", (unsigned int)handle);
        return NULL;
    }
    if (!rl_textures[index].in_use) {
        log_error("Stale texture handle (%u)", (unsigned int)handle);
        return NULL;
    }
    return &rl_textures[index];
}

static rl_handle_t rl_texture_find_by_path(const char *normalized_path)
{
    for (uint16_t i = 1; i < MAX_TEXTURES; i++) {
        if (!rl_textures[i].in_use) {
            continue;
        }
        if (strcmp(rl_textures[i].path, normalized_path) == 0) {
            return rl_handle_pool_handle_from_index(&rl_texture_pool, i);
        }
    }
    return 0;
}

static Texture2D rl_texture_create_magenta_placeholder(void)
{
    Image image = GenImageColor(2, 2, (Color){255, 0, 255, 255});
    Texture2D texture = LoadTextureFromImage(image);
    UnloadImage(image);
    return texture;
}

Texture2D *rl_texture_get_ptr(rl_handle_t handle)
{
    rl_texture_entry_t *entry = rl_texture_get_entry(handle);
    if (entry == NULL) {
        return NULL;
    }
    return &entry->texture;
}

bool rl_texture_retain(rl_handle_t handle)
{
    rl_texture_entry_t *entry = rl_texture_get_entry(handle);
    if (entry == NULL) {
        return false;
    }
    entry->ref_count++;
    return true;
}

void rl_texture_release(rl_handle_t handle)
{
    rl_texture_entry_t *entry = rl_texture_get_entry(handle);
    if (entry == NULL) {
        return;
    }
    if (entry->ref_count > 0) {
        entry->ref_count--;
    }
    if (entry->ref_count == 0) {
        UnloadTexture(entry->texture);
        entry->texture = (Texture2D){0};
        entry->in_use = false;
        entry->path[0] = '\0';
        rl_handle_pool_free(&rl_texture_pool, handle);
    }
}

RL_KEEP
rl_handle_t rl_texture_create(const char *filename)
{
    char normalized_path[256] = {0};
    rl_handle_t handle = 0;
    Texture2D texture = {0};
    uint16_t index = 0;

    if (!filename || filename[0] == '\0') {
        return 0;
    }
    if (!IsWindowReady()) {
        log_error("rl_texture_create(%s) called before window/context is ready", filename);
        return 0;
    }

    path_normalize(filename, normalized_path, sizeof(normalized_path));
    handle = rl_texture_find_by_path(normalized_path);
    if (handle != 0) {
        rl_texture_retain(handle);
        return handle;
    }

    handle = rl_handle_pool_alloc(&rl_texture_pool);
    if (handle == 0) {
        log_error("MAX_TEXTURES reached (%d)", MAX_TEXTURES);
        return 0;
    }
    rl_handle_pool_resolve(&rl_texture_pool, handle, &index);

    texture = LoadTexture(normalized_path);
    if (!IsTextureValid(texture)) {
        rl_handle_t placeholder_handle = rl_texture_find_by_path(RL_TEXTURE_PLACEHOLDER_KEY);

        log_error("Failed to load texture (%s). Using magenta placeholder.", normalized_path);

        if (placeholder_handle != 0) {
            rl_texture_retain(placeholder_handle);
            return placeholder_handle;
        }

        texture = rl_texture_create_magenta_placeholder();
        if (!IsTextureValid(texture)) {
            log_error("Failed to create magenta placeholder texture");
            rl_handle_pool_free(&rl_texture_pool, handle);
            return 0;
        }

        rl_textures[index].texture = texture;
        rl_textures[index].ref_count = 1;
        rl_textures[index].in_use = true;
        snprintf(rl_textures[index].path, sizeof(rl_textures[index].path), "%s", RL_TEXTURE_PLACEHOLDER_KEY);
        return handle;
    }

    rl_textures[index].texture = texture;
    rl_textures[index].ref_count = 1;
    rl_textures[index].in_use = true;
    snprintf(rl_textures[index].path, sizeof(rl_textures[index].path), "%s", normalized_path);
    return handle;
}

RL_KEEP
void rl_texture_destroy(rl_handle_t handle)
{
    rl_texture_release(handle);
}

void rl_texture_init(void)
{
    rl_handle_pool_init(&rl_texture_pool,
                        MAX_TEXTURES,
                        rl_texture_free_indices,
                        MAX_TEXTURES,
                        rl_texture_generations,
                        rl_texture_occupied);
    for (int i = 0; i < MAX_TEXTURES; i++) {
        rl_textures[i].in_use = false;
        rl_textures[i].texture = (Texture2D){0};
        rl_textures[i].ref_count = 0;
        rl_textures[i].path[0] = '\0';
    }
}

void rl_texture_deinit(void)
{
    int unloaded = 0;
    for (rl_handle_t i = 1; i < MAX_TEXTURES; i++) {
        if (!rl_textures[i].in_use) {
            continue;
        }
        UnloadTexture(rl_textures[i].texture);
        rl_textures[i].in_use = false;
        rl_textures[i].texture = (Texture2D){0};
        rl_textures[i].ref_count = 0;
        rl_textures[i].path[0] = '\0';
        unloaded++;
    }
    rl_handle_pool_reset(&rl_texture_pool);
    log_info("rl_texture_deinit: Freed %d textures", unloaded);
}
