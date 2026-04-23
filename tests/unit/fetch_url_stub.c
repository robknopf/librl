#include "fetch_url/fetch_url.h"
#include "fetch_url_stub.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define FETCH_URL_STUB_MAX_RESPONSES 16

typedef struct
{
    int code;
    char *data;
    size_t size;
} fetch_url_stub_response_t;

static int g_response_code = 503;
static char *g_response_data = NULL;
static size_t g_response_size = 0;
static fetch_url_stub_response_t g_response_queue[FETCH_URL_STUB_MAX_RESPONSES];
static size_t g_response_queue_len = 0;
static size_t g_response_queue_index = 0;

static int g_call_count = 0;
static char g_last_host[FETCH_URL_MAX_PATH_LENGTH] = {0};
static char g_last_path[FETCH_URL_MAX_PATH_LENGTH] = {0};

void fetch_url_stub_reset(void)
{
    size_t i = 0;

    g_response_code = 503;
    free(g_response_data);
    g_response_data = NULL;
    g_response_size = 0;
    for (i = 0; i < g_response_queue_len; i++)
    {
        free(g_response_queue[i].data);
        g_response_queue[i].data = NULL;
        g_response_queue[i].size = 0;
        g_response_queue[i].code = 0;
    }
    g_response_queue_len = 0;
    g_response_queue_index = 0;
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

void fetch_url_stub_enqueue_response(int code, const char *data, size_t size)
{
    fetch_url_stub_response_t *response = NULL;

    if (g_response_queue_len >= FETCH_URL_STUB_MAX_RESPONSES)
    {
        return;
    }

    response = &g_response_queue[g_response_queue_len++];
    response->code = code;
    response->data = NULL;
    response->size = 0;

    if (data != NULL && size > 0)
    {
        response->data = (char *)malloc(size);
        if (response->data != NULL)
        {
            memcpy(response->data, data, size);
            response->size = size;
        }
        else
        {
            response->code = 500;
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

int fetch_url_head(const char *url, int timeout_ms)
{
    /*
     * The real implementation performs a network I/O probe. Unit tests are fully offline
     * and only validate the follow-up `fetch_url_with_path_async()` path, so treat HEAD
     * as a no-op success.
     */
    (void)url;
    (void)timeout_ms;
    return 0;
}

fetch_url_op_t *fetch_url_async(const char *url, int timeout_ms)
{
    fetch_url_op_t *op = (fetch_url_op_t *)calloc(1, sizeof(fetch_url_op_t));

    if (!op)
    {
        return NULL;
    }

    wg_op_init(&op->op, WG_OP_KIND_FETCH_URL, NULL, NULL);
    (void)url;
    (void)timeout_ms;
    op->result.code = 501;
    wg_op_complete(&op->op, op->result.code);
    return op;
}

fetch_url_op_t *fetch_url_with_path_async(const char *host_url,
                                          const char *relative_path,
                                          int timeout_ms)
{
    fetch_url_op_t *op = (fetch_url_op_t *)calloc(1, sizeof(fetch_url_op_t));

    if (!op)
    {
        return NULL;
    }

    wg_op_init(&op->op, WG_OP_KIND_FETCH_URL, NULL, NULL);
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

    (void)snprintf(op->result.url, sizeof(op->result.url), "%s/%s", host_url, relative_path);
    if (g_response_queue_index < g_response_queue_len)
    {
        fetch_url_stub_response_t *response = &g_response_queue[g_response_queue_index++];

        op->result.code = response->code;
        if (response->code == 200 && response->data != NULL && response->size > 0)
        {
            op->result.data = (char *)malloc(response->size);
            if (op->result.data != NULL)
            {
                memcpy(op->result.data, response->data, response->size);
                op->result.size = response->size;
            }
            else
            {
                op->result.code = 500;
                op->result.size = 0;
            }
        }
    }
    else
    {
        op->result.code = g_response_code;
    }

    if (g_response_queue_index >= g_response_queue_len &&
        g_response_queue_len == 0 &&
        g_response_code == 200 &&
        g_response_data != NULL &&
        g_response_size > 0)
    {
        op->result.data = (char *)malloc(g_response_size);
        if (op->result.data != NULL)
        {
            memcpy(op->result.data, g_response_data, g_response_size);
            op->result.size = g_response_size;
        }
        else
        {
            op->result.code = 500;
            op->result.size = 0;
        }
    }
    wg_op_complete(&op->op, op->result.code);
    return op;
}

bool fetch_url_poll(fetch_url_op_t *op)
{
    return wg_op_is_done(op ? &op->op : NULL);
}

int fetch_url_finish(fetch_url_op_t *op, fetch_url_result_t *result)
{
    if (!op || !result)
    {
        return -1;
    }

    if (!wg_op_is_done(&op->op))
    {
        return 1;
    }

    *result = op->result;
    op->result.data = NULL;
    op->result.size = 0;
    op->result.code = 0;
    op->result.url[0] = '\0';
    return 0;
}

void fetch_url_op_free(fetch_url_op_t *op)
{
    if (!op)
    {
        return;
    }

    free(op->result.data);
    wg_op_deinit(&op->op);
    free(op);
}
