#include "rl_lua_addon.h"
#include "fileio/fileio.h"

#include <stdio.h>
#include <string.h>

typedef struct test_event_binding_t {
    char event_name[64];
    rl_addon_event_listener_fn listener;
    void *listener_user_data;
} test_event_binding_t;

static test_event_binding_t g_event_bindings[32];
static int g_event_binding_count = 0;

static void test_log(void *user_data, int level, const char *message)
{
    int *log_count = (int *)user_data;
    (void)level;
    (void)message;
    if (log_count != NULL) {
        (*log_count)++;
    }
}

static void test_event_counter(void *payload, void *user_data)
{
    int *counter = (int *)user_data;
    (void)payload;
    if (counter != NULL) {
        (*counter)++;
    }
}

static int host_event_on(void *host_user_data, const char *event_name, rl_addon_event_listener_fn listener,
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

static int host_event_off(void *host_user_data, const char *event_name, rl_addon_event_listener_fn listener,
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

int main(void)
{
    const rl_addon_api_t *api = NULL;
    rl_addon_host_api_t host = {0};
    void *addon_state = NULL;
    int addon_log_count = 0;
    int lua_ok_count = 0;
    int lua_error_count = 0;
    int rc = 0;
    char error[256] = {0};
    const char *mount_point = "lua_addon_test_cache";
    const char *script_path = "scripts/rl_lua_addon_test_script.lua";
    const unsigned char script_data[] = "local y = 3 + 4\n";

    api = rl_lua_addon_get_api();
    if (api == NULL) {
        fprintf(stderr, "rl_lua_addon_get_api returned NULL\n");
        return 1;
    }
    if (api->abi_version != RL_ADDON_ABI_VERSION) {
        fprintf(stderr, "unexpected addon abi version: %d\n", api->abi_version);
        return 1;
    }

    host.user_data = &addon_log_count;
    host.log = test_log;
    host.event_on = host_event_on;
    host.event_off = host_event_off;
    host.event_emit = host_event_emit;

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

    rc = rl_addon_init("lua", &host, &api, &addon_state, error, sizeof(error));
    if (rc != 0 || addon_state == NULL) {
        fprintf(stderr, "addon api init failed: %s\n", error);
        return 1;
    }

    fileio_deinit();
    rc = fileio_init(mount_point);
    if (rc != 0) {
        fprintf(stderr, "failed to init fileio test mount\n");
        rl_addon_deinit_instance(api, addon_state);
        return 1;
    }

    rc = host_event_emit(NULL, "lua.do_string", "local x = 1 + 2");
    if (rc != 0) {
        fprintf(stderr, "failed to emit lua.do_string success case\n");
        rl_addon_deinit_instance(api, addon_state);
        return 1;
    }
    rc = host_event_emit(NULL, "lua.do_string", "this_is_not_valid_lua(");
    if (rc != 0) {
        fprintf(stderr, "failed to emit lua.do_string error case\n");
        rl_addon_deinit_instance(api, addon_state);
        return 1;
    }

    rc = fileio_write(script_path, (void *)script_data, sizeof(script_data) - 1);
    if (rc != 0) {
        fprintf(stderr, "failed to write lua script through fileio\n");
        rl_addon_deinit_instance(api, addon_state);
        return 1;
    }

    rc = host_event_emit(NULL, "lua.do_file", (void *)script_path);
    if (rc != 0) {
        fprintf(stderr, "failed to emit lua.do_file success case\n");
        rl_addon_deinit_instance(api, addon_state);
        fileio_deinit();
        return 1;
    }

    rc = host_event_emit(NULL, "lua.do_file", "scripts/rl_lua_addon_missing.lua");
    if (rc != 0) {
        fprintf(stderr, "failed to emit lua.do_file error case\n");
        rl_addon_deinit_instance(api, addon_state);
        fileio_deinit();
        return 1;
    }

    rc = api->update(addon_state, 1.0f / 60.0f);
    if (rc != 0) {
        fprintf(stderr, "addon api update failed\n");
        rl_addon_deinit_instance(api, addon_state);
        return 1;
    }

    rl_addon_deinit_instance(api, addon_state);
    (void)fileio_rmfile(script_path);
    (void)fileio_rmdir("scripts");
    fileio_deinit();
    (void)host_event_off(NULL, "lua.ok", test_event_counter, &lua_ok_count);
    (void)host_event_off(NULL, "lua.error", test_event_counter, &lua_error_count);

    if (lua_ok_count < 2) {
        fprintf(stderr, "expected lua.ok event at least twice\n");
        return 1;
    }
    if (lua_error_count < 2) {
        fprintf(stderr, "expected lua.error event at least twice\n");
        return 1;
    }
    if (addon_log_count < 2) {
        fprintf(stderr, "expected addon logger to be called at least twice\n");
        return 1;
    }

    printf("lua_addon_test: passed\n");
    return 0;
}
