#ifndef LUA_INTEROP_H
#define LUA_INTEROP_H

#include <stdbool.h>

typedef struct lua_State lua_State;

typedef struct lua_interop_vm_t {
    lua_State *L;
    bool owns_fileio;
    char *mount_point;
} lua_interop_vm_t;

int lua_interop_init(lua_interop_vm_t *vm, const char *mount_point);
void lua_interop_deinit(lua_interop_vm_t *vm);
int lua_interop_run_file(lua_interop_vm_t *vm, const char *filename);

#endif // LUA_INTEROP_H
