#include "rl_pick.h"

#include <raylib.h>
#include <raymath.h>
#include "internal/exports.h"
#include "internal/rl_camera3d.h"
#include "internal/rl_model.h"
#include "internal/rl_sprite3d.h"
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

static Matrix rl_pick_model_transform(float x, float y, float z,
                                      float scale_x, float scale_y, float scale_z,
                                      float rotation_x, float rotation_y, float rotation_z)
{
    Matrix translation = MatrixTranslate(x, y, z);
    Matrix rotation = MatrixRotateXYZ((Vector3){
        rotation_x * DEG2RAD,
        rotation_y * DEG2RAD,
        rotation_z * DEG2RAD
    });
    Matrix scaling = MatrixScale(scale_x, scale_y, scale_z);
    return MatrixMultiply(MatrixMultiply(scaling, rotation), translation);
}

static Vector3 rl_pick_transform_direction(Matrix transform, Vector3 direction)
{
    return (Vector3){
        transform.m0*direction.x + transform.m4*direction.y + transform.m8*direction.z,
        transform.m1*direction.x + transform.m5*direction.y + transform.m9*direction.z,
        transform.m2*direction.x + transform.m6*direction.y + transform.m10*direction.z
    };
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
                               float mouse_y)
{
    Camera3D camera_data = {0};
    Ray ray = {0};
    Matrix instance_transform = {0};
    Matrix model_transform = {0};
    RayCollision collision = {0};
    bool broadphase_tested = false;
    bool broadphase_rejected = false;
    bool narrowphase_ran = false;
    float position_x = 0, position_y = 0, position_z = 0;
    float scale_x = 1, scale_y = 1, scale_z = 1;
    float rotation_x = 0, rotation_y = 0, rotation_z = 0;

    if (!rl_camera3d_get_camera(camera, &camera_data)) {
        return rl_pick_result_empty();
    }
    if (!rl_model_get_transform(model, &position_x, &position_y, &position_z,
                                &scale_x, &scale_y, &scale_z,
                                &rotation_x, &rotation_y, &rotation_z)) {
        return rl_pick_result_empty();
    }

    ray = GetMouseRay((Vector2){mouse_x, mouse_y}, camera_data);
    instance_transform = rl_pick_model_transform(position_x, position_y, position_z,
                                                 scale_x, scale_y, scale_z,
                                                 rotation_x, rotation_y, rotation_z);
    if (!rl_model_get_ray_collision_ex(model,
                                       ray,
                                       instance_transform,
                                       &collision,
                                       &model_transform,
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

    if (collision.hit) {
        Matrix inv = MatrixInvert(model_transform);
        Matrix local_normal_transform = MatrixTranspose(model_transform);
        Vector3 world_pt = {collision.point.x, collision.point.y, collision.point.z};
        Vector3 world_normal = {collision.normal.x, collision.normal.y, collision.normal.z};
        Vector3 local_pt = Vector3Transform(world_pt, inv);
        Vector3 local_normal = Vector3Normalize(
            rl_pick_transform_direction(local_normal_transform, world_normal)
        );
        collision.point = local_pt;
        collision.normal = local_normal;
    }

    return rl_pick_from_ray_collision(collision);
}

RL_KEEP
bool rl_pick_model_to_scratch(rl_handle_t camera,
                              rl_handle_t model,
                              float mouse_x,
                              float mouse_y)
{
    rl_pick_result_t result = rl_pick_model(camera, model, mouse_x, mouse_y);

    rl_scratch_set_vector3(result.point.x, result.point.y, result.point.z);
    rl_scratch_set_vector4(result.normal.x, result.normal.y, result.normal.z, result.distance);
    return result.hit;
}

RL_KEEP
rl_pick_result_t rl_pick_sprite3d(rl_handle_t camera,
                                  rl_handle_t sprite3d,
                                  float mouse_x,
                                  float mouse_y)
{
    Camera3D camera_data = {0};
    Ray ray = {0};
    RayCollision collision = {0};
    bool broadphase_tested = false;
    bool broadphase_rejected = false;
    bool narrowphase_ran = false;
    float position_x = 0, position_y = 0, position_z = 0, size = 1;

    if (!rl_camera3d_get_camera(camera, &camera_data)) {
        return rl_pick_result_empty();
    }
    if (!rl_sprite3d_get_transform(sprite3d, &position_x, &position_y, &position_z, &size)) {
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

    if (collision.hit) {
        collision.normal = (Vector3){0.0f, 0.0f, (collision.normal.z < 0.0f) ? -1.0f : 1.0f};
    }

    return rl_pick_from_ray_collision(collision);
}

RL_KEEP
bool rl_pick_sprite3d_to_scratch(rl_handle_t camera,
                                 rl_handle_t sprite3d,
                                 float mouse_x,
                                 float mouse_y)
{
    rl_pick_result_t result = rl_pick_sprite3d(camera, sprite3d, mouse_x, mouse_y);

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
