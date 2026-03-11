# librl

`librl` is a small C wrapper layer around raylib, with build targets for:

- Desktop static library (`.a`)
- WebAssembly module (`lib/librl.js` + `lib/librl.wasm`)
- WebAssembly static archive (`.wasm.a`)

## Purpose

`librl` is a binding-oriented runtime layer around raylib that provides stable handles, cross-platform asset loading, and shared runtime plumbing for non-C hosts and embedded scripting runtimes. It is still an active work in progress.

Key goals:

- Handle-based APIs for resources:
  - Colors, fonts, models, textures, sprite3d, and camera3d are exposed as `rl_handle_t` IDs instead of raw raylib structs.
  - This keeps bindings simpler and safer by avoiding direct pointer/struct lifetime management in host languages.
- Thin host/runtime shell:
  - Keep platform bootstrap, frame boundaries, and resource ownership on the host side.
  - Let higher-level hosts or scripts describe gameplay and per-frame presentation against a stable handle-based API.
- Cached asset systems:
  - Loader and resource subsystems are designed for reuse/caching instead of one-shot loads.
  - Model/font/color systems keep runtime-owned instances keyed by handles.
- Cross-platform file I/O abstraction:
  - Unified loading path across desktop and web builds.
  - Web can fetch/store assets in browser-backed storage (IndexedDB).
  - Desktop can read/write local files through the same higher-level loader path.
- LRU-backed loader behavior:
  - `rl_loader` uses LRU cache infrastructure to reduce repeated decode/fetch work.
  - This is especially useful for wasm/browser workflows where fetch/decode churn can be costly.
- URL/path normalization helpers:
  - File and URL normalization now share one path utility flow.
  - URL normalization preserves scheme/authority/query/fragment and normalizes URL path segments.
- Script-driven iteration:
  - The current reference direction is a thin native/wasm host with Lua driving gameplay and frame generation.
  - Longer-term, the same host boundary should support evaluating alternate scripting backends without redesigning the core runtime.

## Current Direction

- `librl` is moving toward a thin-host model where a native or wasm app owns platform/bootstrap concerns and scripts drive gameplay and per-frame presentation.
- The current reference path for that is the Lua module:
  - host initializes the Lua module
  - Lua script provides `get_config()`, `init()`, `update(frame)`, and `shutdown()`
  - Lua emits transient frame commands for draw/audio work
  - host drains those commands during its normal frame loop
- Lua-side helper modules now exist for common resource types:
  - model
  - texture
  - sprite3d
  - sound
  - music
  - camera3d
  - font
- The C example is now primarily a thin host shell around that workflow.

## Repository Layout

- `src/` librl runtime and integration code
- `deps/wgutils/` shared C utility/runtime modules (path/fileio/fetch/etc.)
- `include/` public headers
- `bindings/` JS/Nim binding helpers
- `tests/` desktop and web test harnesses

## Prerequisites

- `make`
- Desktop C toolchain (`gcc`, `ar`)
- Emscripten SDK on `PATH` (`emcc`, `emar`) for wasm builds
- raylib dependency source compatible with this project (fetched by `make deps`)

## Build

Build raylib dependency first:

```bash
make deps
```

Build desktop static library:

```bash
make desktop
```

Build wasm JS module:

```bash
make wasm
```

Build wasm static archive:

```bash
make wasm_archive
```

Build all targets:

```bash
make
```

Lua module is now built as a separate module artifact (not compiled into core `librl`):

```bash
make -C modules/lua deps
make -C modules/lua
make -C modules/lua lua_module_test_desktop
```

## Enabling Modules

`librl` modules are linked in at build time (not runtime-loaded).

1. Build the module archive you want:
```bash
make -C modules/lua desktop
```
2. Link it with your app (plus its deps), alongside `librl`:
```bash
-L./lib -lrl ./modules/lua/lib/librl_lua.a ./modules/lua/deps/liblua/lib/liblua.a
```
3. Initialize the module from your app:
```c
const rl_module_api_t *api = NULL;
void *module_state = NULL;
rl_module_host_api_t host = {0}; // set log/alloc/event callbacks as needed
char error[256] = {0};

if (rl_module_init("lua", &host, &api, &module_state, error, sizeof(error)) != 0) {
    // handle error
}
```
4. Per-frame, call `api->update(module_state, dt)` if provided, then call:
```c
rl_module_deinit_instance(api, module_state);
```
on shutdown.

For the current Lua-driven workflow, see:

- [examples/c/main.c](/home/rknopf/projects/whirlinggizmo/experiments/raylib/librl/examples/c/main.c)
- [examples/www/public/assets/scripts/lua_demo.lua](/home/rknopf/projects/whirlinggizmo/experiments/raylib/librl/examples/www/public/assets/scripts/lua_demo.lua)

## Test

Run full test suite from repo root:

```bash
make test
```

Run test targets directly:

```bash
make -C tests test
make -C tests test_desktop
make -C tests test_wasm
```

Debug mode:

```bash
make DEV=1 desktop
make DEV=1 wasm
```

Clean outputs:

```bash
make clean
```

## Build Outputs

- Desktop archive: `lib/librl.a` (or `lib/librl_d.a` with `DEV=1`)
- Wasm JS loader: `lib/librl.js`
- Type declarations for JS tooling: `lib/librl.d.ts` (copied from `types/librl.d.ts` during build)
- Wasm archive: `lib/librl.wasm.a` (or `lib/librl_d.wasm.a` with `DEV=1`)

## Notes

- `rl_model_create()` requires a ready window/graphics context. If model loading fails, it substitutes a visible placeholder cube.
- Keep the README high-level. Exact C APIs, Lua bindings, frame command details, and script-facing runtime surface belong in the docs below.
- API surface documentation: see [API.md](docs/API.md).
- Binding documentation: see [BINDINGS.md](docs/BINDINGS.md).
- Maintainer-focused build/runtime notes: see [DEV_NOTES.md](docs/DEV_NOTES.md).

## TODO

- So, so many things. See [TODO.md](TODO.md) for the list of things I'm playing around with.

## License

See [LICENSE](LICENSE).
