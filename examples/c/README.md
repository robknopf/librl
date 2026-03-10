# Desktop C Example

This example intentionally mixes:

- direct raylib runtime calls (`InitWindow`, `BeginDrawing`, `BeginMode3D`, `DrawText`, etc.)
- `librl` handle-based helpers for assets (`rl_font_create`, `rl_model_create`, `rl_sprite3d_create`, etc.)
- `rl_addon` + `rl_event` flow to drive the Lua addon (`lua.do_file`, `lua.do_string`)

## Build

```bash
make -C examples/c desktop
```

The C example builds/links the in-tree Lua addon (`addons/lua`) and its Lua dependency on demand.

## Build (Wasm)

```bash
make -C examples/c wasm
make -C examples/c wasm-debug
```

- `wasm` outputs `examples/c/out/main.js`
- `wasm-debug` outputs `examples/c/out/main.debug.js` (debug checks + source maps)

## Run

```bash
make -C examples/c run
```

By default, assets are fetched from:

`http://localhost:4444/assets`

Override with:

```bash
RL_ASSET_HOST=http://localhost:4444/assets make -C examples/c run
```
