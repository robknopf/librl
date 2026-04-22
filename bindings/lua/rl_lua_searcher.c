/* rl_lua_searcher.c - Lua require/searcher helpers for librl */

#include <lua.h>
#include <lauxlib.h>

#include <stdio.h>
#include <string.h>

#include "rl_loader.h"
#include "rl_lua_searcher.h"

#ifndef LUA_OK
#define LUA_OK 0
#endif

#if LUA_VERSION_NUM < 502
#define lua_rawlen lua_objlen
#endif

static int rl_lua_is_explicit_path(const char *filename)
{
    if (filename == NULL || filename[0] == '\0') {
        return 0;
    }

    return filename[0] == '/' ||
           strncmp(filename, "./", 2) == 0 ||
           strncmp(filename, "../", 3) == 0 ||
           strchr(filename, '/') != NULL;
}

static int rl_lua_expand_template(const char *prefix, const char *token, const char *suffix,
                                  char *out, size_t out_size)
{
    size_t plen = strlen(prefix);
    size_t tlen = strlen(token);
    size_t slen = strlen(suffix);
    if (plen + tlen + slen + 1 > out_size) {
        return -1;
    }
    memcpy(out, prefix, plen);
    memcpy(out + plen, token, tlen);
    memcpy(out + plen + tlen, suffix, slen);
    out[plen + tlen + slen] = '\0';
    return 0;
}

int rl_lua_fetch_to_fileio(const char *relative_path)
{
    rl_loader_task_t *task = NULL;
    int rc = 0;

    if (relative_path == NULL || relative_path[0] == '\0') {
        return -1;
    }

    task = rl_loader_import_asset_async(relative_path);
    if (task == NULL) {
        return -1;
    }

    rc = rl_loader_wait_task(task);
    return rc;
}

int rl_lua_load_file_chunk(lua_State *L, const char *filename)
{
    rl_loader_read_result_t read_result = {0};
    char chunk_name[512];
    int rc = 0;

    if (L == NULL || filename == NULL || filename[0] == '\0') {
        return LUA_ERRFILE;
    }

    read_result = rl_loader_read_local(filename);
    if (read_result.error != 0 || read_result.data == NULL || read_result.size == 0) {
        rl_loader_read_result_free(&read_result);
        return LUA_ERRFILE;
    }

    (void)snprintf(chunk_name, sizeof(chunk_name), "@%s", filename);
    rc = luaL_loadbuffer(L, (const char *)read_result.data, read_result.size, chunk_name);
    rl_loader_read_result_free(&read_result);
    return rc;
}

int rl_lua_resolve_path(const char *filename, char *resolved_path, size_t resolved_path_size)
{
    int explicit_path = 0;

    if (resolved_path == NULL || resolved_path_size == 0 || filename == NULL || filename[0] == '\0') {
        return -1;
    }

    explicit_path = rl_lua_is_explicit_path(filename);

    if (explicit_path) {
        rl_loader_normalize_path(filename, resolved_path, resolved_path_size);
        if (rl_loader_is_local(resolved_path)) {
            return 0;
        }
    }

    if (!explicit_path) {
        rl_loader_normalize_path(filename, resolved_path, resolved_path_size);
        if (rl_loader_is_local(resolved_path)) {
            return 0;
        }
    }

    resolved_path[0] = '\0';
    return -1;
}

static int rl_lua_require_searcher(lua_State *L)
{
    const char *module_name = luaL_checkstring(L, 1);
    char module_token[2048];
    int rc = 0;

    if (module_name == NULL || module_name[0] == '\0') {
        lua_pushstring(L, "\n\tinvalid module name");
        return 1;
    }

    (void)snprintf(module_token, sizeof(module_token), "%s", module_name);
    for (char *p = module_token; *p != '\0'; ++p) {
        if (*p == '.') {
            *p = '/';
        }
    }

    lua_getglobal(L, "package");
    lua_getfield(L, -1, "path");
    {
        const char *pkg_path = lua_tostring(L, -1);
        if (pkg_path != NULL) {
            char templates[2048];
            char *saveptr = NULL;
            char *templ = NULL;
            (void)snprintf(templates, sizeof(templates), "%s", pkg_path);
            templ = strtok_r(templates, ";", &saveptr);
            while (templ != NULL) {
                char *q = strchr(templ, '?');
                if (q != NULL) {
                    char candidate[2048];
                    const char *suffix = q + 1;
                    *q = '\0';
                    rc = rl_lua_expand_template(templ, module_token, suffix, candidate, sizeof(candidate));
                    *q = '?';
                    if (rc != 0) {
                        templ = strtok_r(NULL, ";", &saveptr);
                        continue;
                    }
                    rl_loader_normalize_path(candidate, candidate, sizeof(candidate));
                    if (candidate[0] != '/' && !rl_loader_is_local(candidate)) {
                        (void)rl_lua_fetch_to_fileio(candidate);
                    }
                    if (rl_loader_is_local(candidate)) {
                        lua_pop(L, 2);
                        rc = rl_lua_load_file_chunk(L, candidate);
                        if (rc == LUA_OK) {
                            return 1;
                        }
                        lua_settop(L, 1);
                        lua_pushfstring(L, "\n\terror loading '%s'", candidate);
                        return 1;
                    }
                }
                templ = strtok_r(NULL, ";", &saveptr);
            }
        }
    }
    lua_pop(L, 1);

    lua_getfield(L, -1, "cpath");
    {
        const char *pkg_cpath = lua_tostring(L, -1);
        int native_fetched = 0;
        if (pkg_cpath != NULL) {
            char templates[2048];
            char *saveptr = NULL;
            char *templ = NULL;
            (void)snprintf(templates, sizeof(templates), "%s", pkg_cpath);
            templ = strtok_r(templates, ";", &saveptr);
            while (templ != NULL && !native_fetched) {
                char *q = strchr(templ, '?');
                if (q != NULL) {
                    char candidate[2048];
                    const char *suffix = q + 1;
                    *q = '\0';
                    rc = rl_lua_expand_template(templ, module_token, suffix, candidate, sizeof(candidate));
                    *q = '?';
                    if (rc != 0) {
                        templ = strtok_r(NULL, ";", &saveptr);
                        continue;
                    }
                    rl_loader_normalize_path(candidate, candidate, sizeof(candidate));
                    if (candidate[0] != '/') {
                        (void)rl_lua_fetch_to_fileio(candidate);
                    }
                    if (rl_loader_is_local(candidate)) {
                        native_fetched = 1;
                    }
                }
                templ = strtok_r(NULL, ";", &saveptr);
            }
        }
        lua_pop(L, 2);
        if (native_fetched) {
            lua_pushfstring(L, "\n\tfetched native module candidate for '%s'", module_name);
            return 1;
        }
    }

    lua_pushfstring(L, "\n\tno module '%s' found in lua search paths", module_name);
    return 1;
}

void rl_lua_install_searcher(lua_State *L)
{
    int len = 0;

    if (L == NULL) {
        return;
    }

    lua_getglobal(L, "package");
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        return;
    }

    lua_getfield(L, -1, "searchers");
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        lua_getfield(L, -1, "loaders");
    }
    if (!lua_istable(L, -1)) {
        lua_pop(L, 2);
        return;
    }

    len = (int)lua_rawlen(L, -1);
    lua_pushcfunction(L, rl_lua_require_searcher);
    lua_rawseti(L, -2, len + 1);
    lua_pop(L, 2);
}
