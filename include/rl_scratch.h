#ifndef RL_SCRATCH_H
#define RL_SCRATCH_H

#ifdef __cplusplus
extern "C" {
#endif

#include <string.h>
#include <stdint.h>
#include "rl.h"

#define RL_SCRATCH_AREA_MAX_NUM_TOUCH_POINTS 16
#define RL_SCRATCH_AREA_MAX_NUM_MOUSE_BUTTONS 3
#define RL_SCRATCH_AREA_MAX_NUM_KEYBOARD_KEYS 512
#define RL_SCRATCH_AREA_MAX_NUM_GAMEPADS 4
#define RL_SCRATCH_AREA_MAX_NUM_GAMEPAD_AXIS 4
#define RL_SCRATCH_AREA_NUM_GAMEPAD_BUTTONS 16

typedef struct
{
    int x;
    int y;
    int wheel;
    int buttons[3]; // left, right, middle
} rl_mouse_t;

typedef struct
{
    int max_num_keys;
    int keys[RL_SCRATCH_AREA_MAX_NUM_KEYBOARD_KEYS];
    int last_key;
    int last_char;
} rl_keyboard_t;

typedef struct
{
        int id;
        float axis[RL_SCRATCH_AREA_MAX_NUM_GAMEPAD_AXIS];
        int buttons[RL_SCRATCH_AREA_NUM_GAMEPAD_BUTTONS];
} rl_gamepad_t;

typedef struct
{
    int max_num_gamepads;
    rl_gamepad_t gamepad[RL_SCRATCH_AREA_MAX_NUM_GAMEPADS];
} rl_gamepads_t;

typedef struct
{
    int id;
    int x;
    int y;
    float pressure;
} rl_touchpoint_t;

typedef struct
{
    int count;
    rl_touchpoint_t touchpoint[RL_SCRATCH_AREA_MAX_NUM_TOUCH_POINTS];
} rl_touchpoints_t;

// Shared Scratch Area
typedef struct
{
    float vector2[2]; // x, y for scratch Vector2
    float vector3[3];
    float vector4[4];
    float matrix[16];
    float quaternion[4];
    int color[4];
    int rect[4];

    rl_mouse_t mouse;

    rl_keyboard_t keyboard;

    rl_gamepads_t gamepads;

    rl_touchpoints_t touchpoints;

} rl_scratch_area_t;

// Offsets structure for JavaScript
typedef struct
{
    size_t vector2;
    size_t vector3;
    size_t vector4;
    size_t matrix;
    size_t quaternion;
    size_t color;
    size_t rect;
    struct
    {
        size_t x;
        size_t y;
        size_t wheel;
        size_t buttons;
    } mouse;
    struct
    {
        size_t max_num_keys;
        size_t keys;
        size_t last_key;
        size_t last_char;
    } keyboard;
    struct
    {
        size_t max_num_gamepads;
        size_t gamepad;        // base offset of gamepad array
        size_t id;     // offset to first gamepad's id
        size_t axis;           // offset to first gamepad's axes
        size_t buttons;        // offset to first gamepad's buttons
        size_t stride; // bytes between gamepads
    } gamepads;
    struct
    {
        size_t count;
        size_t touchpoint;          // base offset of touch array
        size_t id;       // offset to first touch point's id
        size_t x;         // offset to first touch point's x
        size_t y;         // offset to first touch point's y
        size_t stride;   // bytes between touch points
    } touchpoints;
} rl_scratch_area_offsets_t;

void rl_scratch_area_init();
void rl_scratch_area_deinit();
void rl_scratch_area_set_vector2(float x, float y);
void rl_scratch_area_set_vector3(float x, float y, float z);
void rl_scratch_area_set_vector4(float x, float y, float z, float w);
void rl_scratch_area_set_matrix(float m[16]);
void rl_scratch_area_set_quaternion(float x, float y, float z, float w);
void rl_scratch_area_set_color(int r, int g, int b, int a);
void rl_scratch_area_set_rect(int x, int y, int width, int height);
void rl_scratch_area_set_mouse(int x, int y, int wheel, int left, int right, int middle);
void rl_scratch_area_set_keyboard_key(int key, int state);

void rl_scratch_area_set_gamepad_axis(int id, int axis, float value);
void rl_scratch_area_set_gamepad_button(int id, int button, int state);
void rl_scratch_area_set_touchpoint(int index, int x, int y, int id);

// Return the Pointer as an Integer, otherwise emscripten tries to convert it to a BigInt
uintptr_t rl_scratch_area_get();

vec2_t rl_scratch_area_get_vector2();
vec3_t rl_scratch_area_get_vector3();
vec4_t rl_scratch_area_get_vector4();
matrix_t rl_scratch_area_get_matrix();
quat_t rl_scratch_area_get_quaternion();
color_t rl_scratch_area_get_color();
rect_t rl_scratch_area_get_rect();
rl_mouse_t rl_scratch_area_get_mouse();
rl_keyboard_t rl_scratch_area_get_keyboard();
rl_gamepads_t rl_scratch_area_get_gamepads();
rl_gamepad_t rl_scratch_area_get_gamepad(int id);
rl_touchpoints_t rl_scratch_area_get_touchpoints();
rl_touchpoint_t rl_scratch_area_get_touchpoint(int id);

void rl_scratch_area_clear();
void rl_scratch_area_update();

const rl_scratch_area_offsets_t *rl_scratch_area_get_offsets(void);

#ifdef __cplusplus
}
#endif

#endif // RL_SCRATCH_H