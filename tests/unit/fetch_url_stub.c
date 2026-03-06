#include "fetch_url/fetch_url.h"
#include "fetch_url_stub.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int g_response_code = 503;
static char *g_response_data = NULL;
static size_t g_response_size = 0;

static int g_call_count = 0;
static char g_last_host[FETCH_URL_MAX_PATH_LENGTH] = {0};
static char g_last_path[FETCH_URL_MAX_PATH_LENGTH] = {0};

void fetch_url_stub_reset(void)
{
    g_response_code = 503;
    free(g_response_data);
    g_response_data = NULL;
    g_response_size = 0;
    g_call_count = 0;
    g_last_host[0] = '\0';
    g_last_path[0] = '\0';
}

void fetch_url_stub_set_response(int code, const char *data, size_t size)
{
    g_response_code = code;

    free(g_response_data);
    g_response_data = NULL;
    g_response_size = 0;

    if (data != NULL && size > 0)
    {
        g_response_data = (char *)malloc(size);
        if (g_response_data != NULL)
        {
            memcpy(g_response_data, data, size);
            g_response_size = size;
        }
    }
}

int fetch_url_stub_get_call_count(void)
{
    return g_call_count;
}

const char *fetch_url_stub_get_last_host(void)
{
    return g_last_host;
}

const char *fetch_url_stub_get_last_path(void)
{
    return g_last_path;
}

fetch_url_result_t fetch_url(const char *url, int timeout_ms)
{
    (void)url;
    (void)timeout_ms;
    fetch_url_result_t result = {0};
    result.code = 501;
    return result;
}

fetch_url_result_t fetch_url_with_path(const char *host_url, const char *relative_path, int timeout_ms)
{
    fetch_url_result_t result = {0};
    (void)timeout_ms;

    g_call_count++;

    if (host_url == NULL) {
        host_url = "";
    }
    if (relative_path == NULL) {
        relative_path = "";
    }

    (void)snprintf(g_last_host, sizeof(g_last_host), "%s", host_url);
    (void)snprintf(g_last_path, sizeof(g_last_path), "%s", relative_path);

    (void)snprintf(result.url, sizeof(result.url), "%s/%s", host_url, relative_path);
    result.code = g_response_code;

    if (g_response_code == 200 && g_response_data != NULL && g_response_size > 0)
    {
        result.data = (char *)malloc(g_response_size);
        if (result.data != NULL)
        {
            memcpy(result.data, g_response_data, g_response_size);
            result.size = g_response_size;
        }
        else
        {
            result.code = 500;
            result.size = 0;
        }
    }

    return result;
}
