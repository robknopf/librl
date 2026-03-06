# API Reference (Draft)

This document summarizes the current public C API exposed by `include/*.h`.  As with the rest of this library, it is a work in progress. Caveat Emptor!

## Conventions

- Most resource APIs use `rl_handle_t` (`unsigned int`) as an opaque handle.
- `0` is generally an invalid handle unless a subsystem documents otherwise.
- Call `rl_init()` before using subsystem APIs, and `rl_deinit()` at shutdown.

## Resource Lifetime Semantics

- Not all handle-backed resources use the same storage/lifetime policy.
- Colors are lightweight value handles (RGBA) and are not refcounted shared GPU assets.
- Textures are shared GPU assets with path-based deduplication and internal refcounting.
- This difference is intentional: textures are expensive to allocate/upload, colors are cheap values.

## Core (`include/rl.h`)

Main responsibilities:

- Runtime lifecycle (`rl_init`, `rl_deinit`)
- Window management (`rl_init_window`, size/position/title helpers)
- Frame lifecycle (`rl_begin_drawing`, `rl_end_drawing`, `rl_update`)
- Basic drawing (text, rectangles, cubes, fps helpers)
- 2D/3D mode switching
- Mouse position/state helpers (`rl_get_mouse*`)
- Basic lighting toggles and parameters
- Timing helpers (`rl_get_time`)
- Text measurement helpers

Header note:

- `rl.h` is the primary/core header and defines shared base types (`rl_handle_t`, math/data structs) plus core runtime/window/draw APIs.
- For many integrations, including only `rl.h` is enough.
- If you need subsystem-specific APIs (model/font/color/loader/scratch), include their corresponding headers explicitly.

## Camera3D (`include/rl_camera3d.h`)

Main responsibilities:

- Handle-based camera creation/update/activation
- Active camera tracking (`rl_camera3d_get_active`)
- Reserved default camera handle (`RL_CAMERA3D_DEFAULT` / `rl_camera3d_get_default`)

Notes:

- `rl_begin_mode_3d()` uses the current active camera.
- If no active camera is set, `rl_begin_mode_3d()` falls back to the default camera.

## Colors (`include/rl_color.h`)

Main responsibilities:

- Built-in color handles (e.g. `RL_COLOR_WHITE`, `RL_COLOR_BLACK`, etc.)
- Create/destroy runtime color handles

## Fonts (`include/rl_font.h`)

Main responsibilities:

- Font creation/destruction by filename + size
- Default font handle access

## Models (`include/rl_model.h`)

Main responsibilities:

- Model creation/destruction by filename
- Model draw
- Validity checks (`rl_model_is_valid`, `rl_model_is_valid_strict`)
- Animation clip/frame queries
- Animation control (`set_animation`, speed/loop, update/tick)

Notes:

- `rl_model_create()` requires a ready window/graphics context.
- On model load failure, the implementation substitutes a visible placeholder cube.

## Textures (`include/rl_texture.h`)

Main responsibilities:

- Texture creation/destruction by filename
- Shared texture-handle reuse for identical normalized paths

## Sprite3D (`include/rl_sprite3d.h`)

Main responsibilities:

- 3D sprite creation from path or texture handle
- Billboard drawing in active 3D camera context
- Sprite handle destruction

## Loader (`include/rl_loader.h`)

Main responsibilities:

- Loader subsystem init/deinit
- Shared backing for cross-platform asset loading and cache behavior

Notes:

- URL and file-path normalization flow is centralized through `path_normalize()`.
- URL normalization preserves scheme/authority/query/fragment and normalizes only URL path segments.

## Wasm File I/O Lifecycle (IDBFS)

Notes:

- On wasm, `fileio_init()` mounts IDBFS and starts an async restore (`FS.syncfs(true, ...)`) through a single internal sync path.
- `Module.fileio_idbfs_ready` is `false` from init start until restore succeeds.
- `Module.fileio_idbfs_ready` is set back to `false` at deinit start before a best-effort async flush (`FS.syncfs(false, ...)`).
- A sync-overlap guard (`Module.fileio_idbfs_syncing`) prevents concurrent sync operations.
- JS callers that need cache-first behavior should wait for readiness before first asset-backed load.

## Scratch Area (`include/rl_scratch.h`)

Main responsibilities:

- Shared memory struct for high-frequency data exchange with host runtimes:
  - vectors, matrices, quaternions, colors, rectangles
  - mouse/keyboard/gamepad/touch state
- Direct pointer access (`rl_scratch_area_get`)
- Layout metadata (`rl_scratch_area_get_offsets`) for JS/wasm interop
- Set/get helpers and update/clear functions

---

If you want, this can be expanded into a full function-by-function reference with argument semantics, expected call ordering, and error behavior per API.
