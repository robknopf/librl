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
#include "internal/rl_sprite2d.h"
#include "internal/rl_sprite3d.h"
#include "internal/rl_texture.h"
#include "internal/rl_window.h"
#include "raylib.h"
#include "rl_loader.h"
#include <stddef.h>
#include <string.h>

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
rl_tick_result_t rl_tick(void) {
    if (!initialized) {
        return RL_TICK_FAILED;
    }
    rl_loader_tick();
    if (!rl_loader_is_ready()) {
        return RL_TICK_WAITING;
    }
    return RL_TICK_RUNNING;
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
