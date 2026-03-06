#include "fileio/fileio.h"

#include <string.h>

int probe_fileio_init(void)
{
    return fileio_init("cache");
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
    fileio_deinit();
}
