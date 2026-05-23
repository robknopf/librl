# Lua Example (stock desktop Lua)

Runs gameplay on a system Lua/LuaJIT interpreter using the same scripts as the
`c-lua` web/desktop hosts. Only the bootstrap and native libs are local:

- `boot.lua`
- `libs/rl.so` — Lua binding (`bindings/lua`, built by `make rl_lua`)
- `libs/librl.so` — core shared library

## Prerequisites

- Lua or LuaJIT on `PATH` (`luajit`, `lua5.1`, or `lua`)
- Vite (or another static server) serving `examples/www/` on **port 4444**
  - from repo root: `npm run serve` or `npm run dev`
  - scripts and assets are fetched from the configured asset host, not copied into this directory

## Run

```bash
make -C examples/lua run
```

This builds `lib/librl.so` and `lib/rl.so`, copies them into `examples/lua/libs/`,
then runs `boot.lua`.

## Bootstrap flow

`boot.lua`:

1. Prepends `examples/lua/libs/` to `package.cpath`
2. `require("rl")` — loads the native binding; installs the asset-backed `require` searcher
3. `rl.fs_init()` — temporary loader cache for bootstrapping
4. `rl.asset_set_host("https://localhost:4444")` — must match your Vite host (scheme/host/port)
5. Prepends `assets/scripts/lua` to `package.path`
6. `require("assets/scripts/lua/runtime_wrapper")`
7. Pumps the same lifecycle as the C host: `rt_boot` → `rt_init` → `rt_tick` loop → `rt_shutdown`
8. Calls `rl.fs_deinit()` after boot so the script owns full librl lifecycle via `rl.init` / `rl.deinit`

## Script loading

Gameplay files live under `examples/www/public/assets/scripts/lua/` and are served
by Vite. The `rl` binding's custom `require` searcher resolves module names through
`package.path`, fetches missing files from the asset host into the fs cache, then
loads from cache.

Default app module: `main` (see `runtime_wrapper.lua`).

## Alternate runtime module

Pass the module name as the first argument after `boot.lua`:

```bash
cd examples/lua
lua boot.lua lua_demo
```

Use `--root` / `-r` to change the script root (default: `assets/scripts/lua`):

```bash
lua boot.lua --root assets/scripts/lua main
```

## Relation to `c-lua`

`examples/lua/boot.lua` is the stock-Lua equivalent of the thin C host in
`examples/c-lua/main.c`. Both pump `runtime_wrapper` and share:

- `examples/www/public/assets/scripts/lua/runtime_wrapper.lua`
- `examples/www/public/assets/scripts/lua/main.lua`

The C host statically links liblua and the binding; this example loads `rl.so`
dynamically for faster binding iteration on desktop.
