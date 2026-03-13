#ifndef RL_H
#define RL_H

#include <stdbool.h>
#include "rl_module.h"
#include "rl_camera3d.h"
#include "rl_color.h"
#include "rl_debug.h"
#include "rl_event.h"
#include "rl_frame.h"
#include "rl_frame_runner.h"
#include "rl_frame_commands.h"
#include "rl_font.h"
#include "rl_input.h"
#include "rl_loader.h"
#include "rl_logger.h"
#include "rl_model.h"
#include "rl_music.h"
#include "rl_pick.h"
#include "rl_scratch.h"
#include "rl_sound.h"
#include "rl_sprite3d.h"
#include "rl_text.h"
#include "rl_texture.h"
#include "rl_types.h"
#include "rl_window.h"

#ifdef __cplusplus
extern "C" {
#endif

void rl_init();
void rl_deinit();
int rl_set_asset_host(const char *asset_host);
const char *rl_get_asset_host(void);
void rl_begin_mode_3d();
void rl_end_mode_3d();
void rl_enable_lighting();
void rl_disable_lighting();
int rl_is_lighting_enabled();
void rl_set_light_direction(float x, float y, float z);
void rl_set_light_ambient(float ambient);
void rl_draw_cube(float position_x, float position_y, float position_z,
                  float width, float height, float length, rl_handle_t color);
void rl_update_to_scratch(void);
void rl_update(void);
#ifdef __cplusplus
}
#endif

#endif // RL_H
