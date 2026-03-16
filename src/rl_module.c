#include "rl_module.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

__attribute__((weak)) const rl_module_api_t *rl_module_lookup_registry(const char *name);

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

void rl_module_log(const rl_module_host_api_t *host, int level, const char *message)
{
    if (host != NULL && host->log != NULL) {
        host->log(host->user_data, level, message);
    }
}

void rl_module_log_source(const rl_module_host_api_t *host, int level, const char *source_file,
                          int source_line, const char *message)
{
    if (host != NULL && host->log_source != NULL) {
        host->log_source(host->user_data, level, source_file, source_line, message);
        return;
    }
    rl_module_log(host, level, message);
}

void *rl_module_alloc(const rl_module_host_api_t *host, size_t size)
{
    if (host != NULL && host->alloc != NULL) {
        return host->alloc(size, host->user_data);
    }
    return malloc(size);
}

void rl_module_free(const rl_module_host_api_t *host, void *ptr)
{
    if (host != NULL && host->free != NULL) {
        host->free(ptr, host->user_data);
        return;
    }
    free(ptr);
}

int rl_module_event_on(const rl_module_host_api_t *host, const char *event_name,
                      rl_module_event_listener_fn listener, void *listener_user_data)
{
    if (host == NULL || host->event_on == NULL) {
        return -1;
    }
    return host->event_on(host->user_data, event_name, listener, listener_user_data);
}

int rl_module_event_off(const rl_module_host_api_t *host, const char *event_name,
                       rl_module_event_listener_fn listener, void *listener_user_data)
{
    if (host == NULL || host->event_off == NULL) {
        return -1;
    }
    return host->event_off(host->user_data, event_name, listener, listener_user_data);
}

int rl_module_event_emit(const rl_module_host_api_t *host, const char *event_name, void *payload)
{
    if (host == NULL || host->event_emit == NULL) {
        return -1;
    }
    return host->event_emit(host->user_data, event_name, payload);
}

void rl_module_frame_command(const rl_module_host_api_t *host, const rl_render_command_t *command)
{
    if (host == NULL || host->frame_command == NULL || command == NULL) {
        return;
    }
    host->frame_command(host->user_data, command);
}

int rl_module_api_validate(const rl_module_api_t *api, char *error, size_t error_size)
{
    if (api == NULL) {
        set_error(error, error_size, "module api is NULL");
        return -1;
    }
    if (api->name == NULL || api->name[0] == '\0') {
        set_error(error, error_size, "module api missing name");
        return -1;
    }
    if (api->abi_version != RL_MODULE_ABI_VERSION) {
        set_error(error, error_size, "module api abi version mismatch");
        return -1;
    }
    if (api->init == NULL) {
        set_error(error, error_size, "module api missing init");
        return -1;
    }
    if (api->deinit == NULL) {
        set_error(error, error_size, "module api missing deinit");
        return -1;
    }

    set_error(error, error_size, NULL);
    return 0;
}

int rl_module_init_instance(const rl_module_api_t *api, const rl_module_host_api_t *host, void **module_state,
                           char *error, size_t error_size)
{
    int rc = 0;

    if (module_state == NULL) {
        set_error(error, error_size, "module_state output is NULL");
        return -1;
    }
    *module_state = NULL;

    rc = rl_module_api_validate(api, error, error_size);
    if (rc != 0) {
        return -1;
    }

    rc = api->init(host, module_state);
    if (rc != 0 || *module_state == NULL) {
        set_error(error, error_size, "module init failed");
        return -1;
    }

    set_error(error, error_size, NULL);
    return 0;
}

int rl_module_get_config_instance(const rl_module_api_t *api, void *module_state, rl_module_config_t *out_config)
{
    if (out_config == NULL) {
        return -1;
    }
    if (api == NULL || api->get_config == NULL || module_state == NULL) {
        return -1;
    }
    return api->get_config(module_state, out_config);
}

int rl_module_start_instance(const rl_module_api_t *api, void *module_state)
{
    if (api == NULL || api->start == NULL || module_state == NULL) {
        return -1;
    }
    return api->start(module_state);
}

void rl_module_deinit_instance(const rl_module_api_t *api, void *module_state)
{
    if (api == NULL || api->deinit == NULL || module_state == NULL) {
        return;
    }
    api->deinit(module_state);
}

const rl_module_api_t *rl_module_get_api(const char *name)
{
    const rl_module_api_t *api = NULL;

    if (name == NULL || name[0] == '\0') {
        return NULL;
    }

    if (rl_module_lookup_registry != NULL) {
        api = rl_module_lookup_registry(name);
        if (api != NULL) {
            return api;
        }
    }

    return NULL;
}

int rl_module_init(const char *name, const rl_module_host_api_t *host, const rl_module_api_t **out_api,
                  void **module_state, char *error, size_t error_size)
{
    const rl_module_api_t *api = rl_module_get_api(name);
    int rc = 0;

    if (out_api == NULL) {
        set_error(error, error_size, "out_api is NULL");
        return -1;
    }
    *out_api = NULL;

    if (api == NULL) {
        set_error(error, error_size, "module not found");
        return -1;
    }

    rc = rl_module_init_instance(api, host, module_state, error, error_size);
    if (rc != 0) {
        return -1;
    }

    *out_api = api;
    set_error(error, error_size, NULL);
    return 0;
}
