#include "fileio/fileio.h"

#include <string.h>

static fileio_sync_op_t *g_sync_op = NULL;
static fileio_sync_op_t *g_flush_op = NULL;

int probe_fileio_init(void)
{
    return fileio_init("cache");
}

int probe_fileio_restore_begin(void)
{
    g_sync_op = fileio_restore_async();
    return g_sync_op ? 0 : -1;
}

int probe_fileio_restore_poll(void)
{
    if (!g_sync_op) {
        return -1;
    }
    return fileio_sync_poll(g_sync_op) ? 1 : 0;
}

int probe_fileio_restore_finish(void)
{
    if (!g_sync_op) {
        return -1;
    }
    int rc = fileio_sync_finish(g_sync_op);
    fileio_sync_op_free(g_sync_op);
    g_sync_op = NULL;
    return rc;
}

int probe_fileio_flush_begin(void)
{
    g_flush_op = fileio_flush_async();
    return g_flush_op ? 0 : -1;
}

int probe_fileio_flush_poll(void)
{
    if (!g_flush_op) {
        return -1;
    }
    return fileio_sync_poll(g_flush_op) ? 1 : 0;
}

int probe_fileio_flush_finish(void)
{
    if (!g_flush_op) {
        return -1;
    }
    int rc = fileio_sync_finish(g_flush_op);
    fileio_sync_op_free(g_flush_op);
    g_flush_op = NULL;
    return rc;
}

int probe_fileio_write_text(const char *path, const char *text)
{
    if (!path || !text) {
        return -1;
    }
    return fileio_write(path, (void *)text, strlen(text));
}

int probe_fileio_exists(const char *path)
{
    return fileio_exists(path) ? 1 : 0;
}

void probe_fileio_deinit(void)
{
    if (g_sync_op) {
        fileio_sync_op_free(g_sync_op);
        g_sync_op = NULL;
    }
    if (g_flush_op) {
        fileio_sync_op_free(g_flush_op);
        g_flush_op = NULL;
    }
    fileio_deinit();
}
