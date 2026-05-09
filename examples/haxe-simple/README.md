# Haxe Simple Example

This is the canonical direct-librl Haxe example.

It uses librl directly:

- `RL.init(...)`
- `RL.tick()` once per frame
- async asset import via `RLTaskGroup`
- `RL.deinit()` on shutdown

It intentionally does not use the host/runtime `rt_*` ABI. The wasm build exposes
example-local `example_init`, `example_frame`, and `example_shutdown` functions so
the browser page can schedule frames.
