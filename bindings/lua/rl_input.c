/* rl_input.c - Lua input bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl.h"
#include "rl_input.h"

static void rl_push_mouse_state(lua_State *L, rl_mouse_state_t state)
{
    int i;

    lua_newtable(L);

    lua_pushinteger(L, state.x);
    lua_setfield(L, -2, "x");

    lua_pushinteger(L, state.y);
    lua_setfield(L, -2, "y");

    lua_pushinteger(L, state.wheel);
    lua_setfield(L, -2, "wheel");

    lua_pushinteger(L, state.left);
    lua_setfield(L, -2, "left");

    lua_pushinteger(L, state.right);
    lua_setfield(L, -2, "right");

    lua_pushinteger(L, state.middle);
    lua_setfield(L, -2, "middle");

    lua_newtable(L);
    for (i = 0; i < 3; i++) {
        lua_pushinteger(L, state.buttons[i]);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, -2, "buttons");
}

static void rl_push_keyboard_state(lua_State *L, rl_keyboard_state_t state)
{
    int i;

    lua_newtable(L);

    lua_pushinteger(L, state.max_num_keys);
    lua_setfield(L, -2, "max_num_keys");

    lua_pushinteger(L, state.pressed_key);
    lua_setfield(L, -2, "pressed_key");

    lua_pushinteger(L, state.pressed_char);
    lua_setfield(L, -2, "pressed_char");

    lua_pushinteger(L, state.num_pressed_keys);
    lua_setfield(L, -2, "num_pressed_keys");

    lua_pushinteger(L, state.num_pressed_chars);
    lua_setfield(L, -2, "num_pressed_chars");

    lua_newtable(L);
    for (i = 0; i < state.max_num_keys && i < RL_KEYBOARD_MAX_KEYS; i++) {
        lua_pushinteger(L, state.keys[i]);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, -2, "keys");

    lua_newtable(L);
    for (i = 0; i < state.num_pressed_keys && i < RL_KEYBOARD_MAX_PRESSED_KEYS; i++) {
        lua_pushinteger(L, state.pressed_keys[i]);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, -2, "pressed_keys");

    lua_newtable(L);
    for (i = 0; i < state.num_pressed_chars && i < RL_KEYBOARD_MAX_PRESSED_CHARS; i++) {
        lua_pushinteger(L, state.pressed_chars[i]);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, -2, "pressed_chars");
}

static int rl_input_get_mouse_position_lua(lua_State *L)
{
    vec2_t mouse = rl_input_get_mouse_position();
    lua_pushnumber(L, mouse.x);
    lua_pushnumber(L, mouse.y);
    return 2;
}

static int rl_input_get_mouse_wheel_lua(lua_State *L)
{
    (void)L;
    lua_pushinteger(L, rl_input_get_mouse_wheel());
    return 1;
}

static int rl_input_get_mouse_button_lua(lua_State *L)
{
    int button = (int)luaL_checkinteger(L, 1);
    lua_pushinteger(L, rl_input_get_mouse_button(button));
    return 1;
}

static int rl_input_get_mouse_state_lua(lua_State *L)
{
    rl_push_mouse_state(L, rl_input_get_mouse_state());
    return 1;
}

static int rl_input_get_keyboard_state_lua(lua_State *L)
{
    rl_push_keyboard_state(L, rl_input_get_keyboard_state());
    return 1;
}

void rl_register_input_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_input_get_mouse_position_lua);
    lua_setfield(L, -2, "input_get_mouse_position");

    lua_pushcfunction(L, rl_input_get_mouse_wheel_lua);
    lua_setfield(L, -2, "input_get_mouse_wheel");

    lua_pushcfunction(L, rl_input_get_mouse_button_lua);
    lua_setfield(L, -2, "input_get_mouse_button");

    lua_pushcfunction(L, rl_input_get_mouse_state_lua);
    lua_setfield(L, -2, "input_get_mouse_state");

    lua_pushcfunction(L, rl_input_get_keyboard_state_lua);
    lua_setfield(L, -2, "input_get_keyboard_state");
}
