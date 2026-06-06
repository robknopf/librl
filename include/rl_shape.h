#ifndef RL_SHAPE_H
#define RL_SHAPE_H

#ifdef __cplusplus
extern "C" {
#endif

#include "rl_types.h"

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
