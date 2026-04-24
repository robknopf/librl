#ifndef RL_LUA_TASK_GROUP_H
#define RL_LUA_TASK_GROUP_H

#include <lua.h>

/* Registers loader_create_task_group on the rl module (matches Haxe RL.loaderCreateTaskGroup). */
void rl_register_lua_task_group(lua_State *L);

#endif
