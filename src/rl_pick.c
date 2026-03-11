#include "rl_pick.h"

#include <raylib.h>
#include <raymath.h>
#include "internal/exports.h"
#include "internal/rl_camera3d_store.h"
#include "internal/rl_model_store.h"
#include "internal/rl_sprite3d_store.h"
#include "rl_scratch.h"

static rl_pick_stats_t rl_pick_stats = {0};

static rl_pick_result_t rl_pick_result_empty(void)
{
    rl_pick_result_t result = {0};
    result.hit = false;
    result.distance = -1.0f;
    result.point = (vec3_t){0.0f, 0.0f, 0.0f};
    result.normal = (vec3_t){0.0f, 0.0f, 0.0f};
    return result;
}

static Matrix rl_pick_model_transform(float x, float y, float z, float scale,
                                      float rotation_x, float rotation_y, float rotation_z)
{
    Matrix translation = MatrixTranslate(x, y, z);
    Matrix rotation = MatrixRotateXYZ((Vector3){
        rotation_x * DEG2RAD,
        rotation_y * DEG2RAD,
        rotation_z * DEG2RAD
    });
    Matrix scaling = MatrixScale(scale, scale, scale);
    return MatrixMultiply(MatrixMultiply(scaling, rotation), translation);
}

static rl_pick_result_t rl_pick_from_ray_collision(RayCollision collision)
{
    rl_pick_result_t result = rl_pick_result_empty();
    if (!collision.hit) {
        return result;
    }

    result.hit = true;
    result.distance = collision.distance;
    result.point = (vec3_t){collision.point.x, collision.point.y, collision.point.z};
    result.normal = (vec3_t){collision.normal.x, collision.normal.y, collision.normal.z};
    return result;
}

RL_KEEP
rl_pick_result_t rl_pick_model(rl_handle_t camera,
                               rl_handle_t model,
                               float mouse_x,
                               float mouse_y,
                               float position_x,
                               float position_y,
                               float position_z,
                               float scale,
                               float rotation_x,
                               float rotation_y,
                               float rotation_z)
{
    Camera3D camera_data = {0};
    Ray ray = {0};
    Matrix transform = {0};
    RayCollision collision = {0};
    bool broadphase_tested = false;
    bool broadphase_rejected = false;
    bool narrowphase_ran = false;

    if (!rl_camera3d_get_camera(camera, &camera_data)) {
        return rl_pick_result_empty();
    }

    ray = GetMouseRay((Vector2){mouse_x, mouse_y}, camera_data);
    transform = rl_pick_model_transform(position_x, position_y, position_z, scale,
                                        rotation_x, rotation_y, rotation_z);
    if (!rl_model_get_ray_collision_ex(model,
                                       ray,
                                       transform,
                                       &collision,
                                       &broadphase_tested,
                                       &broadphase_rejected,
                                       &narrowphase_ran)) {
        return rl_pick_result_empty();
    }

    if (broadphase_tested) {
        rl_pick_stats.broadphase_tests++;
    }
    if (broadphase_rejected) {
        rl_pick_stats.broadphase_rejects++;
    }
    if (narrowphase_ran) {
        rl_pick_stats.narrowphase_tests++;
    }
    if (collision.hit && narrowphase_ran) {
        rl_pick_stats.narrowphase_hits++;
    }

    return rl_pick_from_ray_collision(collision);
}

RL_KEEP
bool rl_pick_model_to_scratch(rl_handle_t camera,
                              rl_handle_t model,
                              float mouse_x,
                              float mouse_y,
                              float position_x,
                              float position_y,
                              float position_z,
                              float scale,
                              float rotation_x,
                              float rotation_y,
                              float rotation_z)
{
    rl_pick_result_t result = rl_pick_model(camera, model, mouse_x, mouse_y,
                                            position_x, position_y, position_z,
                                            scale, rotation_x, rotation_y, rotation_z);

    rl_scratch_set_vector3(result.point.x, result.point.y, result.point.z);
    rl_scratch_set_vector4(result.normal.x, result.normal.y, result.normal.z, result.distance);
    return result.hit;
}

RL_KEEP
rl_pick_result_t rl_pick_sprite3d(rl_handle_t camera,
                                  rl_handle_t sprite3d,
                                  float mouse_x,
                                  float mouse_y,
                                  float position_x,
                                  float position_y,
                                  float position_z,
                                  float size)
{
    Camera3D camera_data = {0};
    Ray ray = {0};
    RayCollision collision = {0};
    bool broadphase_tested = false;
    bool broadphase_rejected = false;
    bool narrowphase_ran = false;

    if (!rl_camera3d_get_camera(camera, &camera_data)) {
        return rl_pick_result_empty();
    }

    ray = GetMouseRay((Vector2){mouse_x, mouse_y}, camera_data);
    if (!rl_sprite3d_get_ray_collision_ex(sprite3d,
                                          camera_data,
                                          ray,
                                          position_x,
                                          position_y,
                                          position_z,
                                          size,
                                          &collision,
                                          &broadphase_tested,
                                          &broadphase_rejected,
                                          &narrowphase_ran)) {
        return rl_pick_result_empty();
    }

    if (broadphase_tested) {
        rl_pick_stats.broadphase_tests++;
    }
    if (broadphase_rejected) {
        rl_pick_stats.broadphase_rejects++;
    }
    if (narrowphase_ran) {
        rl_pick_stats.narrowphase_tests++;
    }
    if (collision.hit && narrowphase_ran) {
        rl_pick_stats.narrowphase_hits++;
    }

    return rl_pick_from_ray_collision(collision);
}

RL_KEEP
bool rl_pick_sprite3d_to_scratch(rl_handle_t camera,
                                 rl_handle_t sprite3d,
                                 float mouse_x,
                                 float mouse_y,
                                 float position_x,
                                 float position_y,
                                 float position_z,
                                 float size)
{
    rl_pick_result_t result = rl_pick_sprite3d(camera, sprite3d, mouse_x, mouse_y, position_x, position_y, position_z, size);

    rl_scratch_set_vector3(result.point.x, result.point.y, result.point.z);
    rl_scratch_set_vector4(result.normal.x, result.normal.y, result.normal.z, result.distance);
    return result.hit;
}

RL_KEEP
void rl_pick_reset_stats(void)
{
    rl_pick_stats = (rl_pick_stats_t){0};
}

RL_KEEP
int rl_pick_get_broadphase_tests(void)
{
    return rl_pick_stats.broadphase_tests;
}

RL_KEEP
int rl_pick_get_broadphase_rejects(void)
{
    return rl_pick_stats.broadphase_rejects;
}

RL_KEEP
int rl_pick_get_narrowphase_tests(void)
{
    return rl_pick_stats.narrowphase_tests;
}

RL_KEEP
int rl_pick_get_narrowphase_hits(void)
{
    return rl_pick_stats.narrowphase_hits;
}
