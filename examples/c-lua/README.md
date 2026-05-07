# Embedded Lua C Example

This example embeds Lua directly into a C host and runs the shared
`assets/scripts/lua/main.lua` runtime module.

## What This Example Does

The C host in [main.c](/home/rknopf/projects/whirlinggizmo/experiments/raylib/librl/examples/c-lua/main.c) is intentionally thin:

- it creates a Lua VM
- it preloads the `rl` Lua bindings from `bindings/lua/*.c`
- it prepends the example script path to `package.path`
- it requires the shared runtime module `main`
- it caches and drives the returned `rt_boot`, `rt_init`, `rt_tick`, and `rt_shutdown` functions

That means the Lua runtime owns all `rl` behavior:

- `rl.init(...)`
- loader use
- per-frame `rl.tick()`
- scene setup and teardown
- `rl.deinit()`

The outer C host is just the native/wasm equivalent of `examples/lua/boot.lua`.

## Hosted Lifecycle

The callback chain is now direct:

1. `rt_boot()` creates the Lua VM, requires `main`, and calls Lua `rt_boot()`.
2. `rt_init()` forwards to Lua `rt_init(host_context)`.
3. `rt_tick(dt)` forwards to Lua `rt_tick(dt)`.
4. `rt_shutdown()` forwards to Lua `rt_shutdown()` and then closes the VM.

That keeps the host/runtime contract aligned with the other runtime examples in this repo:

- one-time boot
- one-time init
- per-frame tick returning `0` / stopped / failed
- one-time shutdown

## Desktop And Web

Desktop and web share the same runtime module. The difference is only who drives frames:

- desktop: `main.c` calls `rt_boot()`, `rt_init()`, then loops on `rt_tick()`
- web: JS calls `rt_boot()`, `rt_init()`, then pumps `rt_tick()` with `requestAnimationFrame`

On web, [c-lua_example.js](/home/rknopf/projects/whirlinggizmo/experiments/raylib/librl/examples/www/public/js/c-lua_example.js) calls `rt_boot`, `rt_init`, and `rt_tick` through JSPI-aware exports so Lua module loading and runtime init can suspend when needed.

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
