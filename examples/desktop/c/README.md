# Desktop C Example

This example intentionally mixes:

- direct raylib runtime calls (`InitWindow`, `BeginDrawing`, `BeginMode3D`, `DrawText`, etc.)
- `librl` handle-based helpers for assets (`rl_font_create`, `rl_model_create`, `rl_sprite3d_create`, etc.)
- simple Lua VM interop via `lua_interop.c` using raylib `LoadFileData` (through `rl_loader`) to load `lua_demo.lua`

## Build

```bash
make -C examples/desktop/c build
```

## Run

```bash
make -C examples/desktop/c run
```

By default, assets are fetched from:

`http://localhost:4444/assets`

Override with:

```bash
RL_ASSET_HOST=http://localhost:4444/assets make -C examples/desktop/c run
```
