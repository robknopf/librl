/*
 * lua_rl.c - Lua bindings for librl (direct API, no frame commands)
 *
 * Format: [VERSION, FLAGS, count_section, (data...), count_section, ...]
 * Fixed section order: sprite2d_xform, sprite2d_draw, sprite3d_xform, sprite3d_draw, model_xform, model_draw
 */

#include <lua.h>
#include <lauxlib.h>

#include "rl.h"

/* Lua 5.1 compatibility: luaL_newlib was added in 5.2 */
#if LUA_VERSION_NUM < 502
#define luaL_newlib(L, l) (lua_newtable(L), luaL_register(L, NULL, l))
#endif

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

/* Section indices (fixed order) */
#define SECTION_SPRITE2D_XFORM 0
#define SECTION_SPRITE2D_DRAW  1
#define SECTION_SPRITE3D_XFORM 2
#define SECTION_SPRITE3D_DRAW  3
#define SECTION_MODEL_XFORM    4
#define SECTION_MODEL_DRAW     5
#define SECTION_COUNT          6

/* Strides (values per entry) */
#define STRIDE_SPRITE2D_XFORM 6  /* handle, tint, x, y, scale, rotation */
#define STRIDE_SPRITE2D_DRAW  2  /* handle, tint */
#define STRIDE_SPRITE3D_XFORM 6  /* handle, tint, x, y, z, size */
#define STRIDE_SPRITE3D_DRAW  2  /* handle, tint */
#define STRIDE_MODEL_XFORM    10 /* handle, x, y, z, rot_x, rot_y, rot_z, scale_x, scale_y, scale_z */
#define STRIDE_MODEL_DRAW     2  /* handle, tint */

static int rl_submit_frame_buffer(lua_State *L)
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
        return luaL_error(L, "rl_submit_frame_buffer: unsupported version %d", version);
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
            return luaL_error(L, "rl_submit_frame_buffer: FLAGS mismatch (compile-time type_tag=%d, runtime=%d)",
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
                return luaL_error(L, "rl_submit_frame_buffer: type mismatch, expected %d got %d", (expected_type), type_tag); \
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
    /* SECTION_SPRITE2D_XFORM */
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

    /* SECTION_SPRITE2D_DRAW */
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

    /* SECTION_SPRITE3D_XFORM */
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

    /* SECTION_SPRITE3D_DRAW */
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

    /* SECTION_MODEL_XFORM */
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

    /* SECTION_MODEL_DRAW */
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

    /* Add additional sections here: texture, text, audio, etc. */

    lua_pushinteger(L, idx - 1);  /* Return number of elements consumed */
    return 1;
}

/* ============================================================================
 * Individual function bindings for vanilla Lua
 * ============================================================================ */

/* Window */
static int rl_window_close_binding(lua_State *L)
{
    (void)L;  /* Unused */
    rl_window_close();
    return 0;
}

static int rl_window_get_screen_size_binding(lua_State *L)
{
    vec2_t size = rl_window_get_screen_size();
    lua_pushnumber(L, size.x);
    lua_pushnumber(L, size.y);
    return 2;
}

/* Sprite2D */
static int rl_sprite2d_create_binding(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    rl_handle_t handle = rl_sprite2d_create(filename);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_sprite2d_create_from_texture_binding(lua_State *L)
{
    rl_handle_t texture = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t handle = rl_sprite2d_create_from_texture(texture);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_sprite2d_set_transform_binding(lua_State *L)
{
    rl_handle_t sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    float x = (float)luaL_checknumber(L, 2);
    float y = (float)luaL_checknumber(L, 3);
    float scale = (float)luaL_checknumber(L, 4);
    float rotation = (float)luaL_checknumber(L, 5);
    rl_sprite2d_set_transform(sprite, x, y, scale, rotation);
    return 0;
}

static int rl_sprite2d_draw_binding(lua_State *L)
{
    rl_handle_t sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t tint = (rl_handle_t)luaL_checkinteger(L, 2);
    rl_sprite2d_draw(sprite, tint);
    return 0;
}

static int rl_sprite2d_destroy_binding(lua_State *L)
{
    rl_handle_t sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_sprite2d_destroy(sprite);
    return 0;
}

/* Sprite3D */
static int rl_sprite3d_create_binding(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    rl_handle_t handle = rl_sprite3d_create(filename);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_sprite3d_create_from_texture_binding(lua_State *L)
{
    rl_handle_t texture = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t handle = rl_sprite3d_create_from_texture(texture);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_sprite3d_set_transform_binding(lua_State *L)
{
    rl_handle_t sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    float x = (float)luaL_checknumber(L, 2);
    float y = (float)luaL_checknumber(L, 3);
    float z = (float)luaL_checknumber(L, 4);
    float size = (float)luaL_checknumber(L, 5);
    rl_sprite3d_set_transform(sprite, x, y, z, size);
    return 0;
}

static int rl_sprite3d_draw_binding(lua_State *L)
{
    rl_handle_t sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t tint = (rl_handle_t)luaL_checkinteger(L, 2);
    rl_sprite3d_draw(sprite, tint);
    return 0;
}

static int rl_sprite3d_destroy_binding(lua_State *L)
{
    rl_handle_t sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_sprite3d_destroy(sprite);
    return 0;
}

/* Model */
static int rl_model_create_binding(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    rl_handle_t handle = rl_model_create(filename);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_model_set_transform_binding(lua_State *L)
{
    rl_handle_t model = (rl_handle_t)luaL_checkinteger(L, 1);
    float x = (float)luaL_checknumber(L, 2);
    float y = (float)luaL_checknumber(L, 3);
    float z = (float)luaL_checknumber(L, 4);
    float rot_x = (float)luaL_checknumber(L, 5);
    float rot_y = (float)luaL_checknumber(L, 6);
    float rot_z = (float)luaL_checknumber(L, 7);
    float scale_x = (float)luaL_checknumber(L, 8);
    float scale_y = (float)luaL_checknumber(L, 9);
    float scale_z = (float)luaL_checknumber(L, 10);
    rl_model_set_transform(model, x, y, z, rot_x, rot_y, rot_z, scale_x, scale_y, scale_z);
    return 0;
}

static int rl_model_draw_binding(lua_State *L)
{
    rl_handle_t model = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t tint = (rl_handle_t)luaL_optinteger(L, 2, 0);  /* default: RL_COLOR_WHITE */
    rl_model_draw(model, tint);
    return 0;
}

static int rl_model_destroy_binding(lua_State *L)
{
    rl_handle_t model = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_model_destroy(model);
    return 0;
}

/* Texture */
static int rl_texture_create_binding(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    rl_handle_t handle = rl_texture_create(filename);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_texture_destroy_binding(lua_State *L)
{
    rl_handle_t texture = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_texture_destroy(texture);
    return 0;
}

/* Color */
static int rl_color_create_binding(lua_State *L)
{
    int r = (int)luaL_checkinteger(L, 1);
    int g = (int)luaL_checkinteger(L, 2);
    int b = (int)luaL_checkinteger(L, 3);
    int a = (int)luaL_optinteger(L, 4, 255);
    rl_handle_t handle = rl_color_create(r, g, b, a);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_color_destroy_binding(lua_State *L)
{
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_color_destroy(color);
    return 0;
}

/* Camera3D */
static int rl_camera3d_create_binding(lua_State *L)
{
    float pos_x = (float)luaL_checknumber(L, 1);
    float pos_y = (float)luaL_checknumber(L, 2);
    float pos_z = (float)luaL_checknumber(L, 3);
    float target_x = (float)luaL_checknumber(L, 4);
    float target_y = (float)luaL_checknumber(L, 5);
    float target_z = (float)luaL_checknumber(L, 6);
    float up_x = (float)luaL_checknumber(L, 7);
    float up_y = (float)luaL_checknumber(L, 8);
    float up_z = (float)luaL_checknumber(L, 9);
    float fovy = (float)luaL_checknumber(L, 10);
    int projection = (int)luaL_checkinteger(L, 11);
    rl_handle_t handle = rl_camera3d_create(pos_x, pos_y, pos_z, target_x, target_y, target_z,
                                            up_x, up_y, up_z, fovy, projection);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_camera3d_destroy_binding(lua_State *L)
{
    rl_handle_t camera = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_camera3d_destroy(camera);
    return 0;
}

/* Core lifecycle */
static int rl_init_binding(lua_State *L)
{
    (void)L;  /* Unused */
    rl_init();
    return 0;
}

static int rl_deinit_binding(lua_State *L)
{
    (void)L;  /* Unused */
    rl_deinit();
    return 0;
}

static int rl_update_binding(lua_State *L)
{
    (void)L;  /* Unused */
    rl_update();
    return 0;
}

static int rl_begin_drawing_binding(lua_State *L)
{
    (void)L;  /* Unused */
    rl_render_begin();
    return 0;
}

static int rl_end_drawing_binding(lua_State *L)
{
    (void)L;  /* Unused */
    rl_render_end();
    return 0;
}

static int rl_clear_background_binding(lua_State *L)
{
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_render_clear_background(color);
    return 0;
}

/* Frame buffer format query - Lua calls this to know how to pack */
static int rl_get_frame_buffer_format_binding(lua_State *L)
{
    int flags = 0;
#if RL_FRAME_BUFFER_INCLUDE_TYPE_TAG
    flags |= RL_SUBMIT_FLAG_INCLUDES_TYPE_TAG;
#endif
    lua_pushinteger(L, RL_SUBMIT_VERSION);  /* version */
    lua_pushinteger(L, flags);               /* flags */
    return 2;
}

static const luaL_Reg rl_functions[] = {
    /* Batch submission (v2 encoding) */
    {"submit_frame_buffer", rl_submit_frame_buffer},
    {"get_frame_buffer_format", rl_get_frame_buffer_format_binding},

    /* Window */
    {"window_close", rl_window_close_binding},
    {"window_get_screen_size", rl_window_get_screen_size_binding},

    /* Sprite2D */
    {"sprite2d_create", rl_sprite2d_create_binding},
    {"sprite2d_create_from_texture", rl_sprite2d_create_from_texture_binding},
    {"sprite2d_set_transform", rl_sprite2d_set_transform_binding},
    {"sprite2d_draw", rl_sprite2d_draw_binding},
    {"sprite2d_destroy", rl_sprite2d_destroy_binding},

    /* Sprite3D */
    {"sprite3d_create", rl_sprite3d_create_binding},
    {"sprite3d_create_from_texture", rl_sprite3d_create_from_texture_binding},
    {"sprite3d_set_transform", rl_sprite3d_set_transform_binding},
    {"sprite3d_draw", rl_sprite3d_draw_binding},
    {"sprite3d_destroy", rl_sprite3d_destroy_binding},

    /* Model */
    {"model_create", rl_model_create_binding},
    {"model_set_transform", rl_model_set_transform_binding},
    {"model_draw", rl_model_draw_binding},
    {"model_destroy", rl_model_destroy_binding},

    /* Texture */
    {"texture_create", rl_texture_create_binding},
    {"texture_destroy", rl_texture_destroy_binding},

    /* Color */
    {"color_create", rl_color_create_binding},
    {"color_destroy", rl_color_destroy_binding},

    /* Camera3D */
    {"camera3d_create", rl_camera3d_create_binding},
    {"camera3d_destroy", rl_camera3d_destroy_binding},

    /* Core */
    {"init", rl_init_binding},
    {"deinit", rl_deinit_binding},
    {"update", rl_update_binding},
    {"begin_drawing", rl_begin_drawing_binding},
    {"end_drawing", rl_end_drawing_binding},
    {"clear_background", rl_clear_background_binding},

    {NULL, NULL}
};

int luaopen_rl(lua_State *L)
{
    luaL_newlib(L, rl_functions);
    return 1;
}
