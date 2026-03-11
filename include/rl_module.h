#ifndef RL_MODULE_H
#define RL_MODULE_H

#include <stddef.h>
#include "rl_types.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum rl_module_log_level_t {
    RL_MODULE_LOG_TRACE = 0,
    RL_MODULE_LOG_DEBUG = 1,
    RL_MODULE_LOG_INFO = 2,
    RL_MODULE_LOG_WARN = 3,
    RL_MODULE_LOG_ERROR = 4
} rl_module_log_level_t;

typedef enum rl_module_frame_command_type_t {
    RL_MODULE_FRAME_CMD_CLEAR = 0,
    RL_MODULE_FRAME_CMD_DRAW_TEXT = 1,
    RL_MODULE_FRAME_CMD_DRAW_SPRITE3D = 2,
    RL_MODULE_FRAME_CMD_PLAY_SOUND = 3
} rl_module_frame_command_type_t;

#define RL_MODULE_FRAME_TEXT_MAX 256

typedef struct rl_module_frame_clear_t {
    rl_handle_t color;
} rl_module_frame_clear_t;

typedef struct rl_module_frame_draw_text_t {
    rl_handle_t font;
    rl_handle_t color;
    float x;
    float y;
    float font_size;
    float spacing;
    char text[RL_MODULE_FRAME_TEXT_MAX];
} rl_module_frame_draw_text_t;

typedef struct rl_module_frame_draw_sprite3d_t {
    rl_handle_t sprite;
    rl_handle_t tint;
    float x;
    float y;
    float z;
    float size;
} rl_module_frame_draw_sprite3d_t;

typedef struct rl_module_frame_play_sound_t {
    rl_handle_t sound;
} rl_module_frame_play_sound_t;

typedef struct rl_module_frame_command_t {
    int type;
    union {
        rl_module_frame_clear_t clear;
        rl_module_frame_draw_text_t draw_text;
        rl_module_frame_draw_sprite3d_t draw_sprite3d;
        rl_module_frame_play_sound_t play_sound;
    } data;
} rl_module_frame_command_t;

typedef void (*rl_module_log_fn)(void *user_data, int level, const char *message);
typedef void (*rl_module_log_source_fn)(void *user_data, int level, const char *source_file,
                                        int source_line, const char *message);
typedef void *(*rl_module_alloc_fn)(size_t size, void *user_data);
typedef void (*rl_module_free_fn)(void *ptr, void *user_data);
typedef void (*rl_module_event_listener_fn)(void *payload, void *listener_user_data);
typedef void (*rl_module_frame_command_fn)(void *host_user_data, const rl_module_frame_command_t *command);
typedef int (*rl_module_event_on_fn)(void *host_user_data, const char *event_name,
                                    rl_module_event_listener_fn listener, void *listener_user_data);
typedef int (*rl_module_event_off_fn)(void *host_user_data, const char *event_name,
                                     rl_module_event_listener_fn listener, void *listener_user_data);
typedef int (*rl_module_event_emit_fn)(void *host_user_data, const char *event_name, void *payload);

typedef struct rl_module_host_api_t {
    void *user_data;
    rl_module_log_fn log;
    rl_module_log_source_fn log_source;
    rl_module_alloc_fn alloc;
    rl_module_free_fn free;
    rl_module_event_on_fn event_on;
    rl_module_event_off_fn event_off;
    rl_module_event_emit_fn event_emit;
    rl_module_frame_command_fn frame_command;
} rl_module_host_api_t;

typedef int (*rl_module_init_fn)(const rl_module_host_api_t *host, void **module_state);
typedef void (*rl_module_deinit_fn)(void *module_state);
typedef int (*rl_module_update_fn)(void *module_state, float dt_seconds);

typedef struct rl_module_api_t {
    const char *name;
    int abi_version;
    rl_module_init_fn init;
    rl_module_deinit_fn deinit;
    rl_module_update_fn update;
} rl_module_api_t;

typedef struct rl_module_instance_t {
    const rl_module_api_t *api;
    void *state;
} rl_module_instance_t;

typedef struct rl_module_entry_t {
    const char *name;
    const rl_module_api_t *(*get_api_fn)(void);
} rl_module_entry_t;

#define RL_MODULE_ABI_VERSION 1

/*
 * Compile-time module registration helper.
 * Usage: rl_module_register(lua)
 * Note: argument is a token, not a string literal.
 */
#define rl_module_register(name_token) { #name_token, rl_##name_token##_module_get_api }

void rl_module_log(const rl_module_host_api_t *host, int level, const char *message);
void rl_module_log_source(const rl_module_host_api_t *host, int level, const char *source_file,
                          int source_line, const char *message);
void *rl_module_alloc(const rl_module_host_api_t *host, size_t size);
void rl_module_free(const rl_module_host_api_t *host, void *ptr);
int rl_module_event_on(const rl_module_host_api_t *host, const char *event_name,
                      rl_module_event_listener_fn listener, void *listener_user_data);
int rl_module_event_off(const rl_module_host_api_t *host, const char *event_name,
                       rl_module_event_listener_fn listener, void *listener_user_data);
int rl_module_event_emit(const rl_module_host_api_t *host, const char *event_name, void *payload);
void rl_module_frame_command(const rl_module_host_api_t *host, const rl_module_frame_command_t *command);
int rl_module_api_validate(const rl_module_api_t *api, char *error, size_t error_size);
int rl_module_init_instance(const rl_module_api_t *api, const rl_module_host_api_t *host, void **module_state,
                           char *error, size_t error_size);
void rl_module_deinit_instance(const rl_module_api_t *api, void *module_state);
const rl_module_api_t *rl_module_get_api(const char *name);
int rl_module_init(const char *name, const rl_module_host_api_t *host, const rl_module_api_t **out_api,
                  void **module_state, char *error, size_t error_size);

#define RL_MODULE_DEFINE(GETTER_FN, MODULE_NAME, INIT_FN, DEINIT_FN, UPDATE_FN) \
    const rl_module_api_t *GETTER_FN(void)                                      \
    {                                                                           \
        static const rl_module_api_t api = {                                    \
            (MODULE_NAME),                                                       \
            RL_MODULE_ABI_VERSION,                                               \
            (INIT_FN),                                                          \
            (DEINIT_FN),                                                        \
            (UPDATE_FN)                                                         \
        };                                                                      \
        return &api;                                                            \
    }

#ifdef __cplusplus
}
#endif

#endif // RL_MODULE_H
