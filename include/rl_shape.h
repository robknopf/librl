#ifndef RL_SHAPE_H
#define RL_SHAPE_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include "rl_types.h"

typedef enum rl_shape_kind_t {
    RL_SHAPE_KIND_NONE = 0,
    RL_SHAPE_KIND_LINE_3D = 1,
    RL_SHAPE_KIND_LINE_STRIP_3D = 2,
} rl_shape_kind_t;

rl_handle_t rl_shape_create(void);
void rl_shape_destroy(rl_handle_t shape);
bool rl_shape_set_visible(rl_handle_t shape, bool visible);
bool rl_shape_is_visible(rl_handle_t shape);
bool rl_shape_set_stroke_color(rl_handle_t shape, rl_handle_t color);
bool rl_shape_set_line_3d(rl_handle_t shape,
                          float start_x, float start_y, float start_z,
                          float end_x, float end_y, float end_z);
bool rl_shape_set_line_strip_3d(rl_handle_t shape,
                                const float* points,
                                int point_count);
void rl_shape_draw(rl_handle_t shape);

void rl_shape_draw_rectangle(int x, int y, int width, int height,
                             rl_handle_t color);
void rl_shape_draw_cube(float position_x, float position_y, float position_z,
                        float width, float height, float length,
                        rl_handle_t color);
void rl_shape_draw_circle_3d(float center_x, float center_y, float center_z,
                             float radius,
                             float rotation_axis_x, float rotation_axis_y, float rotation_axis_z,
                             float rotation_angle,
                             rl_handle_t color);

void rl_shape_draw_line_3d(float start_x, float start_y, float start_z,
                           float end_x, float end_y, float end_z,
                           rl_handle_t color);

void rl_shape_draw_line_strip_3d(const float* points, int point_count,
                                 rl_handle_t color);

#ifdef __cplusplus
}
#endif

#endif // RL_SHAPE_H
