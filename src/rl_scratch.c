#include <string.h>
#include "raylib.h"
#include "internal/exports.h"
//#include <stdlib.h>
#include <stdio.h>
#include "rl_scratch.h"
#include <stddef.h>

RL_KEEP
static rl_scratch_area_offsets_t rl_scratch_offsets;

RL_KEEP
const rl_scratch_area_offsets_t *rl_scratch_area_get_offsets(void)
{
    rl_scratch_offsets = (rl_scratch_area_offsets_t){
        .vector2 = offsetof(rl_scratch_area_t, vector2),
        .vector3 = offsetof(rl_scratch_area_t, vector3),
        .vector4 = offsetof(rl_scratch_area_t, vector4),
        .matrix = offsetof(rl_scratch_area_t, matrix),
        .quaternion = offsetof(rl_scratch_area_t, quaternion),
        .color = offsetof(rl_scratch_area_t, color),
        .rect = offsetof(rl_scratch_area_t, rect),
        .mouse = {
            .x = offsetof(rl_scratch_area_t, mouse.x),
            .y = offsetof(rl_scratch_area_t, mouse.y),
            .wheel = offsetof(rl_scratch_area_t, mouse.wheel),
            .buttons = offsetof(rl_scratch_area_t, mouse.buttons)},
        .keyboard = {
            .max_num_keys = offsetof(rl_scratch_area_t, keyboard.max_num_keys), 
            .keys = offsetof(rl_scratch_area_t, keyboard.keys), 
            .last_key = offsetof(rl_scratch_area_t, keyboard.last_key), 
            .last_char = offsetof(rl_scratch_area_t, keyboard.last_char)
        },
        .gamepads = {
            .max_num_gamepads = offsetof(rl_scratch_area_t, gamepads.max_num_gamepads),
            .gamepad = offsetof(rl_scratch_area_t, gamepads.gamepad),
            .id = offsetof(rl_scratch_area_t, gamepads.gamepad[0].id),
            .axis = offsetof(rl_scratch_area_t, gamepads.gamepad[0].axis),
            .buttons = offsetof(rl_scratch_area_t, gamepads.gamepad[0].buttons),
            .stride = sizeof(((rl_scratch_area_t *)0)->gamepads.gamepad[0]),
        },
        .touchpoints = {
            .count = offsetof(rl_scratch_area_t, touchpoints.count), 
            .touchpoint = offsetof(rl_scratch_area_t, touchpoints.touchpoint), 
            .x = offsetof(rl_scratch_area_t, touchpoints.touchpoint[0].x), 
            .y = offsetof(rl_scratch_area_t, touchpoints.touchpoint[0].y),
            .id = offsetof(rl_scratch_area_t, touchpoints.touchpoint[0].id), 
            .stride = sizeof(((rl_scratch_area_t *)0)->touchpoints.touchpoint[0]),
        }
    };
    return &rl_scratch_offsets;
}

static rl_scratch_area_t rl_scratch_area;

void rl_scratch_area_set_vector2(float x, float y)
{
    rl_scratch_area.vector2[0] = x;
    rl_scratch_area.vector2[1] = y;
}

void rl_scratch_area_set_vector3(float x, float y, float z)
{
    rl_scratch_area.vector3[0] = x;
    rl_scratch_area.vector3[1] = y;
    rl_scratch_area.vector3[2] = z;
}

void rl_scratch_area_set_vector4(float x, float y, float z, float w)
{
    rl_scratch_area.vector4[0] = x;
    rl_scratch_area.vector4[1] = y;
    rl_scratch_area.vector4[2] = z;
    rl_scratch_area.vector4[3] = w;
}

void rl_scratch_area_set_matrix(float m[16])
{
    memcpy(rl_scratch_area.matrix, m, sizeof(float) * 16);
}

void rl_scratch_area_set_quaternion(float x, float y, float z, float w)
{
    rl_scratch_area.quaternion[0] = x;
    rl_scratch_area.quaternion[1] = y;
    rl_scratch_area.quaternion[2] = z;
    rl_scratch_area.quaternion[3] = w;
}

void rl_scratch_area_set_color(int r, int g, int b, int a)
{
    rl_scratch_area.color[0] = r;
    rl_scratch_area.color[1] = g;
    rl_scratch_area.color[2] = b;
    rl_scratch_area.color[3] = a;
}

void rl_scratch_area_set_rect(int x, int y, int width, int height)
{
    rl_scratch_area.rect[0] = x;
    rl_scratch_area.rect[1] = y;
    rl_scratch_area.rect[2] = width;
    rl_scratch_area.rect[3] = height;
}

void rl_scratch_area_set_mouse(int x, int y, int wheel, int left, int right, int middle)
{
    rl_scratch_area.mouse.x = x;
    rl_scratch_area.mouse.y = y;
    rl_scratch_area.mouse.wheel = wheel;
    rl_scratch_area.mouse.buttons[0] = left;
    rl_scratch_area.mouse.buttons[1] = right;
    rl_scratch_area.mouse.buttons[2] = middle;
}

void rl_scratch_area_set_touch(int index, int x, int y, int id)
{
    rl_scratch_area.touchpoints.count = index + 1;
    rl_scratch_area.touchpoints.touchpoint[index].x = x;
    rl_scratch_area.touchpoints.touchpoint[index].y = y;
    rl_scratch_area.touchpoints.touchpoint[index].id = id;
}

void rl_scratch_area_set_keyboard_key(int key, int state)
{
    rl_scratch_area.keyboard.keys[key] = state;
    if (state == 1)
    {
        rl_scratch_area.keyboard.last_key = key;
        rl_scratch_area.keyboard.last_char = key;
    }
}

void rl_scratch_area_set_gamepad_axis(int id, int axis, float value)
{
    rl_scratch_area.gamepads.gamepad[id].axis[axis] = value;
}

void rl_scratch_area_set_gamepad_button(int id, int button, int state)
{
    rl_scratch_area.gamepads.gamepad[id].buttons[button] = state;
}

// Return the struct pointer as an uintptr, otherwise emscripten tries to convert it to a BigInt
RL_KEEP
uintptr_t rl_scratch_area_get()
{
    return (uintptr_t)&rl_scratch_area;
}

RL_KEEP
void rl_scratch_area_clear()
{
    memset(&rl_scratch_area, 0, sizeof(rl_scratch_area_t));

    rl_scratch_area.keyboard.max_num_keys = RL_SCRATCH_AREA_MAX_NUM_KEYBOARD_KEYS;
    rl_scratch_area.gamepads.max_num_gamepads = RL_SCRATCH_AREA_MAX_NUM_GAMEPADS;
}

void rl_scratch_area_init()
{
    rl_scratch_area_clear();
}

void rl_scratch_area_deinit()
{
    // do nothing?
    //printf("rl_scratch_area_deinit\n");
}

RL_KEEP
void rl_scratch_area_update()
{
    // TODO: num mouse buttons (currently assumed to be 3)

    // mouse
    int mouse_button_status_0 = 0;
    int mouse_button_status_1 = 0;
    int mouse_button_status_2 = 0;

    if (IsMouseButtonPressed(MOUSE_BUTTON_LEFT))
    {
        mouse_button_status_0 = 1; // just pressed
    }
    if (IsMouseButtonDown(MOUSE_BUTTON_LEFT))
    {
        mouse_button_status_0 = 2; // held
    }
    if (IsMouseButtonReleased(MOUSE_BUTTON_LEFT))
    {
        mouse_button_status_0 = 3; // just released
    }

    if (IsMouseButtonPressed(MOUSE_BUTTON_RIGHT))
    {
        mouse_button_status_1 = 1; // just pressed
    }
    if (IsMouseButtonDown(MOUSE_BUTTON_RIGHT))
    {
        mouse_button_status_1 = 2; // held
    }
    if (IsMouseButtonReleased(MOUSE_BUTTON_RIGHT))
    {
        mouse_button_status_1 = 3; // just released
    }

    if (IsMouseButtonPressed(MOUSE_BUTTON_MIDDLE))
    {
        mouse_button_status_2 = 1; // just pressed
    }
    if (IsMouseButtonDown(MOUSE_BUTTON_MIDDLE))
    {
        mouse_button_status_2 = 2; // held
    }
    if (IsMouseButtonReleased(MOUSE_BUTTON_MIDDLE))
    {
        mouse_button_status_2 = 3; // just released
    }

    rl_scratch_area_set_mouse(GetMouseX(), GetMouseY(), GetMouseWheelMove(), mouse_button_status_0, mouse_button_status_1, mouse_button_status_2);

    // keyboard
    for (int i = 0; i < RL_SCRATCH_AREA_MAX_NUM_KEYBOARD_KEYS; i++)
    {
        int key_status = 0;
        if (IsKeyPressed(i))
        {
            key_status = 1; // just pressed
            // fprintf(stderr, "key %d just pressed\n", i);
        }
        if (IsKeyDown(i))
        {
            key_status = 2; // held
        }
        if (IsKeyReleased(i))
        {
            key_status = 3; // just released
        }
        rl_scratch_area_set_keyboard_key(i, key_status);
    }

    // gamepad
    for (int id = 0; id < RL_SCRATCH_AREA_MAX_NUM_GAMEPADS; id++)
    {
        if (!IsGamepadAvailable(id))
        {
            continue;
        }
        for (int i = 0; i < RL_SCRATCH_AREA_NUM_GAMEPAD_BUTTONS; i++)
        {
            int button_status = 0;
            if (IsGamepadButtonPressed(id, i))
            {
                button_status = 1; // just pressed
            }
            if (IsGamepadButtonDown(id, i))
            {
                button_status = 2; // held
            }
            if (IsGamepadButtonReleased(id, i))
            {
                button_status = 3; // just released
            }
            rl_scratch_area_set_gamepad_button(id, i, button_status);
        }

        // gamepad axis
        int num_axis = GetGamepadAxisCount(id);
        if (num_axis < RL_SCRATCH_AREA_MAX_NUM_GAMEPAD_AXIS)
        {
            fprintf(stderr, "Gamepad %d has %d axis, more than we allocated for (%d)\n", id, GetGamepadAxisCount(id), RL_SCRATCH_AREA_MAX_NUM_GAMEPAD_AXIS);
            continue;
        }

        for (int i = 0; i < num_axis; i++)
        {
            rl_scratch_area_set_gamepad_axis(id, i, GetGamepadAxisMovement(id, i));
        }
    }

    // touch
    if (GetTouchPointCount() > 0)
    {
        // set the touch point 0
        rl_scratch_area_set_touch(0, GetTouchX(), GetTouchY(), GetTouchPointId(0));

        // set the other touch points
        for (int i = 1; i < GetTouchPointCount(); i++)
        {
            Vector2 position = GetTouchPosition(i);
            rl_scratch_area_set_touch(i, position.x, position.y, GetTouchPointId(i));
        }
    }
    else
    {
        rl_scratch_area_set_touch(0, 0, 0, 0);
    }
}

vec2_t rl_scratch_area_get_vector2()
{
    vec2_t v2;
    v2.x = rl_scratch_area.vector2[0];
    v2.y = rl_scratch_area.vector2[1];
    return v2;
}

vec3_t rl_scratch_area_get_vector3()
{
    vec3_t v3;
    v3.x = rl_scratch_area.vector3[0];
    v3.y = rl_scratch_area.vector3[1];
    v3.z = rl_scratch_area.vector3[2];
    return v3;
}

vec4_t rl_scratch_area_get_vector4()
{
    vec4_t v4;
    v4.x = rl_scratch_area.vector4[0];
    v4.y = rl_scratch_area.vector4[1];
    v4.z = rl_scratch_area.vector4[2];
    v4.w = rl_scratch_area.vector4[3];
    return v4;
}

matrix_t rl_scratch_area_get_matrix()
{
    matrix_t m;
    m.m0 = rl_scratch_area.matrix[0];
    m.m1 = rl_scratch_area.matrix[1];
    m.m2 = rl_scratch_area.matrix[2];
    m.m3 = rl_scratch_area.matrix[3];
    m.m4 = rl_scratch_area.matrix[4];
    m.m5 = rl_scratch_area.matrix[5];
    m.m6 = rl_scratch_area.matrix[6];
    m.m7 = rl_scratch_area.matrix[7];
    m.m8 = rl_scratch_area.matrix[8];
    m.m9 = rl_scratch_area.matrix[9];
    m.m10 = rl_scratch_area.matrix[10];
    m.m11 = rl_scratch_area.matrix[11];
    m.m12 = rl_scratch_area.matrix[12];
    m.m13 = rl_scratch_area.matrix[13];
    m.m14 = rl_scratch_area.matrix[14];
    m.m15 = rl_scratch_area.matrix[15];
    return m;
}

quat_t rl_scratch_area_get_quaternion()
{
    quat_t q;
    q.x = rl_scratch_area.quaternion[0];
    q.y = rl_scratch_area.quaternion[1];
    q.z = rl_scratch_area.quaternion[2];
    q.w = rl_scratch_area.quaternion[3];
    return q;
}

color_t rl_scratch_area_get_color()
{
    color_t c;
    c.r = rl_scratch_area.color[0];
    c.g = rl_scratch_area.color[1];
    c.b = rl_scratch_area.color[2];
    c.a = rl_scratch_area.color[3];
    return c;
}

rect_t rl_scratch_area_get_rect()
{
    rect_t r;
    r.x = rl_scratch_area.rect[0];
    r.y = rl_scratch_area.rect[1];
    r.width = rl_scratch_area.rect[2];
    r.height = rl_scratch_area.rect[3];
    return r;
}

rl_mouse_t rl_scratch_area_get_mouse()
{
    return rl_scratch_area.mouse;
}

rl_keyboard_t rl_scratch_area_get_keyboard()
{
    return rl_scratch_area.keyboard;
}

rl_gamepad_t rl_scratch_area_get_gamepad(int id)
{
    return rl_scratch_area.gamepads.gamepad[id];
}

rl_touchpoint_t rl_scratch_area_get_touchpoint(int id) {
    return rl_scratch_area.touchpoints.touchpoint[id];
}