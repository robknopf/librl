#include "rl_color.h"
#include "raylib.h"
#include <stdio.h>
#include <stdlib.h>

#include "internal/exports.h"

#define MAX_COLORS 255
Color* colors[MAX_COLORS];

// Color handles intentionally map to lightweight RGBA values.
// Unlike textures/models, colors are tiny value objects and do not use
// refcounted shared-asset semantics.

// predefined colors
const rl_handle_t RL_COLOR_DEFAULT = 0;
const rl_handle_t RL_COLOR_LIGHTGRAY = 1;
const rl_handle_t RL_COLOR_GRAY = 2;
const rl_handle_t RL_COLOR_DARKGRAY = 3;
const rl_handle_t RL_COLOR_YELLOW = 4;
const rl_handle_t RL_COLOR_GOLD = 5;
const rl_handle_t RL_COLOR_ORANGE = 6;
const rl_handle_t RL_COLOR_PINK = 7;
const rl_handle_t RL_COLOR_RED = 8;
const rl_handle_t RL_COLOR_MAROON = 9;
const rl_handle_t RL_COLOR_GREEN = 10;
const rl_handle_t RL_COLOR_LIME = 11;
const rl_handle_t RL_COLOR_DARKGREEN = 12;
const rl_handle_t RL_COLOR_SKYBLUE = 13;
const rl_handle_t RL_COLOR_BLUE = 14;
const rl_handle_t RL_COLOR_DARKBLUE = 15;
const rl_handle_t RL_COLOR_PURPLE = 16;
const rl_handle_t RL_COLOR_VIOLET = 17;
const rl_handle_t RL_COLOR_DARKPURPLE = 18;
const rl_handle_t RL_COLOR_BEIGE = 19;
const rl_handle_t RL_COLOR_BROWN = 20;
const rl_handle_t RL_COLOR_DARKBROWN = 21;
const rl_handle_t RL_COLOR_WHITE = 22;
const rl_handle_t RL_COLOR_BLACK = 23;
const rl_handle_t RL_COLOR_BLANK = 24;
const rl_handle_t RL_COLOR_MAGENTA = 25;
const rl_handle_t RL_COLOR_RAYWHITE = 26;

rl_handle_t next_color_handle = 27;

rl_handle_t rl_color_get_next_handle() {
    if (next_color_handle >= MAX_COLORS) {
        fprintf(stderr, "ERROR: MAX_COLORS reached (%d)\n", next_color_handle);
        return 0;
    }
    return next_color_handle++;
}

RL_KEEP
rl_handle_t rl_color_create(int r, int g, int b, int a) {
    Color* color = malloc(sizeof(Color));
    color->r = r;
    color->g = g;
    color->b = b;
    color->a = a;
    rl_handle_t handle = rl_color_get_next_handle();
    colors[handle] = color;
    return handle;
}

RL_KEEP
void rl_color_destroy(rl_handle_t handle) {
    Color* color = colors[handle];
    if (!color) {
        fprintf(stderr, "ERROR: Invalid color handle (%d)\n", handle);
        return;
    }
    free(color);
    colors[handle] = NULL;
}

void rl_color_set(rl_handle_t handle, int r, int g, int b, int a) {
    Color *color = colors[handle];
    if (!color) {
        color = malloc(sizeof(Color));
        colors[handle] = color;
    }
    color->r = r;
    color->g = g;
    color->b = b;
    color->a = a;
}

Color rl_color_get(rl_handle_t handle) {
    if (!colors[handle]) {
        fprintf(stderr, "ERROR: Invalid color handle (%d)\n", handle);
        return MAGENTA;
    }
    return *colors[handle];
}


void rl_color_init() {

    for (rl_handle_t i = 0; i < MAX_COLORS; i++) {
        colors[i] = NULL;
    }


   rl_color_set(RL_COLOR_DEFAULT, 255, 0, 255, 255);  // fucia
   rl_color_set(RL_COLOR_LIGHTGRAY, 200, 200, 200, 255);  // light gray
   rl_color_set(RL_COLOR_GRAY, 130, 130, 130, 255);  // gray
   rl_color_set(RL_COLOR_DARKGRAY, 80, 80, 80, 255);  // dark gray
   rl_color_set(RL_COLOR_YELLOW, 255, 255, 0, 255);  // yellow
   rl_color_set(RL_COLOR_GOLD, 255, 203, 0, 255);  // gold
   rl_color_set(RL_COLOR_ORANGE, 255, 161, 0, 255);  // orange
   rl_color_set(RL_COLOR_PINK, 255, 109, 194, 255);  // pink
   rl_color_set(RL_COLOR_RED, 230, 41, 55, 255);  // red
   rl_color_set(RL_COLOR_MAROON, 190, 33, 45, 255);  // maroon
   rl_color_set(RL_COLOR_GREEN, 0, 228, 48, 255);  // green
   rl_color_set(RL_COLOR_LIME, 0, 158, 47, 255);  // lime
   rl_color_set(RL_COLOR_DARKGREEN, 0, 117, 44, 255);  // dark green
   rl_color_set(RL_COLOR_SKYBLUE, 102, 191, 255, 255);  // sky blue
   rl_color_set(RL_COLOR_BLUE, 0, 121, 241, 255);  // blue
   rl_color_set(RL_COLOR_DARKBLUE, 0, 82, 172, 255);  // dark blue
   rl_color_set(RL_COLOR_PURPLE, 200, 122, 255, 255);  // purple
   rl_color_set(RL_COLOR_VIOLET, 135, 60, 190, 255);  // violet
   rl_color_set(RL_COLOR_DARKPURPLE, 112, 31, 126, 255);  // dark purple
   rl_color_set(RL_COLOR_BEIGE, 211, 176, 131, 255);  // beige
   rl_color_set(RL_COLOR_BROWN, 127, 106, 79, 255);  // brown
   rl_color_set(RL_COLOR_DARKBROWN, 76, 63, 47, 255);  // dark brown
   rl_color_set(RL_COLOR_WHITE, 255, 255, 255, 255);  // white
   rl_color_set(RL_COLOR_BLACK, 0, 0, 0, 255);  // black
   rl_color_set(RL_COLOR_BLANK, 0, 0, 0, 0);  // blank
   rl_color_set(RL_COLOR_MAGENTA, 255, 0, 255, 255);  // magenta
   rl_color_set(RL_COLOR_RAYWHITE, 245, 245, 245, 255);  // raywhite
}

void rl_color_deinit() {

    int rl_colors_freed = 0;

    for (rl_handle_t i = 0; i < MAX_COLORS; i++) {
        if (colors[i] != NULL) {
            //printf("Freeing color %d\n", i);
            free(colors[i]);
            colors[i] = NULL;
            rl_colors_freed++;
        }
    }
    next_color_handle = 0;

    printf("rl_color_deinit: Freed %d colors\n", rl_colors_freed);
}
