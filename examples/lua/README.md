# Lua Example

This example runs on stock desktop Lua/LuaJIT, but it still uses the same
shared runtime scripts as the embedded `c-lua` example under
`examples/www/public/assets/scripts/lua/`.

Only the bootstrap is local:

- `boot.lua`
- `libs/rl.so`
- `libs/librl.so`

## Run

```bash
make -C examples/lua run
```

What this does:

- builds `lib/librl.so` and `lib/rl.so` via `make rl_lua`
- copies `rl.so` and `librl.so` into `examples/lua/libs/`
- runs local `boot.lua`

## Bootstrap Flow

`boot.lua` does the following:

1. prepends `examples/lua/libs/` to `package.cpath`
2. `require("rl")` loads the local native Lua binding module
3. initializes the loader with `rl.loader_init()`
4. points the loader at the desktop asset host with `rl.loader_set_asset_host("https://localhost:4444")`
5. prepends `assets/scripts/lua` to `package.path`
6. `require(...)`s the shared `runtime_wrapper` module
7. `runtime_wrapper` then `require(...)`s the requested runtime module, which defaults to `main`

The important detail is that the app runtime is not loaded from the local
filesystem. The `rl` Lua module installs a custom loader-backed `require`
searcher, so missing Lua modules are:

- resolved through `package.path`
- fetched from the configured asset host
- written into the loader/fileio cache
- loaded from that cached local copy

That is why this desktop Lua example can run the same files that `c-lua` and
the web-served Lua examples use:

- `examples/www/public/assets/scripts/lua/runtime_wrapper.lua`
- `examples/www/public/assets/scripts/lua/main.lua`

In other words, `examples/lua/boot.lua` is the stock-Lua equivalent of the
thin host in `examples/c-lua/main.c`.

## Alternate Runtime Module

`boot.lua` accepts an alternate runtime module name as its final positional
argument. For example:

```bash
cd examples/lua
lua boot.lua main
```

or with a different script root:

```bash
cd examples/lua
lua boot.lua --root assets/scripts/lua main
```
