# Lua Example

This example loads `rl.so` from a local `libs/` folder.

## Run

```bash
make -C examples/lua run
```

What this does:

- builds `lib/librl.so` and `lib/rl.so` via `make rl_lua`
- copies `rl.so` and `librl.so` into `examples/lua/libs/`
- runs `boot.lua`, which sets `package.cpath`, calls `rl.init`, fetches the entry with `loader_import_asset_async` (coroutine + `loader_tick` until done), then loads the script with `loader_read_local` on the path from `loader_get_task_path` and runs the chunk (no `package.path` guessing).

`RL_LUA_ENTRY` can override the default (e.g. `RL_LUA_ENTRY=assets/scripts/lua/main2.lua make run`). The entry should respect `_G.__LIBRL_BOOT` and skip a second `rl.init` when loaded via `boot.lua`.

