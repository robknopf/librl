#include "rl_addon.h"
#include "internal/rl_addon_store.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void set_error(char *error, size_t error_size, const char *message)
{
    if (error == NULL || error_size == 0) {
        return;
    }

    if (message == NULL) {
        error[0] = '\0';
        return;
    }

    (void)snprintf(error, error_size, "%s", message);
}

void rl_addon_log(const rl_addon_host_api_t *host, int level, const char *message)
{
    if (host != NULL && host->log != NULL) {
        host->log(host->user_data, level, message);
    }
}

void *rl_addon_alloc(const rl_addon_host_api_t *host, size_t size)
{
    if (host != NULL && host->alloc != NULL) {
        return host->alloc(size, host->user_data);
    }
    return malloc(size);
}

void rl_addon_free(const rl_addon_host_api_t *host, void *ptr)
{
    if (host != NULL && host->free != NULL) {
        host->free(ptr, host->user_data);
        return;
    }
    free(ptr);
}

int rl_addon_event_on(const rl_addon_host_api_t *host, const char *event_name,
                      rl_addon_event_listener_fn listener, void *listener_user_data)
{
    if (host == NULL || host->event_on == NULL) {
        return -1;
    }
    return host->event_on(host->user_data, event_name, listener, listener_user_data);
}

int rl_addon_event_off(const rl_addon_host_api_t *host, const char *event_name,
                       rl_addon_event_listener_fn listener, void *listener_user_data)
{
    if (host == NULL || host->event_off == NULL) {
        return -1;
    }
    return host->event_off(host->user_data, event_name, listener, listener_user_data);
}

int rl_addon_event_emit(const rl_addon_host_api_t *host, const char *event_name, void *payload)
{
    if (host == NULL || host->event_emit == NULL) {
        return -1;
    }
    return host->event_emit(host->user_data, event_name, payload);
}

int rl_addon_api_validate(const rl_addon_api_t *api, char *error, size_t error_size)
{
    if (api == NULL) {
        set_error(error, error_size, "addon api is NULL");
        return -1;
    }
    if (api->name == NULL || api->name[0] == '\0') {
        set_error(error, error_size, "addon api missing name");
        return -1;
    }
    if (api->abi_version != RL_ADDON_ABI_VERSION) {
        set_error(error, error_size, "addon api abi version mismatch");
        return -1;
    }
    if (api->init == NULL) {
        set_error(error, error_size, "addon api missing init");
        return -1;
    }
    if (api->deinit == NULL) {
        set_error(error, error_size, "addon api missing deinit");
        return -1;
    }

    set_error(error, error_size, NULL);
    return 0;
}

int rl_addon_init_instance(const rl_addon_api_t *api, const rl_addon_host_api_t *host, void **addon_state,
                           char *error, size_t error_size)
{
    int rc = 0;

    if (addon_state == NULL) {
        set_error(error, error_size, "addon_state output is NULL");
        return -1;
    }
    *addon_state = NULL;

    rc = rl_addon_api_validate(api, error, error_size);
    if (rc != 0) {
        return -1;
    }

    rc = api->init(host, addon_state);
    if (rc != 0 || *addon_state == NULL) {
        set_error(error, error_size, "addon init failed");
        return -1;
    }

    set_error(error, error_size, NULL);
    return 0;
}

void rl_addon_deinit_instance(const rl_addon_api_t *api, void *addon_state)
{
    if (api == NULL || api->deinit == NULL || addon_state == NULL) {
        return;
    }
    api->deinit(addon_state);
}

const rl_addon_api_t *rl_addon_get_api(const char *name)
{
    size_t i = 0;

    if (name == NULL || name[0] == '\0') {
        return NULL;
    }

    for (i = 0; i < rl_addon_store_count; i++) {
        if (strcmp(name, rl_addon_store[i].name) == 0) {
            if (rl_addon_store[i].get_api_fn == NULL) {
                return NULL;
            }
            return rl_addon_store[i].get_api_fn();
        }
    }

    return NULL;
}

int rl_addon_init(const char *name, const rl_addon_host_api_t *host, const rl_addon_api_t **out_api,
                  void **addon_state, char *error, size_t error_size)
{
    const rl_addon_api_t *api = rl_addon_get_api(name);
    int rc = 0;

    if (out_api == NULL) {
        set_error(error, error_size, "out_api is NULL");
        return -1;
    }
    *out_api = NULL;

    if (api == NULL) {
        set_error(error, error_size, "addon not found");
        return -1;
    }

    rc = rl_addon_init_instance(api, host, addon_state, error, error_size);
    if (rc != 0) {
        return -1;
    }

    *out_api = api;
    set_error(error, error_size, NULL);
    return 0;
}
