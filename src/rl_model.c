#include "rl_model.h"

#include <math.h>
#include <raylib.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "internal/exports.h"
#include "internal/rl_color_store.h"
#include "path/path.h"

#define MAX_MODELS 255
#define MAX_MODEL_ASSETS 255
#define RL_MODEL_FRAMERATE 60.0f

/*
 * Model system layout:
 * - rl_model_asset_t is shared GPU/animation data loaded from a source file.
 * - rl_model_instance_t is per-handle runtime state (animation time, loop mode, etc).
 * Multiple model handles can point at the same asset and only free it when
 * the last instance releases it.
 */
typedef struct
{
    bool in_use;
    Model *model;
    ModelAnimation *animations;
    int animation_count;
    unsigned int ref_count;
    char source_path[256];
    bool has_source_path;
} rl_model_asset_t;

typedef struct
{
    bool in_use;
    rl_handle_t asset_handle;
    int selected_animation;
    float animation_time;
    float animation_speed;
    bool animation_loop;
    bool animation_playing;
    bool animation_gpu_warning_emitted;
} rl_model_instance_t;

static rl_model_asset_t rl_model_assets[MAX_MODEL_ASSETS];
static rl_model_instance_t rl_model_instances[MAX_MODELS];

static rl_handle_t rl_next_model_handle = 1;
static rl_handle_t rl_next_asset_handle = 1;

static bool rl_model_is_valid_model(Model model)
{
    return (model.meshCount > 0 && model.meshes != NULL);
}

static void rl_model_log_invalid_details(const char *filename, Model model)
{
    fprintf(stderr, "Model validity check failed for %s\n", filename ? filename : "(null)");
    fprintf(stderr, "  model.meshes != NULL: %s\n", model.meshes ? "true" : "false");
    fprintf(stderr, "  model.materials != NULL: %s\n", model.materials ? "true" : "false");
    fprintf(stderr, "  model.meshMaterial != NULL: %s\n", model.meshMaterial ? "true" : "false");
    fprintf(stderr, "  model.meshCount: %d\n", model.meshCount);
    fprintf(stderr, "  model.materialCount: %d\n", model.materialCount);
}

static void rl_model_asset_reset(rl_model_asset_t *asset)
{
    if (asset == NULL) {
        return;
    }
    asset->in_use = false;
    asset->model = NULL;
    asset->animations = NULL;
    asset->animation_count = 0;
    asset->ref_count = 0;
    asset->source_path[0] = '\0';
    asset->has_source_path = false;
}

static void rl_model_instance_reset(rl_model_instance_t *instance)
{
    if (instance == NULL) {
        return;
    }
    instance->in_use = false;
    instance->asset_handle = 0;
    instance->selected_animation = -1;
    instance->animation_time = 0.0f;
    instance->animation_speed = 1.0f;
    instance->animation_loop = true;
    instance->animation_playing = false;
    instance->animation_gpu_warning_emitted = false;
}

static rl_model_asset_t *rl_model_asset_get(rl_handle_t handle)
{
    if (handle == 0 || handle >= MAX_MODEL_ASSETS) {
        return NULL;
    }
    if (!rl_model_assets[handle].in_use) {
        return NULL;
    }
    return &rl_model_assets[handle];
}

static rl_model_instance_t *rl_model_instance_get(rl_handle_t handle)
{
    if (handle == 0 || handle >= MAX_MODELS) {
        return NULL;
    }
    if (!rl_model_instances[handle].in_use) {
        return NULL;
    }
    return &rl_model_instances[handle];
}

static rl_handle_t rl_model_find_free_instance_handle(void)
{
    // Reuse holes first; placeholder to wrapped scan to avoid unbounded growth.
    for (rl_handle_t i = rl_next_model_handle; i < MAX_MODELS; i++) {
        if (!rl_model_instances[i].in_use) {
            rl_next_model_handle = i + 1;
            return i;
        }
    }
    for (rl_handle_t i = 1; i < rl_next_model_handle; i++) {
        if (!rl_model_instances[i].in_use) {
            rl_next_model_handle = i + 1;
            return i;
        }
    }
    return 0;
}

static rl_handle_t rl_model_find_free_asset_handle(void)
{
    // Reuse holes first; placeholder to wrapped scan to avoid unbounded growth.
    for (rl_handle_t i = rl_next_asset_handle; i < MAX_MODEL_ASSETS; i++) {
        if (!rl_model_assets[i].in_use) {
            rl_next_asset_handle = i + 1;
            return i;
        }
    }
    for (rl_handle_t i = 1; i < rl_next_asset_handle; i++) {
        if (!rl_model_assets[i].in_use) {
            rl_next_asset_handle = i + 1;
            return i;
        }
    }
    return 0;
}

static rl_handle_t rl_model_find_asset_by_path(const char *normalized_path)
{
    if (!normalized_path || normalized_path[0] == '\0') {
        return 0;
    }

    for (rl_handle_t i = 1; i < MAX_MODEL_ASSETS; i++)
    {
        if (!rl_model_assets[i].in_use || !rl_model_assets[i].has_source_path) {
            continue;
        }
        if (strcmp(rl_model_assets[i].source_path, normalized_path) == 0) {
            return i;
        }
    }
    return 0;
}

/*
 * Asset lifecycle:
 * - one asset owns loaded model + optional animation clip array
 * - instances retain/release assets and keep per-entity playback state
 */
static void rl_model_asset_release(rl_handle_t asset_handle)
{
    rl_model_asset_t *asset = rl_model_asset_get(asset_handle);
    if (asset == NULL) {
        return;
    }

    if (asset->ref_count > 0) {
        asset->ref_count--;
    }

    if (asset->ref_count == 0)
    {
        if (asset->animations != NULL && asset->animation_count > 0) {
            UnloadModelAnimations(asset->animations, asset->animation_count);
        }
        if (asset->model != NULL) {
            UnloadModel(*(asset->model));
            free(asset->model);
        }
        rl_model_asset_reset(asset);
    }
}

static rl_handle_t rl_model_asset_create(Model model,
                                         ModelAnimation *animations,
                                         int animation_count,
                                         const char *normalized_path,
                                         bool cache_by_path)
{
    rl_handle_t handle = rl_model_find_free_asset_handle();
    rl_model_asset_t *asset = NULL;

    if (handle == 0) {
        fprintf(stderr, "ERROR: MAX_MODEL_ASSETS reached (%d)\n", MAX_MODEL_ASSETS);
        if (animations != NULL && animation_count > 0) {
            UnloadModelAnimations(animations, animation_count);
        }
        UnloadModel(model);
        return 0;
    }

    asset = &rl_model_assets[handle];
    rl_model_asset_reset(asset);

    asset->model = malloc(sizeof(Model));
    if (asset->model == NULL)
    {
        fprintf(stderr, "ERROR: Failed to allocate model asset storage\n");
        if (animations != NULL && animation_count > 0) {
            UnloadModelAnimations(animations, animation_count);
        }
        UnloadModel(model);
        return 0;
    }

    *(asset->model) = model;
    asset->animations = animations;
    asset->animation_count = animation_count;
    asset->ref_count = 1;
    asset->in_use = true;

    if (cache_by_path && normalized_path != NULL) {
        snprintf(asset->source_path, sizeof(asset->source_path), "%s", normalized_path);
        asset->has_source_path = true;
    }

    return handle;
}

static rl_handle_t rl_model_instance_create(rl_handle_t asset_handle)
{
    rl_handle_t handle = rl_model_find_free_instance_handle();
    rl_model_instance_t *instance = NULL;
    rl_model_asset_t *asset = rl_model_asset_get(asset_handle);

    if (asset == NULL) {
        return 0;
    }

    if (handle == 0) {
        fprintf(stderr, "ERROR: MAX_MODELS reached (%d)\n", MAX_MODELS);
        return 0;
    }

    instance = &rl_model_instances[handle];
    rl_model_instance_reset(instance);
    instance->in_use = true;
    instance->asset_handle = asset_handle;

    if (asset->animation_count > 0) {
        instance->selected_animation = 0;
        instance->animation_playing = true;
    }

    return handle;
}

static bool rl_model_prepare_animation_gpu_state(rl_model_instance_t *instance, Model *model, rl_handle_t handle)
{
    if (instance == NULL || model == NULL || !IsWindowReady()) {
        return false;
    }

    // Animated update requires both CPU anim arrays and GPU VBOs.
    // If normal VBO is missing we can still animate positions; we just disable
    // animated normals once to avoid repeated per-frame warnings.
    for (int m = 0; m < model->meshCount; m++)
    {
        Mesh *mesh = &model->meshes[m];

        if ((mesh->boneWeights == NULL) || (mesh->boneIndices == NULL) ||
            (mesh->animVertices == NULL) || (mesh->animNormals == NULL)) {
            continue;
        }

        if ((mesh->vboId == NULL) || (mesh->vboId[SHADER_LOC_VERTEX_POSITION] == 0))
        {
            if (!instance->animation_gpu_warning_emitted)
            {
                fprintf(stderr,
                        "WARNING: Skipping model animation, missing position VBO for handle %u mesh %d\n",
                        handle, m);
                instance->animation_gpu_warning_emitted = true;
            }
            return false;
        }

        if ((mesh->normals != NULL) && (mesh->vboId[SHADER_LOC_VERTEX_NORMAL] == 0))
        {
            if (!instance->animation_gpu_warning_emitted)
            {
                fprintf(stderr,
                        "WARNING: Model animation normals disabled for handle %u mesh %d (missing normal VBO)\n",
                        handle, m);
                instance->animation_gpu_warning_emitted = true;
            }
            mesh->normals = NULL;
        }
    }

    return true;
}

RL_KEEP
rl_handle_t rl_model_create(const char *filename)
{
    char normalized_path[256] = {0};
    rl_handle_t asset_handle = 0;
    rl_handle_t instance_handle = 0;
    Model loaded_model = {0};
    ModelAnimation *animations = NULL;
    int animation_count = 0;
    bool using_placeholder = false;

    if (!filename || filename[0] == '\0') {
        return 0;
    }

    if (!IsWindowReady()) {
        fprintf(stderr, "ERROR: rl_model_create(%s) called before window/context is ready\n", filename);
        return 0;
    }

    path_normalize(filename, normalized_path, sizeof(normalized_path));

    // Reuse successfully loaded source assets by path.
    asset_handle = rl_model_find_asset_by_path(normalized_path);
    if (asset_handle != 0)
    {
        rl_model_assets[asset_handle].ref_count++;
        instance_handle = rl_model_instance_create(asset_handle);
        if (instance_handle == 0) {
            rl_model_asset_release(asset_handle);
        }
        return instance_handle;
    }

    loaded_model = LoadModel(normalized_path);
    if (!rl_model_is_valid_model(loaded_model))
    {
        rl_model_log_invalid_details(normalized_path, loaded_model);
        fprintf(stderr, "ERROR: Failed to load model (%s). Substituting placeholder.\n", normalized_path);
        if (loaded_model.meshCount > 0 || loaded_model.materialCount > 0) {
            UnloadModel(loaded_model);
        }

        loaded_model = LoadModelFromMesh(GenMeshCube(1.0f, 1.0f, 1.0f));
        if (!rl_model_is_valid_model(loaded_model)) {
            fprintf(stderr, "ERROR: Failed to create placeholder model for (%s)\n", normalized_path);
            return 0;
        }
        using_placeholder = true; // Placeholder instance; caller can still render something visible.
    }

    if (!using_placeholder)
    {
        animations = LoadModelAnimations(normalized_path, &animation_count);
        if (animations == NULL || animation_count <= 0) {
            animations = NULL;
            animation_count = 0;
        }
    }

    // Do not cache placeholder assets by path so future create calls can retry real loads.
    asset_handle = rl_model_asset_create(loaded_model,
                                         animations,
                                         animation_count,
                                         normalized_path,
                                         !using_placeholder);
    if (asset_handle == 0) {
        return 0;
    }

    instance_handle = rl_model_instance_create(asset_handle);
    if (instance_handle == 0)
    {
        rl_model_asset_release(asset_handle);
        return 0;
    }

    return instance_handle;
}

RL_KEEP
void rl_model_destroy(rl_handle_t handle)
{
    rl_model_instance_t *instance = rl_model_instance_get(handle);
    if (instance == NULL) {
        return;
    }

    rl_model_asset_release(instance->asset_handle);
    rl_model_instance_reset(instance);
}

RL_KEEP
int rl_model_animation_count(rl_handle_t handle)
{
    rl_model_instance_t *instance = rl_model_instance_get(handle);
    rl_model_asset_t *asset = NULL;

    if (instance == NULL) {
        return 0;
    }

    asset = rl_model_asset_get(instance->asset_handle);
    if (asset == NULL) {
        return 0;
    }

    return asset->animation_count;
}

RL_KEEP
int rl_model_animation_frame_count(rl_handle_t handle, int animation_index)
{
    rl_model_instance_t *instance = rl_model_instance_get(handle);
    rl_model_asset_t *asset = NULL;

    if (instance == NULL) {
        return 0;
    }

    asset = rl_model_asset_get(instance->asset_handle);
    if (asset == NULL) {
        return 0;
    }

    if (animation_index < 0 || animation_index >= asset->animation_count) {
        return 0;
    }

    return asset->animations[animation_index].keyframeCount;
}

RL_KEEP
void rl_model_animation_update(rl_handle_t handle, int animation_index, int frame)
{
    rl_model_instance_t *instance = rl_model_instance_get(handle);
    rl_model_asset_t *asset = NULL;
    int frame_count = 0;
    int normalized_frame = 0;

    if (instance == NULL) {
        return;
    }

    asset = rl_model_asset_get(instance->asset_handle);
    if (asset == NULL) {
        return;
    }

    if (animation_index < 0 || animation_index >= asset->animation_count) {
        return;
    }

    frame_count = asset->animations[animation_index].keyframeCount;
    if (frame_count <= 0) {
        return;
    }

    if (!rl_model_prepare_animation_gpu_state(instance, asset->model, handle)) {
        return;
    }

    normalized_frame = frame % frame_count;
    if (normalized_frame < 0) {
        normalized_frame += frame_count;
    }

    UpdateModelAnimation(*(asset->model), asset->animations[animation_index], normalized_frame);
    instance->selected_animation = animation_index;
    instance->animation_time = (float)normalized_frame;
    instance->animation_playing = true;
}

RL_KEEP
bool rl_model_set_animation(rl_handle_t handle, int animation_index)
{
    rl_model_instance_t *instance = rl_model_instance_get(handle);
    rl_model_asset_t *asset = NULL;

    if (instance == NULL) {
        return false;
    }

    asset = rl_model_asset_get(instance->asset_handle);
    if (asset == NULL || asset->animation_count <= 0) {
        return false;
    }

    if (animation_index < 0 || animation_index >= asset->animation_count) {
        return false;
    }

    instance->selected_animation = animation_index;
    instance->animation_time = 0.0f;
    instance->animation_playing = true;
    return true;
}

RL_KEEP
bool rl_model_set_animation_speed(rl_handle_t handle, float speed)
{
    rl_model_instance_t *instance = rl_model_instance_get(handle);
    if (instance == NULL) {
        return false;
    }

    instance->animation_speed = speed;
    return true;
}

RL_KEEP
bool rl_model_set_animation_loop(rl_handle_t handle, bool should_loop)
{
    rl_model_instance_t *instance = rl_model_instance_get(handle);
    if (instance == NULL) {
        return false;
    }

    instance->animation_loop = should_loop;
    return true;
}

RL_KEEP
bool rl_model_animate(rl_handle_t handle, float delta_seconds)
{
    rl_model_instance_t *instance = rl_model_instance_get(handle);
    rl_model_asset_t *asset = NULL;
    int frame_count = 0;
    int frame = 0;

    if (instance == NULL) {
        return false;
    }

    asset = rl_model_asset_get(instance->asset_handle);
    if (asset == NULL || asset->animation_count <= 0) {
        return false;
    }

    if (instance->selected_animation < 0 || instance->selected_animation >= asset->animation_count) {
        return false;
    }
    if (!instance->animation_playing) {
        return false;
    }
    if (instance->animation_speed <= 0.0f || delta_seconds <= 0.0f) {
        return false;
    }

    frame_count = asset->animations[instance->selected_animation].keyframeCount;
    if (frame_count <= 0) {
        return false;
    }

    if (!rl_model_prepare_animation_gpu_state(instance, asset->model, handle)) {
        return false;
    }

    instance->animation_time += delta_seconds * (RL_MODEL_FRAMERATE * instance->animation_speed);

    if (instance->animation_loop)
    {
        while (instance->animation_time >= (float)frame_count) {
            instance->animation_time -= (float)frame_count;
        }
        while (instance->animation_time < 0.0f) {
            instance->animation_time += (float)frame_count;
        }
        frame = (int)floorf(instance->animation_time);
    }
    else
    {
        frame = (int)floorf(instance->animation_time);
        if (frame >= frame_count)
        {
            frame = frame_count - 1;
            instance->animation_time = (float)frame;
            instance->animation_playing = false;
        }
        else if (frame < 0)
        {
            frame = 0;
            instance->animation_time = 0.0f;
        }
    }

    UpdateModelAnimation(*(asset->model), asset->animations[instance->selected_animation], frame);
    return true;
}

RL_KEEP
void rl_model_draw(rl_handle_t handle, float position_x, float position_y, float position_z, float scale, rl_handle_t tint)
{
    rl_model_instance_t *instance = rl_model_instance_get(handle);
    rl_model_asset_t *asset = NULL;

    if (instance == NULL) {
        fprintf(stderr, "ERROR: Invalid model handle (%d)\n", handle);
        return;
    }

    asset = rl_model_asset_get(instance->asset_handle);
    if (asset == NULL || asset->model == NULL) {
        fprintf(stderr, "ERROR: Missing model asset for handle (%d)\n", handle);
        return;
    }

    DrawModel(*(asset->model), (Vector3){position_x, position_y, position_z}, scale, rl_color_get(tint));
}

RL_KEEP
bool rl_model_is_valid(rl_handle_t handle)
{
    rl_model_instance_t *instance = rl_model_instance_get(handle);
    rl_model_asset_t *asset = NULL;

    if (instance == NULL) {
        return false;
    }

    asset = rl_model_asset_get(instance->asset_handle);
    if (asset == NULL || asset->model == NULL) {
        return false;
    }

    return rl_model_is_valid_model(*(asset->model));
}

RL_KEEP
bool rl_model_is_valid_strict(rl_handle_t handle)
{
    rl_model_instance_t *instance = rl_model_instance_get(handle);
    rl_model_asset_t *asset = NULL;

    if (instance == NULL) {
        return false;
    }

    asset = rl_model_asset_get(instance->asset_handle);
    if (asset == NULL || asset->model == NULL) {
        return false;
    }

    return IsModelValid(*(asset->model));
}

void rl_model_init(void)
{
    for (int i = 0; i < MAX_MODEL_ASSETS; i++) {
        rl_model_asset_reset(&rl_model_assets[i]);
    }

    for (int i = 0; i < MAX_MODELS; i++) {
        rl_model_instance_reset(&rl_model_instances[i]);
    }

    rl_next_asset_handle = 1;
    rl_next_model_handle = 1;
}

void rl_model_deinit(void)
{
    int assets_freed = 0;

    for (rl_handle_t i = 1; i < MAX_MODELS; i++) {
        if (rl_model_instances[i].in_use) {
            rl_model_destroy(i);
        }
    }

    for (rl_handle_t i = 1; i < MAX_MODEL_ASSETS; i++) {
        if (rl_model_assets[i].in_use) {
            rl_model_asset_release(i);
            assets_freed++;
        }
    }

    rl_next_asset_handle = 1;
    rl_next_model_handle = 1;

    printf("rl_model_deinit: Freed %d model assets\n", assets_freed);
}
