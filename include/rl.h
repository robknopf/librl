#ifndef RL_H
#define RL_H

#include <stdbool.h>
#include "rl_module.h" // IWYU pragma: keep
#include "rl_camera3d.h" // IWYU pragma: keep
#include "rl_color.h" // IWYU pragma: keep
#include "rl_debug.h" // IWYU pragma: keep
#include "rl_event.h" // IWYU pragma: keep
#include "rl_render.h" // IWYU pragma: keep
#include "rl_frame_command.h" // IWYU pragma: keep
#include "rl_font.h" // IWYU pragma: keep
#include "rl_input.h" // IWYU pragma: keep
#include "rl_loader.h" // IWYU pragma: keep
#include "rl_logger.h" // IWYU pragma: keep
#include "rl_model.h" // IWYU pragma: keep
#include "rl_music.h" // IWYU pragma: keep
#include "rl_pick.h" // IWYU pragma: keep
#include "rl_shape.h" // IWYU pragma: keep
#include "rl_scratch.h" // IWYU pragma: keep
#include "rl_sound.h" // IWYU pragma: keep
#include "rl_sprite2d.h" // IWYU pragma: keep
#include "rl_sprite3d.h" // IWYU pragma: keep
#include "rl_text.h" // IWYU pragma: keep
#include "rl_texture.h" // IWYU pragma: keep
#include "rl_types.h" // IWYU pragma: keep
#include "rl_config.h"
#include "rl_window.h" // IWYU pragma: keep

#ifdef __cplusplus
extern "C" {
#endif

typedef enum rl_init_result_t {
  RL_INIT_OK = 0,
  RL_INIT_ERR_UNKNOWN = -1,
  RL_INIT_ERR_ALREADY_INITIALIZED = -2,
  RL_INIT_ERR_LOADER = -3,
  RL_INIT_ERR_ASSET_HOST = -4,
  RL_INIT_ERR_WINDOW = -5,
} rl_init_result_t;

typedef enum rl_tick_result_t {
  RL_TICK_RUNNING = 0,
  RL_TICK_WAITING = 1,
  RL_TICK_FAILED = -1,
} rl_tick_result_t;

int rl_init(const rl_init_config_t *config);
bool rl_is_initialized(void);
const char *rl_get_platform(void);
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
rl_tick_result_t rl_tick(void);
void rl_set_target_fps(int fps);
float rl_get_delta_time(void);
double rl_get_time(void);

#ifdef __cplusplus
}
#endif

#endif // RL_H
