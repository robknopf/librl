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
#include "internal/rl_sprite3d.h"
#include "internal/rl_texture.h"
#include "raylib.h"
#include "rl_loader.h"
#include "logger/logger.h"


bool initialized = false;

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
