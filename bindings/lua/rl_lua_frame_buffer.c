/* rl_frame_buffer.c - Lua frame buffer submission bindings for librl */

#include <lua.h>
#include <lauxlib.h>

//#include "rl.h"
#include "rl_sprite2d.h"
#include "rl_sprite3d.h"
#include "rl_model.h"
#include "rl_lua_frame_buffer.h"

/* Version and flags */
#define RL_SUBMIT_VERSION 1
#define RL_SUBMIT_FLAG_DEBUG_TAGS         0x01  /* Reserved for debug mode */
#define RL_SUBMIT_FLAG_INCLUDES_TYPE_TAG  0x02  /* Each section prefixed with [type_tag, count] */

/* Compile-time format configuration */
/* Define RL_FRAME_BUFFER_INCLUDE_TYPE_TAG to enable type tag checking */
/* Default: enabled for debug builds, disabled for release */
#ifndef RL_FRAME_BUFFER_INCLUDE_TYPE_TAG
#ifdef NDEBUG
#define RL_FRAME_BUFFER_INCLUDE_TYPE_TAG 0
#else
#define RL_FRAME_BUFFER_INCLUDE_TYPE_TAG 1
#endif
#endif

/* Section type tags (for type_tag mode) */
#define TYPE_SPRITE2D_XFORM 10
#define TYPE_SPRITE2D_DRAW  11
#define TYPE_SPRITE3D_XFORM 12
#define TYPE_SPRITE3D_DRAW  13
#define TYPE_MODEL_XFORM    14
#define TYPE_MODEL_DRAW     15

static int rl_frame_buffer_submit(lua_State *L)
{
    int version;
    int flags;
    int idx = 1;  /* Lua tables are 1-indexed */
    int table_idx = 1;
    int i, count;
    rl_handle_t handle, tint;
    float x, y, z, scale, rotation, size;
    float rot_x, rot_y, rot_z, scale_x, scale_y, scale_z;

    /* Check argument is a table */
    luaL_checktype(L, 1, LUA_TTABLE);

    /* Read VERSION */
    lua_rawgeti(L, table_idx, idx++);
    version = (int)luaL_checkinteger(L, -1);
    lua_pop(L, 1);

    if (version != RL_SUBMIT_VERSION) {
        return luaL_error(L, "rl_frame_buffer_submit: unsupported version %d", version);
    }

    /* Read FLAGS */
    lua_rawgeti(L, table_idx, idx++);
    flags = (int)luaL_checkinteger(L, -1);
    lua_pop(L, 1);

    /* Validate FLAGS matches compile-time configuration */
    {
        int expected_flags = 0;
#if RL_FRAME_BUFFER_INCLUDE_TYPE_TAG
        expected_flags |= RL_SUBMIT_FLAG_INCLUDES_TYPE_TAG;
#endif
        if ((flags & RL_SUBMIT_FLAG_INCLUDES_TYPE_TAG) != (expected_flags & RL_SUBMIT_FLAG_INCLUDES_TYPE_TAG)) {
            return luaL_error(L, "rl_frame_buffer_submit: FLAGS mismatch (compile-time type_tag=%d, runtime=%d)",
                              RL_FRAME_BUFFER_INCLUDE_TYPE_TAG, (flags & RL_SUBMIT_FLAG_INCLUDES_TYPE_TAG) ? 1 : 0);
        }
    }

    /* Helper macro to read section header - compile-time optimized */
#if RL_FRAME_BUFFER_INCLUDE_TYPE_TAG
#define READ_SECTION_HEADER(expected_type) \
    do { \
        int type_tag; \
        lua_rawgeti(L, table_idx, idx++); \
        type_tag = (int)luaL_checkinteger(L, -1); \
        lua_pop(L, 1); \
        if (type_tag != (expected_type)) { \
            return luaL_error(L, "rl_frame_buffer_submit: type mismatch, expected %d got %d", (expected_type), type_tag); \
        } \
        lua_rawgeti(L, table_idx, idx++); \
        count = (int)luaL_checkinteger(L, -1); \
        lua_pop(L, 1); \
    } while (0)
#else
#define READ_SECTION_HEADER(expected_type) \
    do { \
        lua_rawgeti(L, table_idx, idx++); \
        count = (int)luaL_checkinteger(L, -1); \
        lua_pop(L, 1); \
    } while (0)
#endif

    /* Process sections in fixed order */
    READ_SECTION_HEADER(TYPE_SPRITE2D_XFORM);
    if (count > 0) {
        for (i = 0; i < count; i++) {
            lua_rawgeti(L, table_idx, idx++);
            handle = (rl_handle_t)luaL_checkinteger(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            tint = (rl_handle_t)luaL_checkinteger(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            x = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            y = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            scale = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            rotation = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
            rl_sprite2d_set_transform(handle, x, y, scale, rotation);
        }
    }

    READ_SECTION_HEADER(TYPE_SPRITE2D_DRAW);
    if (count > 0) {
        for (i = 0; i < count; i++) {
            lua_rawgeti(L, table_idx, idx++);
            handle = (rl_handle_t)luaL_checkinteger(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            tint = (rl_handle_t)luaL_checkinteger(L, -1);
            lua_pop(L, 1);
            rl_sprite2d_draw(handle, tint);
        }
    }

    READ_SECTION_HEADER(TYPE_SPRITE3D_XFORM);
    if (count > 0) {
        for (i = 0; i < count; i++) {
            lua_rawgeti(L, table_idx, idx++);
            handle = (rl_handle_t)luaL_checkinteger(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            tint = (rl_handle_t)luaL_checkinteger(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            x = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            y = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            z = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            size = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
            rl_sprite3d_set_transform(handle, x, y, z, size);
        }
    }

    READ_SECTION_HEADER(TYPE_SPRITE3D_DRAW);
    if (count > 0) {
        for (i = 0; i < count; i++) {
            lua_rawgeti(L, table_idx, idx++);
            handle = (rl_handle_t)luaL_checkinteger(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            tint = (rl_handle_t)luaL_checkinteger(L, -1);
            lua_pop(L, 1);
            rl_sprite3d_draw(handle, tint);
        }
    }

    READ_SECTION_HEADER(TYPE_MODEL_XFORM);
    if (count > 0) {
        for (i = 0; i < count; i++) {
            lua_rawgeti(L, table_idx, idx++);
            handle = (rl_handle_t)luaL_checkinteger(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            x = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            y = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            z = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            rot_x = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            rot_y = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            rot_z = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            scale_x = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            scale_y = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            scale_z = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
            rl_model_set_transform(handle, x, y, z, rot_x, rot_y, rot_z, scale_x, scale_y, scale_z);
        }
    }

    READ_SECTION_HEADER(TYPE_MODEL_DRAW);
    if (count > 0) {
        for (i = 0; i < count; i++) {
            lua_rawgeti(L, table_idx, idx++);
            handle = (rl_handle_t)luaL_checkinteger(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, table_idx, idx++);
            tint = (rl_handle_t)luaL_checkinteger(L, -1);
            lua_pop(L, 1);
            rl_model_draw(handle, tint);
        }
    }

#undef READ_SECTION_HEADER

    lua_pushinteger(L, idx - 1);  /* Return number of elements consumed */
    return 1;
}

static int rl_frame_buffer_get_format(lua_State *L)
{
    int flags = 0;
#if RL_FRAME_BUFFER_INCLUDE_TYPE_TAG
    flags |= RL_SUBMIT_FLAG_INCLUDES_TYPE_TAG;
#endif
    lua_pushinteger(L, RL_SUBMIT_VERSION);
    lua_pushinteger(L, flags);
    return 2;
}

void rl_register_frame_buffer_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_frame_buffer_submit);
    lua_setfield(L, -2, "frame_buffer_submit");

    lua_pushcfunction(L, rl_frame_buffer_get_format);
    lua_setfield(L, -2, "frame_buffer_get_format");
}
