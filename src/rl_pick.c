#include "rl_pick.h"

#include <raylib.h>
#include <raymath.h>
#include "internal/exports.h"
#include "internal/rl_camera3d_store.h"
#include "internal/rl_model_store.h"
#include "internal/rl_sprite3d_store.h"
#include "rl_scratch.h"

static rl_pick_result_t rl_pick_result_empty(void)
{
    rl_pick_result_t result = {0};
    result.hit = false;
    result.distance = -1.0f;
    result.point = (vec3_t){0.0f, 0.0f, 0.0f};
    result.normal = (vec3_t){0.0f, 0.0f, 0.0f};
    return result;
}

static Matrix rl_pick_model_transform(float x, float y, float z, float scale)
{
    Matrix translation = MatrixTranslate(x, y, z);
    Matrix scaling = MatrixScale(scale, scale, scale);
    return MatrixMultiply(scaling, translation);
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
                               float scale)
{
    Camera3D camera_data = {0};
    Ray ray = {0};
    Matrix transform = {0};
    RayCollision collision = {0};

    if (!rl_camera3d_get_camera(camera, &camera_data)) {
        return rl_pick_result_empty();
    }

    ray = GetMouseRay((Vector2){mouse_x, mouse_y}, camera_data);
    transform = rl_pick_model_transform(position_x, position_y, position_z, scale);
    if (!rl_model_get_ray_collision(model, ray, transform, &collision)) {
        return rl_pick_result_empty();
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
                              float scale)
{
    rl_pick_result_t result = rl_pick_model(camera, model, mouse_x, mouse_y, position_x, position_y, position_z, scale);

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

    if (!rl_camera3d_get_camera(camera, &camera_data)) {
        return rl_pick_result_empty();
    }

    ray = GetMouseRay((Vector2){mouse_x, mouse_y}, camera_data);
    if (!rl_sprite3d_get_ray_collision(sprite3d, camera_data, ray, position_x, position_y, position_z, size, &collision)) {
        return rl_pick_result_empty();
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
