#include "rl.h"
#include "internal/exports.h"
#include "internal/rl_camera3d.h"
#include "internal/rl_color.h"
#include "internal/rl_debug.h"
#include "internal/rl_event.h"
#include "internal/rl_font.h"
#include "internal/rl_loader.h"
#include "internal/rl_logger.h"
#include "internal/rl_model.h"
#include "internal/rl_music.h"
#include "internal/rl_sound.h"
#include "internal/rl_scratch.h"
#include "internal/rl_state.h"
#include "internal/rl_sprite2d.h"
#include "internal/rl_sprite3d.h"
#include "internal/rl_texture.h"
#include "raylib.h"
#include "rl_loader.h"
#include <string.h>

#if defined(PLATFORM_WEB)
#include <emscripten/emscripten.h>
#endif


bool initialized = false;

typedef struct rl_loop_state_t {
    rl_init_fn init_fn;
    rl_tick_fn tick_fn;
    rl_shutdown_fn shutdown_fn;
    void *user_data;
    int running;
    int init_complete;
} rl_loop_state_t;

static rl_loop_state_t rl_loop_state = {0};

static void rl_finish_run(void) {
    rl_shutdown_fn shutdown_fn = rl_loop_state.shutdown_fn;
    void *user_data = rl_loop_state.user_data;

    rl_loop_state.running = 0;
    rl_loop_state.init_fn = NULL;
    rl_loop_state.tick_fn = NULL;
    rl_loop_state.shutdown_fn = NULL;
    rl_loop_state.user_data = NULL;

    if (shutdown_fn != NULL) {
        shutdown_fn(user_data);
    }
}

#if defined(PLATFORM_WEB)
static void rl_web_step(void) {
    if (!rl_loop_state.running) {
        emscripten_cancel_main_loop();
        rl_finish_run();
        return;
    }

    rl_loader_tick();

    if (!rl_loop_state.init_complete) {
        if (!rl_loader_is_ready()) {
            return;
        }

        if (rl_loop_state.init_fn != NULL) {
            rl_loop_state.init_fn(rl_loop_state.user_data);
        }
        rl_loop_state.init_complete = 1;

        if (!rl_loop_state.running) {
            emscripten_cancel_main_loop();
            rl_finish_run();
            return;
        }
    }

    if (rl_loop_state.tick_fn != NULL) {
        rl_loop_state.tick_fn(rl_loop_state.user_data);
    }

    if (!rl_loop_state.running) {
        emscripten_cancel_main_loop();
        rl_finish_run();
    }
}
#endif

RL_KEEP
void rl_init() {
    if (initialized) {
        return;
    }    
    rl_logger_init();
    rl_loader_init("cache");
    rl_scratch_init();
    rl_color_init();
    rl_font_init();
    rl_model_init();
    rl_music_init();
    rl_sound_init();
    rl_event_init();
    rl_camera3d_init();
    rl_texture_init();
    rl_sprite2d_init();
    rl_sprite3d_init();
    rl_debug_init();
    initialized = true;
}

RL_KEEP
void rl_deinit() {
    if (!initialized) {
        return;
    }
    rl_camera3d_deinit();
    initialized = false;
    rl_debug_deinit();
    rl_sprite2d_deinit();
    rl_sprite3d_deinit();
    rl_texture_deinit();
    rl_model_deinit();
    rl_sound_deinit();
    rl_music_deinit();
    rl_event_deinit();
    rl_font_deinit();
    rl_color_deinit();
    rl_scratch_deinit();
    rl_loader_deinit();
    rl_logger_deinit();
    if (IsAudioDeviceReady()) {
        CloseAudioDevice();
    }
}

RL_KEEP
int rl_set_asset_host(const char *asset_host) {
    return rl_loader_set_asset_host(asset_host);
}

RL_KEEP
const char *rl_get_asset_host(void) {
    return rl_loader_get_asset_host();
}

RL_KEEP
void rl_update_to_scratch() {
    rl_scratch_update();
}

void rl_update(void) {
    // Intentionally a no-op for API parity on non-wasm hosts.
}

RL_KEEP
void rl_run(rl_init_fn init_fn,
            rl_tick_fn tick_fn,
            rl_shutdown_fn shutdown_fn,
            void *user_data) {
    if (tick_fn == NULL) {
        return;
    }

    rl_loop_state.init_fn = init_fn;
    rl_loop_state.tick_fn = tick_fn;
    rl_loop_state.shutdown_fn = shutdown_fn;
    rl_loop_state.user_data = user_data;
    rl_loop_state.running = 1;
    rl_loop_state.init_complete = 0;

#if defined(PLATFORM_WEB)
    emscripten_set_main_loop(rl_web_step, 0, 1);
#else
    while (rl_loop_state.running) {
        rl_loader_tick();

        if (!rl_loop_state.init_complete) {
            if (!rl_loader_is_ready()) {
                continue;
            }

            if (rl_loop_state.init_fn != NULL) {
                rl_loop_state.init_fn(rl_loop_state.user_data);
            }
            rl_loop_state.init_complete = 1;

            if (!rl_loop_state.running) {
                break;
            }
        }

        if (WindowShouldClose()) {
            break;
        }

        rl_loop_state.tick_fn(rl_loop_state.user_data);
    }
    rl_finish_run();
#endif
}

RL_KEEP
void rl_request_stop(void) {
    rl_loop_state.running = 0;
}

RL_KEEP
void rl_set_target_fps(int fps) {
    SetTargetFPS(fps);
}

RL_KEEP
float rl_get_delta_time() {
    return GetFrameTime();
}

RL_KEEP
double rl_get_time() {
    return GetTime();
}
