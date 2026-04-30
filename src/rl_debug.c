#include "rl_debug.h"

#include "internal/rl_debug.h"
#include "rl_color.h"
#include "rl_font.h"
#include "rl_text.h"

#include <stdbool.h>
#include <stddef.h>

typedef struct rl_debug_state_t {
    bool fps_enabled;
    int fps_x;
    int fps_y;
    int fps_font_size;
    rl_handle_t fps_font;
    bool owns_fps_font;
} rl_debug_state_t;

static rl_debug_state_t rl_debug_state = {0};

static void rl_debug_release_fps_font(void) {
    if (rl_debug_state.owns_fps_font && rl_debug_state.fps_font != 0) {
        rl_font_destroy(rl_debug_state.fps_font);
    }
    rl_debug_state.fps_font = 0;
    rl_debug_state.owns_fps_font = false;
}

void rl_debug_enable_fps(int x, int y, int font_size, const char *font_path) {
    rl_debug_release_fps_font();

    rl_debug_state.fps_enabled = true;
    rl_debug_state.fps_x = x;
    rl_debug_state.fps_y = y;
    rl_debug_state.fps_font_size = font_size > 0 ? font_size : 16;

    if (font_path != NULL && font_path[0] != '\0') {
        rl_debug_state.fps_font = rl_font_create(font_path, rl_debug_state.fps_font_size);
        rl_debug_state.owns_fps_font = rl_debug_state.fps_font != 0;
    }
}

void rl_debug_disable(void) {
    rl_debug_release_fps_font();
    rl_debug_state.fps_enabled = false;
}

void rl_debug_init(void) {
    rl_debug_state = (rl_debug_state_t){0};
}

void rl_debug_deinit(void) {
    rl_debug_disable();
}

void rl_debug_draw(void) {
    if (!rl_debug_state.fps_enabled) {
        return;
    }

    if (rl_debug_state.fps_font != 0) {
        rl_text_draw_fps_ex(rl_debug_state.fps_font,
                            rl_debug_state.fps_x,
                            rl_debug_state.fps_y,
                            rl_debug_state.fps_font_size,
                            RL_COLOR_DARKGRAY);
        return;
    }

    rl_text_draw_fps(rl_debug_state.fps_x, rl_debug_state.fps_y);
}
