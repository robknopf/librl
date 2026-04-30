# Embedded Lua C Example

This example embeds Lua directly into a C host and runs the shared
`assets/scripts/lua/simple.lua` app in hosted mode.

## What This Example Does

The C host in [main.c](/home/rknopf/projects/whirlinggizmo/experiments/raylib/librl/examples/c-lua/main.c) is intentionally small:

- it calls `rl_init(...)`
- it creates a Lua VM
- it preloads the `rl` Lua bindings from `bindings/lua/*.c`
- it injects a hosted-only `rl.set_callbacks(init, tick, shutdown, ctx)` helper
- it starts one outer librl lifecycle with `host_init`, `host_tick`, and `host_shutdown`

The Lua script in [simple.lua](/home/rknopf/projects/whirlinggizmo/experiments/raylib/librl/examples/www/public/assets/scripts/lua/simple.lua) then switches behavior based on host mode:

- hosted mode (`__LIBRL_HOSTED`): call `rl.set_callbacks(...)`
- standalone Lua mode: call `rl.init(...)` and `rl.run(...)`

That means the same Lua script can run:

- from this embedded C example
- from the direct Lua example in `examples/lua`

## Hosted Lifecycle

The outer C lifecycle exists so loader readiness still happens in the normal
`rl_start(...)` / `rl_tick()` / `rl_run()` flow.

The callback chain is:

1. `main()` creates the Lua VM and arms the outer lifecycle.
2. `host_init()` runs after loader readiness and requires `simple.lua`.
3. Hosted `simple.lua` calls `rl.set_callbacks(on_init, on_tick, on_shutdown, ctx)`.
4. `host_init`, `host_tick`, and `host_shutdown` springboard into those registered Lua callbacks.

This avoids loading the Lua app too early on web, where requiring the script
from `main()` would block on the loader restore barrier before JS has a chance
to yield.

## Desktop And Web

Desktop and web share the same hosted Lua logic. The difference is only who
drives frames:

- desktop: `main.c` uses `rl_run(host_init, host_tick, host_shutdown, ...)`
- web: `main.c` uses `rl_start(...)`, and JS drives exported `rl_tick()`

On web, [c-lua_example.js](/home/rknopf/projects/whirlinggizmo/experiments/raylib/librl/examples/www/public/js/c-lua_example.js) pumps frames with `Module.ccall(..., { async: true })`, so the wasm build exports `rl_tick` through JSPI.

## Build

```bash
make -C examples/c-lua desktop
make -C examples/c-lua wasm
make -C examples/c-lua wasm-debug
```

The example links:

- core `librl`
- the direct Lua bindings from `bindings/lua/*.c`
- the vendored Lua archive from `deps/liblua`

## Run

```bash
make -C examples/c-lua run
```

By default, desktop assets are fetched from:

`https://localhost:4444`

Override with:

```bash
RL_ASSET_HOST=https://localhost:4444 make -C examples/c-lua run
```

For web builds, assets are loaded relative to the served page.
