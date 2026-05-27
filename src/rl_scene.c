#include "rl_scene.h"

#include <string.h>

#include <raylib.h>

#include "internal/exports.h"
#include "internal/rl_camera3d.h"
#include "internal/rl_handle_pool.h"
#include "internal/rl_model.h"
#include "internal/rl_pick_scene.h"
#include "internal/rl_scene.h"
#include "internal/rl_sprite3d.h"
#include "rl_camera3d.h"
#include "rl_handle.h"
#include "rl_model.h"
#include "rl_pick.h"
#include "rl_render.h"
#include "rl_scratch.h"
#include "rl_sprite2d.h"
#include "rl_sprite3d.h"
#include "rl_text2d.h"

#define MAX_SCENES 32
#define MAX_SCENE_MEMBERS 128

typedef struct
{
    rl_handle_t drawable;
    rl_handle_kind_t kind;
    int layer;
    uint32_t order;
} rl_scene_member_t;

typedef struct
{
    bool in_use;
    rl_handle_t camera;
    rl_scene_member_t members[MAX_SCENE_MEMBERS];
    int member_count;
    uint32_t next_order;
} rl_scene_instance_t;

static rl_scene_instance_t rl_scenes[MAX_SCENES];
static rl_handle_pool_t rl_scene_pool;
static uint16_t rl_scene_free_indices[MAX_SCENES];
static uint16_t rl_scene_generations[MAX_SCENES];
static unsigned char rl_scene_occupied[MAX_SCENES];

static rl_scene_instance_t *rl_scene_get(rl_handle_t scene)
{
    uint16_t index = 0;

    if (!rl_handle_pool_resolve(&rl_scene_pool, scene, &index)) {
        if (scene != 0) {
            log_warn("Invalid scene handle (%u)", (unsigned int)scene);
        }
        return NULL;
    }
    if (!rl_scenes[index].in_use) {
        log_warn("Stale scene handle (%u)", (unsigned int)scene);
        return NULL;
    }
    return &rl_scenes[index];
}

static bool rl_scene_is_drawable_kind(rl_handle_kind_t kind)
{
    switch (kind) {
    case RL_HANDLE_KIND_MODEL:
    case RL_HANDLE_KIND_SPRITE3D:
    case RL_HANDLE_KIND_SPRITE2D:
    case RL_HANDLE_KIND_TEXT2D:
        return true;
    default:
        return false;
    }
}

static bool rl_scene_is_drawable_valid(rl_handle_t drawable, rl_handle_kind_t kind)
{
    switch (kind) {
    case RL_HANDLE_KIND_MODEL:
        return rl_model_is_valid(drawable);
    case RL_HANDLE_KIND_SPRITE3D:
    case RL_HANDLE_KIND_SPRITE2D:
    case RL_HANDLE_KIND_TEXT2D:
        return true;
    default:
        return false;
    }
}

static int rl_scene_find_member(const rl_scene_instance_t *scene, rl_handle_t drawable)
{
    int i = 0;

    if (scene == NULL) {
        return -1;
    }

    for (i = 0; i < scene->member_count; i++) {
        if (scene->members[i].drawable == drawable) {
            return i;
        }
    }
    return -1;
}

static rl_handle_t rl_scene_resolve_camera(const rl_scene_instance_t *scene,
                                           rl_handle_t camera_param)
{
    if (camera_param != 0) {
        return camera_param;
    }
    if (scene != NULL && scene->camera != 0) {
        return scene->camera;
    }
    return rl_camera3d_get_active();
}

static void rl_scene_apply_camera(rl_handle_t camera)
{
    if (camera != 0) {
        (void)rl_camera3d_set_active(camera);
    }
}

static void rl_scene_sort_members(rl_scene_member_t *members, int count)
{
    int i = 0;
    int j = 0;

    for (i = 0; i < count - 1; i++) {
        for (j = i + 1; j < count; j++) {
            rl_scene_member_t tmp = {0};
            bool swap = false;

            if (members[j].layer < members[i].layer) {
                swap = true;
            } else if (members[j].layer == members[i].layer &&
                       members[j].order < members[i].order) {
                swap = true;
            }

            if (swap) {
                tmp = members[i];
                members[i] = members[j];
                members[j] = tmp;
            }
        }
    }
}

static void rl_scene_draw_member(rl_handle_t drawable, rl_handle_kind_t kind)
{
    switch (kind) {
    case RL_HANDLE_KIND_MODEL:
        rl_model_draw(drawable);
        break;
    case RL_HANDLE_KIND_SPRITE3D:
        rl_sprite3d_draw(drawable);
        break;
    case RL_HANDLE_KIND_SPRITE2D:
        rl_sprite2d_draw(drawable);
        break;
    case RL_HANDLE_KIND_TEXT2D:
        rl_text2d_draw(drawable);
        break;
    default:
        break;
    }
}

static bool rl_scene_kind_supports_narrow_pick(rl_handle_kind_t kind)
{
    return kind == RL_HANDLE_KIND_MODEL || kind == RL_HANDLE_KIND_SPRITE3D;
}

static bool rl_scene_drawable_instance_visible(rl_handle_t drawable, rl_handle_kind_t kind)
{
    switch (kind) {
    case RL_HANDLE_KIND_MODEL:
        return rl_model_is_visible(drawable);
    case RL_HANDLE_KIND_SPRITE3D:
        return rl_sprite3d_is_visible(drawable);
    case RL_HANDLE_KIND_SPRITE2D:
        return rl_sprite2d_is_visible(drawable);
    case RL_HANDLE_KIND_TEXT2D:
        return rl_text2d_is_visible(drawable);
    default:
        return false;
    }
}

RL_KEEP
rl_handle_t rl_scene_create(void)
{
    rl_handle_t handle = rl_handle_pool_alloc(&rl_scene_pool);
    uint16_t index = 0;

    if (handle == 0) {
        log_error("MAX_SCENES reached (%d)", MAX_SCENES);
        return 0;
    }

    rl_handle_pool_resolve(&rl_scene_pool, handle, &index);
    rl_scenes[index].camera = 0;
    rl_scenes[index].member_count = 0;
    rl_scenes[index].next_order = 0;
    rl_scenes[index].in_use = true;
    return handle;
}

RL_KEEP
void rl_scene_destroy(rl_handle_t scene)
{
    rl_scene_instance_t *instance = rl_scene_get(scene);

    if (instance == NULL) {
        return;
    }

    instance->camera = 0;
    instance->member_count = 0;
    instance->next_order = 0;
    instance->in_use = false;
    rl_handle_pool_free(&rl_scene_pool, scene);
}

RL_KEEP
bool rl_scene_add(rl_handle_t scene, rl_handle_t drawable, int layer)
{
    rl_scene_instance_t *instance = rl_scene_get(scene);
    rl_handle_kind_t kind = RL_HANDLE_KIND_NONE;
    rl_scene_member_t *member = NULL;

    if (instance == NULL || drawable == 0) {
        return false;
    }

    kind = rl_handle_get_kind(drawable);
    if (!rl_scene_is_drawable_kind(kind)) {
        log_warn("rl_scene_add: unsupported drawable kind (%d) for handle (%u)",
                 (int)kind, (unsigned int)drawable);
        return false;
    }

    if (rl_scene_find_member(instance, drawable) >= 0) {
        return false;
    }

    if (instance->member_count >= MAX_SCENE_MEMBERS) {
        log_error("rl_scene_add: MAX_SCENE_MEMBERS reached (%d)", MAX_SCENE_MEMBERS);
        return false;
    }

    member = &instance->members[instance->member_count++];
    member->drawable = drawable;
    member->kind = kind;
    member->layer = layer;
    member->order = instance->next_order++;
    return true;
}

RL_KEEP
bool rl_scene_set_layer(rl_handle_t scene, rl_handle_t drawable, int layer)
{
    rl_scene_instance_t *instance = rl_scene_get(scene);
    int index = 0;

    if (instance == NULL || drawable == 0) {
        return false;
    }

    index = rl_scene_find_member(instance, drawable);
    if (index < 0) {
        return false;
    }

    instance->members[index].layer = layer;
    return true;
}

RL_KEEP
bool rl_scene_remove(rl_handle_t scene, rl_handle_t drawable)
{
    rl_scene_instance_t *instance = rl_scene_get(scene);
    int index = 0;

    if (instance == NULL) {
        return false;
    }

    index = rl_scene_find_member(instance, drawable);
    if (index < 0) {
        return false;
    }

    instance->member_count--;
    if (index < instance->member_count) {
        instance->members[index] = instance->members[instance->member_count];
    }
    return true;
}

RL_KEEP
void rl_scene_clear(rl_handle_t scene)
{
    rl_scene_instance_t *instance = rl_scene_get(scene);

    if (instance == NULL) {
        return;
    }

    instance->member_count = 0;
    instance->next_order = 0;
}

RL_KEEP
void rl_scene_set_active_camera(rl_handle_t scene, rl_handle_t camera)
{
    rl_scene_instance_t *instance = rl_scene_get(scene);

    if (instance == NULL) {
        return;
    }

    instance->camera = camera;
}

RL_KEEP
void rl_scene_draw(rl_handle_t scene)
{
    rl_scene_instance_t *instance = rl_scene_get(scene);
    rl_scene_member_t sorted[MAX_SCENE_MEMBERS];
    rl_handle_t camera = 0;
    int i = 0;
    bool has_3d = false;
    bool has_2d = false;

    if (instance == NULL) {
        return;
    }

    if (instance->member_count <= 0) {
        return;
    }

    memcpy(sorted, instance->members,
           (size_t)instance->member_count * sizeof(sorted[0]));
    rl_scene_sort_members(sorted, instance->member_count);

    camera = rl_scene_resolve_camera(instance, 0);
    rl_scene_apply_camera(camera);

    for (i = 0; i < instance->member_count; i++) {
        if (!rl_scene_drawable_instance_visible(sorted[i].drawable, sorted[i].kind)) {
            continue;
        }
        if (!rl_scene_is_drawable_valid(sorted[i].drawable, sorted[i].kind)) {
            continue;
        }
        if (sorted[i].kind == RL_HANDLE_KIND_MODEL ||
            sorted[i].kind == RL_HANDLE_KIND_SPRITE3D) {
            has_3d = true;
        } else {
            has_2d = true;
        }
    }

    if (has_3d) {
        rl_render_begin_mode_3d();
        for (i = 0; i < instance->member_count; i++) {
            if (sorted[i].kind != RL_HANDLE_KIND_MODEL &&
                sorted[i].kind != RL_HANDLE_KIND_SPRITE3D) {
                continue;
            }
            if (!rl_scene_drawable_instance_visible(sorted[i].drawable, sorted[i].kind)) {
                continue;
            }
            if (!rl_scene_is_drawable_valid(sorted[i].drawable, sorted[i].kind)) {
                continue;
            }
            rl_scene_draw_member(sorted[i].drawable, sorted[i].kind);
        }
        rl_render_end_mode_3d();
    }

    if (has_2d) {
        for (i = 0; i < instance->member_count; i++) {
            if (sorted[i].kind != RL_HANDLE_KIND_SPRITE2D &&
                sorted[i].kind != RL_HANDLE_KIND_TEXT2D) {
                continue;
            }
            if (!rl_scene_drawable_instance_visible(sorted[i].drawable, sorted[i].kind)) {
                continue;
            }
            if (!rl_scene_is_drawable_valid(sorted[i].drawable, sorted[i].kind)) {
                continue;
            }
            rl_scene_draw_member(sorted[i].drawable, sorted[i].kind);
        }
    }
}

RL_KEEP
rl_pick_result_t rl_scene_pick(rl_handle_t scene,
                               rl_handle_t camera,
                               float mouse_x,
                               float mouse_y,
                               rl_handle_t *out_handle)
{
    rl_scene_instance_t *instance = rl_scene_get(scene);
    rl_pick_result_t best = {0};
    rl_handle_t best_handle = 0;
    rl_handle_t pick_camera = 0;
    Camera3D camera_data = {0};
    Ray ray = {0};
    int i = 0;

    if (out_handle != NULL) {
        *out_handle = 0;
    }

    if (instance == NULL) {
        return best;
    }

    pick_camera = rl_scene_resolve_camera(instance, camera);
    if (pick_camera == 0) {
        return best;
    }

    if (!rl_camera3d_get_camera(pick_camera, &camera_data)) {
        return best;
    }

    ray = GetMouseRay((Vector2){mouse_x, mouse_y}, camera_data);

    rl_pick_reset_stats();

    for (i = 0; i < instance->member_count; i++) {
        rl_scene_member_t *member = &instance->members[i];
        rl_pick_result_t result = {0};

        if (!rl_scene_kind_supports_narrow_pick(member->kind)) {
            continue;
        }
        if (!rl_scene_is_drawable_valid(member->drawable, member->kind)) {
            continue;
        }

        if (member->kind == RL_HANDLE_KIND_MODEL) {
            if (!rl_model_is_pickable(member->drawable)) {
                continue;
            }
            if (!rl_model_scene_pick_broadphase(member->drawable, ray)) {
                continue;
            }
            result = rl_pick_model_with_camera_ray(camera_data, ray, member->drawable);
        } else if (member->kind == RL_HANDLE_KIND_SPRITE3D) {
            if (!rl_sprite3d_is_pickable(member->drawable)) {
                continue;
            }
            if (!rl_sprite3d_scene_pick_broadphase(member->drawable, ray)) {
                continue;
            }
            result = rl_pick_sprite3d_with_camera_ray(camera_data, ray, member->drawable);
        }

        if (!result.hit) {
            continue;
        }
        if (!best.hit || result.distance < best.distance) {
            best = result;
            best_handle = member->drawable;
        }
    }

    if (out_handle != NULL && best.hit) {
        *out_handle = best_handle;
    }

    return best;
}

RL_KEEP
bool rl_scene_pick_to_scratch(rl_handle_t scene,
                              rl_handle_t camera,
                              float mouse_x,
                              float mouse_y)
{
    rl_handle_t picked = 0;
    rl_pick_result_t result =
        rl_scene_pick(scene, camera, mouse_x, mouse_y, &picked);

    rl_scratch_set_vector3(result.point.x, result.point.y, result.point.z);
    rl_scratch_set_vector4(result.normal.x, result.normal.y, result.normal.z,
                           result.distance);
    rl_scratch_set_vector2((float)picked, 0.0f);
    return result.hit;
}

void rl_scene_on_drawable_destroy(rl_handle_t drawable)
{
    int s = 0;
    int index = 0;

    if (drawable == 0) {
        return;
    }

    for (s = 0; s < MAX_SCENES; s++) {
        rl_scene_instance_t *scene = &rl_scenes[s];

        if (!scene->in_use) {
            continue;
        }

        index = rl_scene_find_member(scene, drawable);
        if (index < 0) {
            continue;
        }

        scene->member_count--;
        if (index < scene->member_count) {
            scene->members[index] = scene->members[scene->member_count];
        }
    }
}

void rl_scene_init(void)
{
    rl_handle_pool_init(&rl_scene_pool,
                        RL_HANDLE_KIND_SCENE,
                        MAX_SCENES,
                        rl_scene_free_indices,
                        MAX_SCENES,
                        rl_scene_generations,
                        rl_scene_occupied);
    for (int i = 0; i < MAX_SCENES; i++) {
        rl_scenes[i].in_use = false;
        rl_scenes[i].camera = 0;
        rl_scenes[i].member_count = 0;
        rl_scenes[i].next_order = 0;
    }
}

void rl_scene_deinit(void)
{
    int destroyed = 0;

    for (uint16_t i = 1; i < MAX_SCENES; i++) {
        if (!rl_scenes[i].in_use) {
            continue;
        }
        rl_handle_t handle = rl_handle_pool_handle_from_index(&rl_scene_pool, i);
        if (handle == 0) {
            continue;
        }
        rl_scene_destroy(handle);
        destroyed++;
    }
    rl_handle_pool_reset(&rl_scene_pool);
    log_info("rl_scene_deinit: Destroyed %d scenes", destroyed);
}
