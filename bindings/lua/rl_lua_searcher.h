#ifndef RL_LUA_SEARCHER_H
#define RL_LUA_SEARCHER_H

#include <stddef.h>

#include <lua.h>

int rl_lua_fetch_to_fileio(const char *relative_path);
int rl_lua_load_file_chunk(lua_State *L, const char *filename);
int rl_lua_resolve_path(const char *filename, char *resolved_path, size_t resolved_path_size);
void rl_lua_install_searcher(lua_State *L);

#endif /* RL_LUA_SEARCHER_H */
