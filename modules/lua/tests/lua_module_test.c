#include "rl_module_lua.h"
#include "fileio/fileio.h"

#include <stdio.h>
#include <string.h>

typedef struct test_event_binding_t {
    char event_name[64];
    rl_module_event_listener_fn listener;
    void *listener_user_data;
} test_event_binding_t;

static test_event_binding_t g_event_bindings[32];
static int g_event_binding_count = 0;
static int g_test_event_count = 0;
static char g_last_test_payload[128];

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
    int module_log_count = 0;
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

    host.user_data = &module_log_count;
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
    if (module_log_count < 2) {
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
