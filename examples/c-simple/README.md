# C Simple Example

This example is a plain C runtime using the same host lifecycle as the other
examples. It mirrors the same "simple" scene used by `haxe-simple` and
`nim-simple`: the same camera/light setup, the same asset set, the same
animated sprite/model scene, and the same overlay/picking flow.

- `rt_boot()` resets runtime state
- `rt_init(host_context)` initializes `librl`, queues the same startup assets as
  the Haxe/Nim simple examples, and clears the initial frame
- `rt_tick(dt)` calls `rl_tick()`, lets the shared loader queue complete asset
  callbacks, draws a frame, and returns `0` / stopped / failed
- `rt_shutdown()` releases resources and calls `rl_deinit()`

Desktop uses `main.c` as a small host loop. Web uses
`examples/www/public/js/runtime_host.js` to call the exported `rt_*` functions
and pump `rt_tick()` with `requestAnimationFrame`.

## Build

```bash
make -C examples/c-simple desktop
make -C examples/c-simple wasm
```

## Run

```bash
make -C examples/c-simple run
```

By default, desktop assets are fetched from:

`https://localhost:4444`

For web builds, assets are loaded relative to the served page.
