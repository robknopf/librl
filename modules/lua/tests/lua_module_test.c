#include "rl_module_lua.h"
#include "rl_frame_command.h"
#include "fileio/fileio.h"

#include <stdio.h>
#include <string.h>

static rl_frame_command_buffer_t g_test_frame_buffer = {0};

typedef struct test_event_binding_t {
    char event_name[64];
    rl_module_event_listener_fn listener;
    void *listener_user_data;
} test_event_binding_t;

static test_event_binding_t g_event_bindings[32];
static int g_event_binding_count = 0;
static int g_test_event_count = 0;
static char g_last_test_payload[128];
static int g_module_log_count = 0;

static void test_log(void *user_data, int level, const char *message)
{
    (void)user_data;
    (void)level;
    (void)message;
    g_module_log_count++;
}

static void test_event_counter(void *payload, void *user_data)
{
    int *counter = (int *)user_data;
    (void)payload;
    if (counter != NULL) {
        (*counter)++;
    }
}

static void test_capture_payload(void *payload, void *user_data)
{
    int *counter = (int *)user_data;
    const char *text = (const char *)payload;

    if (counter != NULL) {
        (*counter)++;
    }
    if (text == NULL) {
        g_last_test_payload[0] = '\0';
        return;
    }

    (void)snprintf(g_last_test_payload, sizeof(g_last_test_payload), "%s", text);
}

static int host_event_on(void *host_user_data, const char *event_name, rl_module_event_listener_fn listener,
                         void *listener_user_data)
{
    test_event_binding_t *binding = NULL;
    (void)host_user_data;
    if (event_name == NULL || listener == NULL || g_event_binding_count >= (int)(sizeof(g_event_bindings) / sizeof(g_event_bindings[0]))) {
        return -1;
    }

    binding = &g_event_bindings[g_event_binding_count++];
    (void)snprintf(binding->event_name, sizeof(binding->event_name), "%s", event_name);
    binding->listener = listener;
    binding->listener_user_data = listener_user_data;
    return 0;
}

static int host_event_off(void *host_user_data, const char *event_name, rl_module_event_listener_fn listener,
                          void *listener_user_data)
{
    int i = 0;
    (void)host_user_data;
    for (i = 0; i < g_event_binding_count; i++) {
        if (strcmp(g_event_bindings[i].event_name, event_name) == 0 &&
            g_event_bindings[i].listener == listener &&
            g_event_bindings[i].listener_user_data == listener_user_data) {
            g_event_bindings[i] = g_event_bindings[g_event_binding_count - 1];
            g_event_binding_count--;
            return 0;
        }
    }
    return 0;
}

static int host_event_emit(void *host_user_data, const char *event_name, void *payload)
{
    int i = 0;
    (void)host_user_data;
    for (i = 0; i < g_event_binding_count; i++) {
        if (strcmp(g_event_bindings[i].event_name, event_name) == 0 &&
            g_event_bindings[i].listener != NULL) {
            g_event_bindings[i].listener(payload, g_event_bindings[i].listener_user_data);
        }
    }
    return 0;
}

static const rl_module_entry_t g_test_modules[] = {
    rl_module_register(lua),
};

const rl_module_api_t *rl_module_lookup_registry(const char *name)
{
    size_t i = 0;

    if (name == NULL || name[0] == '\0') {
        return NULL;
    }

    for (i = 0; i < (sizeof(g_test_modules) / sizeof(g_test_modules[0])); i++) {
        if (strcmp(g_test_modules[i].name, name) == 0 && g_test_modules[i].get_api_fn != NULL) {
            return g_test_modules[i].get_api_fn();
        }
    }

    return NULL;
}

int main(void)
{
    const rl_module_api_t *api = NULL;
    rl_module_host_api_t host = {0};
    void *module_state = NULL;
    int lua_ok_count = 0;
    int lua_error_count = 0;
    int rc = 0;
    char error[256] = {0};
    const char *mount_point = "lua_module_test_cache";
    const char *script_path = "scripts/rl_lua_module_test_script.lua";
    const unsigned char script_data[] = "local y = 3 + 4\n";
    const char *event_setup_script =
        "event_count = 0\n"
        "event_payload = nil\n"
        "event_listener = function(payload)\n"
        "  event_count = event_count + 1\n"
        "  event_payload = payload\n"
        "end\n"
        "assert(event_on('test.event', event_listener))\n";
    const char *event_assert_script =
        "assert(event_count == 1)\n"
        "assert(event_payload == 'from_host')\n"
        "assert(event_off('test.event', event_listener))\n";
    const char *event_emit_script =
        "assert(event_emit('lua.test.emit', 'from_lua'))\n";
    const char *event_post_off_assert_script =
        "assert(event_count == 1)\n"
        "assert(event_payload == 'from_host')\n";

    api = rl_module_lua_get_api();
    if (api == NULL) {
        fprintf(stderr, "rl_module_lua_get_api returned NULL\n");
        return 1;
    }
    if (api->abi_version != RL_MODULE_ABI_VERSION) {
        fprintf(stderr, "unexpected module abi version: %d\n", api->abi_version);
        return 1;
    }

    memset(&g_test_frame_buffer, 0, sizeof(g_test_frame_buffer));

    host.user_data = &g_test_frame_buffer;
    host.log = test_log;
    host.log_source = NULL;
    host.event_on = host_event_on;
    host.event_off = host_event_off;
    host.event_emit = host_event_emit;
    host.frame_command = rl_frame_commands_append;

    rc = host_event_on(NULL, "lua.ok", test_event_counter, &lua_ok_count);
    if (rc != 0) {
        fprintf(stderr, "failed to subscribe to lua.ok\n");
        return 1;
    }
    rc = host_event_on(NULL, "lua.error", test_event_counter, &lua_error_count);
    if (rc != 0) {
        fprintf(stderr, "failed to subscribe to lua.error\n");
        return 1;
    }
    rc = host_event_on(NULL, "lua.test.emit", test_capture_payload, &g_test_event_count);
    if (rc != 0) {
        fprintf(stderr, "failed to subscribe to lua.test.emit\n");
        return 1;
    }

    rc = rl_module_init("lua", &host, &api, &module_state, error, sizeof(error));
    if (rc != 0 || module_state == NULL) {
        fprintf(stderr, "module api init failed: %s\n", error);
        return 1;
    }

    fileio_deinit();
    rc = fileio_init(mount_point);
    if (rc != 0) {
        fprintf(stderr, "failed to init fileio test mount\n");
        rl_module_deinit_instance(api, module_state);
        return 1;
    }

    rc = host_event_emit(NULL, "lua.do_string", "local x = 1 + 2");
    if (rc != 0) {
        fprintf(stderr, "failed to emit lua.do_string success case\n");
        rl_module_deinit_instance(api, module_state);
        return 1;
    }
    rc = host_event_emit(NULL, "lua.do_string", "this_is_not_valid_lua(");
    if (rc != 0) {
        fprintf(stderr, "failed to emit lua.do_string error case\n");
        rl_module_deinit_instance(api, module_state);
        return 1;
    }

    rc = fileio_write(script_path, (void *)script_data, sizeof(script_data) - 1);
    if (rc != 0) {
        fprintf(stderr, "failed to write lua script through fileio\n");
        rl_module_deinit_instance(api, module_state);
        return 1;
    }

    rc = host_event_emit(NULL, "lua.do_file", (void *)script_path);
    if (rc != 0) {
        fprintf(stderr, "failed to emit lua.do_file success case\n");
        rl_module_deinit_instance(api, module_state);
        fileio_deinit();
        return 1;
    }

    rc = host_event_emit(NULL, "lua.do_file", "scripts/rl_lua_module_missing.lua");
    if (rc != 0) {
        fprintf(stderr, "failed to emit lua.do_file error case\n");
        rl_module_deinit_instance(api, module_state);
        fileio_deinit();
        return 1;
    }

    rc = host_event_emit(NULL, "lua.do_string", (void *)event_setup_script);
    if (rc != 0) {
        fprintf(stderr, "failed to set up lua event listener script\n");
        rl_module_deinit_instance(api, module_state);
        fileio_deinit();
        return 1;
    }

    rc = host_event_emit(NULL, "test.event", "from_host");
    if (rc != 0) {
        fprintf(stderr, "failed to emit host test.event\n");
        rl_module_deinit_instance(api, module_state);
        fileio_deinit();
        return 1;
    }

    rc = host_event_emit(NULL, "lua.do_string", (void *)event_assert_script);
    if (rc != 0) {
        fprintf(stderr, "failed to assert lua event delivery\n");
        rl_module_deinit_instance(api, module_state);
        fileio_deinit();
        return 1;
    }

    rc = host_event_emit(NULL, "test.event", "after_off");
    if (rc != 0) {
        fprintf(stderr, "failed to emit host test.event after off\n");
        rl_module_deinit_instance(api, module_state);
        fileio_deinit();
        return 1;
    }

    rc = host_event_emit(NULL, "lua.do_string", (void *)event_post_off_assert_script);
    if (rc != 0) {
        fprintf(stderr, "failed to assert lua event_off behavior\n");
        rl_module_deinit_instance(api, module_state);
        fileio_deinit();
        return 1;
    }

    rc = host_event_emit(NULL, "lua.do_string", (void *)event_emit_script);
    if (rc != 0) {
        fprintf(stderr, "failed to exercise lua event_emit\n");
        rl_module_deinit_instance(api, module_state);
        fileio_deinit();
        return 1;
    }

    rc = api->update(module_state, 1.0f / 60.0f);
    if (rc != 0) {
        fprintf(stderr, "module api update failed\n");
        rl_module_deinit_instance(api, module_state);
        return 1;
    }

    /* --- frame command emission tests --- */
    {
        const char *cmd_clear_script =
            "clear(1)\n";
        const char *cmd_draw_cube_script =
            "draw_cube(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 1)\n";
        const char *cmd_draw_text_script =
            "draw_text(1, 'hello', 10.0, 20.0, 16.0, 1.0, 1)\n";
        const char *cmd_play_sound_script =
            "play_sound(1)\n";
        const char *cmd_play_music_script =
            "play_music(1)\n";
        const char *cmd_pause_music_script =
            "pause_music(1)\n";
        const char *cmd_stop_music_script =
            "stop_music(1)\n";
        const char *cmd_set_music_loop_script =
            "set_music_loop(1, true)\n";
        const char *cmd_set_music_volume_script =
            "set_music_volume(1, 0.5)\n";

        rl_frame_commands_reset(&g_test_frame_buffer);
        rc = host_event_emit(NULL, "lua.do_string", (void *)cmd_clear_script);
        if (rc != 0 || g_test_frame_buffer.count != 1 ||
            g_test_frame_buffer.commands[0].type != RL_RENDER_CMD_CLEAR) {
            fprintf(stderr, "expected CLEAR command (count=%d)\n", g_test_frame_buffer.count);
            rl_module_deinit_instance(api, module_state);
            fileio_deinit();
            return 1;
        }

        rl_frame_commands_reset(&g_test_frame_buffer);
        rc = host_event_emit(NULL, "lua.do_string", (void *)cmd_draw_cube_script);
        if (rc != 0 || g_test_frame_buffer.count != 1 ||
            g_test_frame_buffer.commands[0].type != RL_RENDER_CMD_DRAW_CUBE ||
            g_test_frame_buffer.commands[0].data.draw_cube.x != 1.0f ||
            g_test_frame_buffer.commands[0].data.draw_cube.y != 2.0f ||
            g_test_frame_buffer.commands[0].data.draw_cube.z != 3.0f) {
            fprintf(stderr, "expected DRAW_CUBE command (count=%d)\n", g_test_frame_buffer.count);
            rl_module_deinit_instance(api, module_state);
            fileio_deinit();
            return 1;
        }

        rl_frame_commands_reset(&g_test_frame_buffer);
        rc = host_event_emit(NULL, "lua.do_string", (void *)cmd_draw_text_script);
        if (rc != 0 || g_test_frame_buffer.count != 1 ||
            g_test_frame_buffer.commands[0].type != RL_RENDER_CMD_DRAW_TEXT) {
            fprintf(stderr, "expected DRAW_TEXT command (count=%d)\n", g_test_frame_buffer.count);
            rl_module_deinit_instance(api, module_state);
            fileio_deinit();
            return 1;
        }

        rl_frame_commands_reset(&g_test_frame_buffer);
        rc = host_event_emit(NULL, "lua.do_string", (void *)cmd_play_sound_script);
        if (rc != 0 || g_test_frame_buffer.count != 1 ||
            g_test_frame_buffer.commands[0].type != RL_RENDER_CMD_PLAY_SOUND) {
            fprintf(stderr, "expected PLAY_SOUND command (count=%d)\n", g_test_frame_buffer.count);
            rl_module_deinit_instance(api, module_state);
            fileio_deinit();
            return 1;
        }

        rl_frame_commands_reset(&g_test_frame_buffer);
        rc = host_event_emit(NULL, "lua.do_string", (void *)cmd_play_music_script);
        if (rc != 0 || g_test_frame_buffer.count != 1 ||
            g_test_frame_buffer.commands[0].type != RL_RENDER_CMD_PLAY_MUSIC ||
            g_test_frame_buffer.commands[0].data.play_music.music != 1) {
            fprintf(stderr, "expected PLAY_MUSIC command (count=%d)\n", g_test_frame_buffer.count);
            rl_module_deinit_instance(api, module_state);
            fileio_deinit();
            return 1;
        }

        rl_frame_commands_reset(&g_test_frame_buffer);
        rc = host_event_emit(NULL, "lua.do_string", (void *)cmd_pause_music_script);
        if (rc != 0 || g_test_frame_buffer.count != 1 ||
            g_test_frame_buffer.commands[0].type != RL_RENDER_CMD_PAUSE_MUSIC) {
            fprintf(stderr, "expected PAUSE_MUSIC command (count=%d)\n", g_test_frame_buffer.count);
            rl_module_deinit_instance(api, module_state);
            fileio_deinit();
            return 1;
        }

        rl_frame_commands_reset(&g_test_frame_buffer);
        rc = host_event_emit(NULL, "lua.do_string", (void *)cmd_stop_music_script);
        if (rc != 0 || g_test_frame_buffer.count != 1 ||
            g_test_frame_buffer.commands[0].type != RL_RENDER_CMD_STOP_MUSIC) {
            fprintf(stderr, "expected STOP_MUSIC command (count=%d)\n", g_test_frame_buffer.count);
            rl_module_deinit_instance(api, module_state);
            fileio_deinit();
            return 1;
        }

        rl_frame_commands_reset(&g_test_frame_buffer);
        rc = host_event_emit(NULL, "lua.do_string", (void *)cmd_set_music_loop_script);
        if (rc != 0 || g_test_frame_buffer.count != 1 ||
            g_test_frame_buffer.commands[0].type != RL_RENDER_CMD_SET_MUSIC_LOOP ||
            !g_test_frame_buffer.commands[0].data.set_music_loop.loop) {
            fprintf(stderr, "expected SET_MUSIC_LOOP command (count=%d)\n", g_test_frame_buffer.count);
            rl_module_deinit_instance(api, module_state);
            fileio_deinit();
            return 1;
        }

        rl_frame_commands_reset(&g_test_frame_buffer);
        rc = host_event_emit(NULL, "lua.do_string", (void *)cmd_set_music_volume_script);
        if (rc != 0 || g_test_frame_buffer.count != 1 ||
            g_test_frame_buffer.commands[0].type != RL_RENDER_CMD_SET_MUSIC_VOLUME ||
            g_test_frame_buffer.commands[0].data.set_music_volume.volume != 0.5f) {
            fprintf(stderr, "expected SET_MUSIC_VOLUME command (count=%d)\n", g_test_frame_buffer.count);
            rl_module_deinit_instance(api, module_state);
            fileio_deinit();
            return 1;
        }
    }

    rl_module_deinit_instance(api, module_state);
    (void)fileio_rmfile(script_path);
    (void)fileio_rmdir("scripts");
    fileio_deinit();
    (void)host_event_off(NULL, "lua.ok", test_event_counter, &lua_ok_count);
    (void)host_event_off(NULL, "lua.error", test_event_counter, &lua_error_count);
    (void)host_event_off(NULL, "lua.test.emit", test_capture_payload, &g_test_event_count);

    if (lua_ok_count < 2) {
        fprintf(stderr, "expected lua.ok event at least twice\n");
        return 1;
    }
    if (lua_error_count < 2) {
        fprintf(stderr, "expected lua.error event at least twice\n");
        return 1;
    }
    if (g_module_log_count < 2) {
        fprintf(stderr, "expected module logger to be called at least twice\n");
        return 1;
    }
    if (g_test_event_count != 1) {
        fprintf(stderr, "expected lua.test.emit exactly once\n");
        return 1;
    }
    if (strcmp(g_last_test_payload, "from_lua") != 0) {
        fprintf(stderr, "unexpected lua.test.emit payload: %s\n", g_last_test_payload);
        return 1;
    }

    printf("lua_module_test: passed\n");
    return 0;
}
