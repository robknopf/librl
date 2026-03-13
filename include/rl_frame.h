#ifndef RL_FRAME_H
#define RL_FRAME_H

#ifdef __cplusplus
extern "C" {
#endif

#include "rl_types.h"

void rl_frame_begin(void);
void rl_frame_end(void);
void rl_frame_clear_background(rl_handle_t color);
float rl_frame_get_delta_time(void);
void rl_frame_begin_mode_2d(rl_handle_t camera);
void rl_frame_end_mode_2d(void);
void rl_frame_draw_rectangle(int x, int y, int width, int height,
                             rl_handle_t color);
double rl_frame_get_time(void);

#ifdef __cplusplus
}
#endif

#endif // RL_FRAME_H
