#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <raylib.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include "lua_interop.h"
#include "path/path.h"

int lua_interop_init(lua_interop_vm_t *vm, const char *mount_point)
{
    lua_State *L = NULL;
    const char *resolved_mount = NULL;
    size_t mount_len = 0;

    if (vm == NULL) {
        return -1;
    }

    vm->L = NULL;
    vm->owns_fileio = false;
    vm->mount_point = NULL;

    resolved_mount = (mount_point != NULL) ? mount_point : "";
    mount_len = strlen(resolved_mount);
    vm->mount_point = (char *)malloc(mount_len + 1);
    if (vm->mount_point == NULL) {
        fprintf(stderr, "lua_interop_init: failed to allocate mount_point\n");
        return -2;
    }

    memcpy(vm->mount_point, resolved_mount, mount_len + 1);

    L = luaL_newstate();
    if (L == NULL) {
        fprintf(stderr, "lua_interop_init: luaL_newstate failed\n");
        free(vm->mount_point);
        vm->mount_point = NULL;
        return -3;
    }

    luaL_openlibs(L);
    vm->L = L;
    vm->owns_fileio = true;
    return 0;
}

void lua_interop_deinit(lua_interop_vm_t *vm)
{
    if (vm == NULL) {
        return;
    }

    if (vm->L != NULL) {
        lua_close(vm->L);
        vm->L = NULL;
    }

    if (vm->mount_point != NULL) {
        free(vm->mount_point);
        vm->mount_point = NULL;
    }
}

int lua_interop_run_file(lua_interop_vm_t *vm, const char *filename)
{
    int data_size = 0;
    unsigned char *data = NULL;
    int status = 0;
    char *full_path = NULL;

    if (vm == NULL || vm->L == NULL || filename == NULL || filename[0] == '\0') {
        return -1;
    }

    full_path = path_join_alloc((vm->mount_point != NULL) ? vm->mount_point : "", filename);
    if (full_path == NULL) {
        fprintf(stderr, "lua_interop_run_file: failed to join path for '%s'\n", filename);
        return -2;
    }

    // Uses raylib file callback path, which librl routes through rl_loader.
    data = LoadFileData(full_path, &data_size);
    if (data == NULL || data_size <= 0) {
        fprintf(stderr, "lua_interop_run_file: failed to read '%s' (from '%s')\n", filename, full_path);
        free(full_path);
        return -3;
    }

    status = luaL_loadbuffer(vm->L, (const char *)data, (size_t)data_size, filename);
    if (status == 0) {
        status = lua_pcall(vm->L, 0, LUA_MULTRET, 0);
    }

    if (status != 0) {
        const char *msg = lua_tostring(vm->L, -1);
        fprintf(stderr, "lua_interop_run_file: Lua error in '%s': %s\n", filename, msg ? msg : "(unknown)");
        lua_pop(vm->L, 1);
        UnloadFileData(data);
        free(full_path);
        return -4;
    }

    UnloadFileData(data);
    free(full_path);
    return 0;
}
