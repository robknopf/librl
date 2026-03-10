#include "rl_lua_addon.h"

#include <stdio.h>
#include <string.h>

static void test_log(void *user_data, int level, const char *message)
{
    int *log_count = (int *)user_data;
    (void)level;
    (void)message;
    if (log_count != NULL) {
        (*log_count)++;
    }
}

int main(void)
{
    const rl_addon_api_t *api = NULL;
    rl_addon_host_api_t host = {0};
    void *addon_state = NULL;
    int addon_log_count = 0;
    int rc = 0;
    char error[256] = {0};

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

    rc = rl_addon_init("lua", &host, &api, &addon_state, error, sizeof(error));
    if (rc != 0 || addon_state == NULL) {
        fprintf(stderr, "addon api init failed: %s\n", error);
        return 1;
    }

    rc = api->update(addon_state, 1.0f / 60.0f);
    if (rc != 0) {
        fprintf(stderr, "addon api update failed\n");
        rl_addon_deinit_instance(api, addon_state);
        return 1;
    }

    rl_addon_deinit_instance(api, addon_state);
    if (addon_log_count < 2) {
        fprintf(stderr, "expected addon logger to be called at least twice\n");
        return 1;
    }

    printf("lua_addon_test: passed\n");
    return 0;
}
