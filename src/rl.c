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
#include "internal/rl_window.h"
#include "raylib.h"
#include "rl_loader.h"
#include <stddef.h>
#include <string.h>

#if defined(PLATFORM_WEB)
#include <emscripten/emscripten.h>
#endif


bool initialized = false;

static void rl_init_apply_defaults(rl_init_config_t *out)
{
    if (out->window_width == 0) {
        out->window_width = 1024;
    }
    if (out->window_height == 0) {
        out->window_height = 1280;
    }
    if (out->window_title == NULL) {
        out->window_title = "librl";
    }
    if (out->loader_cache_dir == NULL) {
        out->loader_cache_dir = "cache";
    }
}

RL_KEEP
size_t rl_init_config_sizeof(void) { return sizeof(rl_init_config_t); }

typedef struct rl_loop_state_t {
    rl_init_fn init_fn;
    rl_tick_fn tick_fn;
    rl_shutdown_fn shutdown_fn;
    void *user_data;
    int armed;       /* start() returned OK; session active for tick/stop */
    int user_inited; /* user init callback has run, or is not used */
    int looping;
} rl_loop_state_t;

static rl_loop_state_t rl_loop_state = {0};

static void rl_dispatch(void) {
    rl_loader_tick();
    if (!rl_loader_is_ready()) {
        return;
    }
    if (!rl_loop_state.user_inited) {
        if (rl_loop_state.init_fn != NULL) {
            rl_loop_state.init_fn(rl_loop_state.user_data);
        }
        rl_loop_state.user_inited = 1;
        return;
    }
    if (rl_loop_state.tick_fn != NULL) {
        rl_loop_state.tick_fn(rl_loop_state.user_data);
    }
}

static void rl_finish_run(void) {
    rl_shutdown_fn shutdown_fn = rl_loop_state.shutdown_fn;
    void *user_data = rl_loop_state.user_data;

    rl_loop_state.armed = 0;
    rl_loop_state.user_inited = 0;
    rl_loop_state.looping = 0;
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
    if (!rl_loop_state.looping) {
        emscripten_cancel_main_loop();
        rl_stop();
        return;
    }

    /* Do not call WindowShouldClose() here: raylib's rcore_web.c implementation
     * always ends with emscripten_sleep(12) to yield, which requires ASYNCIFY/JSPI
     * in the app link. On web it always returns false anyway; closing is not
     * driven the same way as desktop GLFW. */
    rl_dispatch();

    if (!rl_loop_state.looping) {
        emscripten_cancel_main_loop();
        rl_stop();
    }
}
#endif

RL_KEEP
int rl_init(const rl_init_config_t *config) {
    rl_init_config_t cfg;
    if (initialized) {
        return RL_INIT_ERR_ALREADY_INITIALIZED;
    }

    memset(&cfg, 0, sizeof(cfg));
    if (config != NULL) {
        cfg = *config;
    }
    rl_init_apply_defaults(&cfg);

    rl_logger_init();
    if (rl_loader_init(cfg.loader_cache_dir) != 0) {
        rl_logger_deinit();
        return RL_INIT_ERR_LOADER;
    }
    if (cfg.asset_host != NULL && cfg.asset_host[0] != '\0') {
        if (rl_set_asset_host(cfg.asset_host) != 0) {
            rl_loader_deinit();
            rl_logger_deinit();
            return RL_INIT_ERR_ASSET_HOST;
        }
    }
    rl_window_open_internal(
        cfg.window_width,
        cfg.window_height,
        cfg.window_title,
        cfg.window_flags
    );
    if (!IsWindowReady()) {
        rl_loader_deinit();
        rl_logger_deinit();
        return RL_INIT_ERR_WINDOW;
    }
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
    return 0;
}

RL_KEEP
bool rl_is_initialized(void) {
    return initialized;
}

RL_KEEP
const char *rl_get_platform(void) {
#if defined(PLATFORM_WEB)
    return "web";
#else
    return "desktop";
#endif
}

RL_KEEP
void rl_deinit() {
    if (!initialized) {
        return;
    }
    rl_camera3d_deinit();
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
    if (IsAudioDeviceReady()) {
        CloseAudioDevice();
    }
    rl_scratch_deinit();
    rl_loader_deinit();
    initialized = false;
    rl_window_close_internal();
    rl_logger_deinit();
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
int rl_start(rl_init_fn init_fn,
             rl_tick_fn tick_fn,
             rl_shutdown_fn shutdown_fn,
             void *user_data) {
    if (rl_loop_state.armed || rl_loop_state.looping) {
        return -1;
    }

    if (tick_fn == NULL) {
        return -1;
    }

    rl_loop_state.init_fn = init_fn;
    rl_loop_state.tick_fn = tick_fn;
    rl_loop_state.shutdown_fn = shutdown_fn;
    rl_loop_state.user_data = user_data;
    rl_loop_state.user_inited = (init_fn == NULL) ? 1 : 0;
    rl_loop_state.looping = 0;

    /* Loader readiness and user init_fn run in rl_dispatch (tick / run loop) so
     * the host can return between frames (e.g. web IDBFS restore). */
    rl_loop_state.armed = 1;
    return 0;
}

RL_KEEP
int rl_tick(void) {
    if (!rl_loop_state.armed || rl_loop_state.looping) {
        return -1;
    }

    rl_dispatch();

    return 0;
}

RL_KEEP
void rl_run(rl_init_fn init_fn,
            rl_tick_fn tick_fn,
            rl_shutdown_fn shutdown_fn,
            void *user_data) {
    if (rl_start(init_fn, tick_fn, shutdown_fn, user_data) != 0) {
        return;
    }

    rl_loop_state.looping = 1;

#if defined(PLATFORM_WEB)
    emscripten_set_main_loop(rl_web_step, 0, 1);
#else
    while (rl_loop_state.looping) {
        if (WindowShouldClose()) {
            rl_stop();
            break;
        }

        rl_dispatch();
    }
    rl_stop();
#endif
}

RL_KEEP
void rl_stop(void) {
    if (rl_loop_state.looping) {
        rl_loop_state.looping = 0;
        return;
    }

    if (!rl_loop_state.armed) {
        return;
    }

    rl_finish_run();
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
