#ifndef RL_H
#define RL_H

#include <stdbool.h>
#include "rl_module.h"
#include "rl_camera3d.h"
#include "rl_color.h"
#include "rl_debug.h"
#include "rl_event.h"
#include "rl_render.h"
#include "rl_frame_command.h"
#include "rl_font.h"
#include "rl_input.h"
#include "rl_loader.h"
#include "rl_logger.h"
#include "rl_model.h"
#include "rl_music.h"
#include "rl_pick.h"
#include "rl_shape.h"
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

typedef void (*rl_init_fn)(void *user_data);
typedef void (*rl_tick_fn)(void *user_data);
typedef void (*rl_shutdown_fn)(void *user_data);

void rl_init();
void rl_deinit();
int rl_set_asset_host(const char *asset_host);
const char *rl_get_asset_host(void);
void rl_enable_lighting();
void rl_disable_lighting();
int rl_is_lighting_enabled();
void rl_set_light_direction(float x, float y, float z);
void rl_set_light_ambient(float ambient);
void rl_update_to_scratch(void);
void rl_update(void);
void rl_run(rl_init_fn init_fn,
            rl_tick_fn tick_fn,
            rl_shutdown_fn shutdown_fn,
            void *user_data);
void rl_request_stop(void);
void rl_set_target_fps(int fps);
float rl_get_delta_time(void);
double rl_get_time(void);

#ifdef __cplusplus
}
#endif

#endif // RL_H
