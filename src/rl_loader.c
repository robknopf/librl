#include "rl_loader.h"

#include <raylib.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdbool.h>
#include <limits.h>
#include <ctype.h>

#include "fileio/fileio.h"
#include "lru_cache/lru_cache.h"

#define RL_LOADER_DEFAULT_MOUNT_POINT "cache"
#define RL_LOADER_DEFAULT_REMOTE_HOST "https://localhost:4444"
#define RL_LOADER_DEFAULT_TIMEOUT_MS 5000
#define RL_LOADER_CACHE_MAX_BYTES (32u * 1024u * 1024u)
#define RL_LOADER_CACHE_MAX_ENTRIES 256u
#define RL_LOADER_CACHE_MAX_ENTRY_BYTES (8u * 1024u * 1024u)

static bool rl_loader_initialized = false;
static lru_cache_t *rl_loader_memory_cache = NULL;

static bool rl_loader_is_http_url(const char *path)
{
    if (!path) {
        return false;
    }
    return (strncmp(path, "http://", 7) == 0) || (strncmp(path, "https://", 8) == 0);
}

static bool rl_loader_split_url(const char *url, char *host, size_t host_size, char *path, size_t path_size)
{
    const char *scheme = strstr(url, "://");
    const char *path_start = NULL;
    const char *query_start = NULL;
    size_t host_len = 0;
    size_t path_len = 0;

    if (!scheme) {
        return false;
    }

    path_start = strchr(scheme + 3, '/');
    if (!path_start) {
        return false;
    }

    host_len = (size_t)(path_start - url);
    if (host_len + 1 > host_size) {
        return false;
    }
    memcpy(host, url, host_len);
    host[host_len] = '\0';

    path_start++;
    query_start = strpbrk(path_start, "?#");
    if (query_start) {
        path_len = (size_t)(query_start - path_start);
    } else {
        path_len = strlen(path_start);
    }

    if (path_len == 0 || path_len + 1 > path_size) {
        return false;
    }
    memcpy(path, path_start, path_len);
    path[path_len] = '\0';

    return true;
}

static const char *rl_loader_strip_leading_slash(const char *path)
{
    if (path && path[0] == '/') {
        return path + 1;
    }
    return path;
}

static const char *rl_loader_get_extension(const char *path)
{
    const char *dot = NULL;
    const char *slash = NULL;
    if (!path) {
        return NULL;
    }

    dot = strrchr(path, '.');
    if (!dot) {
        return NULL;
    }

    slash = strrchr(path, '/');
    if (slash && dot < slash) {
        return NULL;
    }

    return dot;
}

static bool rl_loader_ext_eq(const char *ext, const char *target)
{
    size_t i = 0;
    if (!ext || !target) {
        return false;
    }

    while (ext[i] != '\0' && target[i] != '\0')
    {
        if ((char)tolower((unsigned char)ext[i]) != (char)tolower((unsigned char)target[i])) {
            return false;
        }
        i++;
    }

    return ext[i] == '\0' && target[i] == '\0';
}

static bool rl_loader_should_memory_cache_path(const char *resolved_path)
{
    const char *ext = rl_loader_get_extension(resolved_path);
    if (!ext) {
        return false;
    }

    // Keep cache selective so RAM usage is predictable.
    return rl_loader_ext_eq(ext, ".glb") ||
           rl_loader_ext_eq(ext, ".gltf") ||
           rl_loader_ext_eq(ext, ".ttf") ||
           rl_loader_ext_eq(ext, ".otf");
}

static unsigned char *rl_loader_load_file_data_cb(const char *file_name, int *data_size)
{
    fileio_read_result_t result = {0};
    const char *resolved_host = RL_LOADER_DEFAULT_REMOTE_HOST;
    const char *resolved_path = NULL;
    char parsed_host[256] = {0};
    char parsed_path[512] = {0};
    bool should_cache_in_memory = false;
    size_t cached_size = 0;
    unsigned char *cached_data = NULL;

    if (data_size) {
        *data_size = 0;
    }

    if (!file_name) {
        return NULL;
    }

    // Step 1: Resolve host/path. Explicit URL overrides default host.
    if (rl_loader_is_http_url(file_name)) {
        if (!rl_loader_split_url(file_name, parsed_host, sizeof(parsed_host), parsed_path, sizeof(parsed_path))) {
            return NULL;
        }
        resolved_host = parsed_host;
        resolved_path = parsed_path;
    } else {
        resolved_path = rl_loader_strip_leading_slash(file_name);
    }

    should_cache_in_memory = rl_loader_should_memory_cache_path(resolved_path);

    // Step 2: Cache-first read from in-memory LRU for selected asset types.
    if (should_cache_in_memory && rl_loader_memory_cache != NULL) {
        if (lru_cache_get_copy(rl_loader_memory_cache, resolved_path, &cached_data, &cached_size)) {
            if (cached_size > (size_t)INT_MAX) {
                free(cached_data);
                return NULL;
            }
            if (data_size) {
                *data_size = (int)cached_size;
            }
            return cached_data;
        }
    }

    // Step 3: Cache-first read from local mounted storage.
    result = fileio_read(resolved_path);
    if (result.error != 0 || !result.data || result.size == 0) {
        if (result.data) {
            free(result.data);
            result.data = NULL;
        }

        // Step 4: On miss, fetch from remote host and store into local cache.
        result = fileio_read_url(resolved_host, resolved_path, RL_LOADER_DEFAULT_TIMEOUT_MS);
    }

    // Step 5: If load still failed, signal raylib failure for this path.
    if (result.error != 0 || !result.data || result.size == 0) {
        if (result.data) {
            free(result.data);
        }
        return NULL;
    }

    if (should_cache_in_memory && rl_loader_memory_cache != NULL && result.size <= RL_LOADER_CACHE_MAX_ENTRY_BYTES) {
        lru_cache_put_copy(rl_loader_memory_cache, resolved_path, result.data, result.size);
    }

    if (data_size) {
        if (result.size > (size_t)INT_MAX) {
            free(result.data);
            return NULL;
        }
        *data_size = (int)result.size;
    }

    return result.data;
}

int rl_loader_init(const char *mount_point)
{
    const char *resolved_mount = mount_point;

    if (rl_loader_initialized) {
        return 0;
    }

    if (!resolved_mount || resolved_mount[0] == '\0') {
        resolved_mount = RL_LOADER_DEFAULT_MOUNT_POINT;
    }

    if (fileio_init(resolved_mount) != 0) {
        return -1;
    }

    // One shared byte cache for loader callbacks across all modules.
    rl_loader_memory_cache = lru_cache_create(RL_LOADER_CACHE_MAX_BYTES, RL_LOADER_CACHE_MAX_ENTRIES);

    SetLoadFileDataCallback(rl_loader_load_file_data_cb);

    rl_loader_initialized = true;
    return 0;
}

void rl_loader_deinit(void)
{
    if (!rl_loader_initialized) {
        return;
    }

    SetLoadFileDataCallback(NULL);
    lru_cache_destroy(rl_loader_memory_cache);
    rl_loader_memory_cache = NULL;
    rl_loader_initialized = false;
}
