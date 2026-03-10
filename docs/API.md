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
- Music streams are handle-backed runtime resources; each handle owns its decoded stream/data until destroyed.
- Sounds are handle-backed runtime resources intended for short one-shot SFX.
- This difference is intentional: textures are expensive to allocate/upload, colors are cheap values.

## Core (`include/rl.h`)

Main responsibilities:

- Runtime lifecycle (`rl_init`, `rl_deinit`)
- Window management (`rl_init_window(width, height, title, flags)`, size/position/title helpers)
- Frame lifecycle (`rl_begin_drawing`, `rl_end_drawing`, `rl_update`)
- Basic drawing (text, rectangles, cubes, fps helpers)
- 2D/3D mode switching
- Mouse/keyboard input helpers (`rl_get_mouse*`, `rl_get_keyboard_state`)
- Basic lighting toggles and parameters
- Timing helpers (`rl_get_time`)
- Text measurement helpers

Header note:

- `rl.h` is the primary/core header for runtime/window/draw APIs.
- Shared base types (`rl_handle_t`, math/data structs) live in `rl_types.h`.
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

## Picking (`include/rl_pick.h`)

Main responsibilities:

- Model picking from screen-space mouse coordinates with camera + model handles
- Sprite3D billboard picking from screen-space mouse coordinates with camera + sprite handles
- Return collision details (`hit`, `distance`, world-space `point` and `normal`)
- Wasm bridge helpers for JS (`rl_pick_model_to_scratch`, `rl_pick_sprite3d_to_scratch`)

Notes:

- `rl_pick_model(...)` currently targets one model handle at a time.
- `rl_pick_sprite3d(...)` targets one sprite handle at a time and uses billboard-quad collision.
- Transform inputs mirror the current model draw style (position + uniform scale).
- Picking now uses broad-phase culling before narrow-phase tests:
  - models: world-space AABB ray test
  - sprite3d billboards: bounding-sphere ray test
- `rl_pick_model_to_scratch(...)` writes:
  - hit point into scratch `vector3`
  - hit normal + distance into scratch `vector4` (`x,y,z = normal`, `w = distance`)
- Pick telemetry helpers:
  - `rl_pick_reset_stats()`
  - `rl_pick_get_broadphase_tests()`
  - `rl_pick_get_broadphase_rejects()`
  - `rl_pick_get_narrowphase_tests()`
  - `rl_pick_get_narrowphase_hits()`

## Music (`include/rl_music.h`)

Main responsibilities:

- Music stream creation/destruction by filename
- Playback control (`play`, `pause`, `stop`)
- Runtime control (`set_loop`, `set_volume`)
- Status/update (`is_playing`, `update`, `update_all`)

Notes:

- Music loading uses the same loader/file callback flow as other assets.
- `rl_music_update()` (or `rl_music_update_all()`) should be called each frame while playing.

## Sound (`include/rl_sound.h`)

Main responsibilities:

- Sound creation/destruction by filename
- Playback control (`play`, `pause`, `resume`, `stop`)
- Runtime control (`set_volume`, `set_pitch`, `set_pan`)
- Status query (`is_playing`)

Notes:

- Sounds are intended for short SFX and do not require a per-frame update call.
- Sound loading uses the same loader/file callback flow as other assets.

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
- Cache management APIs:
  - `rl_loader_cache_file(filename)`
  - `rl_loader_uncache_file(filename)`
  - `rl_loader_clear_cache()`

Notes:

- URL and file-path normalization flow is centralized through `path_normalize()`.
- URL normalization preserves scheme/authority/query/fragment and normalizes only URL path segments.

## Modules (`include/rl_module.h`)

Main responsibilities:

- Generic module ABI for host-driven plugin lifecycle (`init`, `update`, `deinit`)
- Host services passed to modules through `rl_module_host_api_t`:
  - logging (`log`)
  - allocation (`alloc` / `free`)
  - immediate event pub/sub (`event_on` / `event_off` / `event_emit`)
- Module registry lookup via module name (`rl_module_init("lua", ...)`, etc.)

Minimal usage pattern:

```c
#include "rl.h"
#include "rl_module.h"
#include "rl_event.h"

typedef struct module_runtime_t {
    const rl_module_api_t *api;
    void *state;
} module_runtime_t;

static int host_event_on(void *host_user_data, const char *event_name,
                         rl_module_event_listener_fn listener, void *listener_user_data)
{
    (void)host_user_data;
    return rl_event_on(event_name, listener, listener_user_data);
}

static int host_event_off(void *host_user_data, const char *event_name,
                          rl_module_event_listener_fn listener, void *listener_user_data)
{
    (void)host_user_data;
    return rl_event_off(event_name, listener, listener_user_data);
}

static int host_event_emit(void *host_user_data, const char *event_name, void *payload)
{
    (void)host_user_data;
    return rl_event_emit(event_name, payload);
}

static void host_log(void *user_data, int level, const char *message)
{
    (void)user_data;
    (void)level;
    fprintf(stderr, "[module] %s\n", message ? message : "(null)");
}

void run_lua_module_example(void)
{
    rl_module_host_api_t host = {0};
    module_runtime_t lua = {0};
    char error[256] = {0};

    rl_init();

    host.log = host_log;
    host.event_on = host_event_on;
    host.event_off = host_event_off;
    host.event_emit = host_event_emit;

    if (rl_module_init("lua", &host, &lua.api, &lua.state, error, sizeof(error)) != 0) {
        fprintf(stderr, "failed to init lua module: %s\n", error);
        rl_deinit();
        return;
    }

    (void)rl_event_emit("lua.do_string", "print('hello from lua module')");
    (void)rl_event_emit("lua.do_file", "scripts/startup.lua");

    if (lua.api != NULL && lua.api->update != NULL) {
        (void)lua.api->update(lua.state, 1.0f / 60.0f);
    }

    rl_module_deinit_instance(lua.api, lua.state);
    rl_deinit();
}
```

Notes:

- Events are immediate/synchronous today (no queue yet).
- `lua.do_file` in current Lua module uses `fileio_read(...)`, so file paths should be loader/fileio-relative.
- Lua module is built as a separate archive (`modules/lua/lib/librl_lua.a` / `.wasm.a`) and linked by the host app.

## Wasm File I/O Lifecycle (IDBFS)

Notes:

- On wasm, `fileio_init()` mounts IDBFS and starts an async restore (`FS.syncfs(true, ...)`) through a single internal sync path.
- `Module.fileio_idbfs_ready` is `false` from init start until restore succeeds.
- `Module.fileio_idbfs_ready` is set back to `false` at deinit start before a best-effort async flush (`FS.syncfs(false, ...)`).
- A sync-overlap guard (`Module.fileio_idbfs_syncing`) prevents concurrent sync operations.
- JS callers that need cache-first behavior should wait for readiness before first asset-backed load.

## Logging

Notes:
- Logging goes through the shared wrapper logger (`deps/wgutils/logger/log.h`), not direct `fprintf`/`printf`.
- Log level is carried by logger calls (`log_error`, `log_warn`, `log_info`, `log_debug`) or explicit `log_message(...)`.
- Log messages should include a subsystem scope prefix in message text, e.g. `FILEIO: ...`.

## Input Button States (`include/rl_types.h`)

Mouse button state values are shared across C/JS/Nim:

- `RL_BUTTON_UP` (`0`)
- `RL_BUTTON_PRESSED` (`1`)
- `RL_BUTTON_DOWN` (`2`)
- `RL_BUTTON_RELEASED` (`3`)

## Scratch Area (`include/rl_scratch.h`)

This provides a method of avoiding the expensive data exchange between JS and wasm (aka: "Border Tax").  It is a shared memory block with known offsets so each system can read/write to that shared memory and not invoke another boundry call.  It's especially useful when trying to share structures that are constantly being mutated (like keyboard, mouse info, etc).

Main responsibilities:
- Shared memory struct for high-frequency data exchange with host runtimes:
  - vectors, matrices, quaternions, colors, rectangles
  - mouse/keyboard/gamepad/touch state
- Direct pointer access (`rl_scratch_get`)
- Layout metadata (`rl_scratch_get_offsets`) for JS/wasm interop
- Set/get helpers and update/clear functions

Wasm/JS boundary conventions:

- Scratch bridge entrypoints follow explicit naming:
  - `*_to_scratch`: write computed data into scratch (for JS to read through `rl_scratch.js`).
  - `*_from_scratch`: read host-provided scratch data (where applicable).
- JS bindings keep scratch abstracted:
  - `bindings/js/rl.js` exposes high-level methods.
  - Scratch-backed methods are grouped and implemented through bridge calls + `rl_scratch.js` reads.
- `rl_update()` exists for cross-platform API parity and is currently a no-op.
- Wasm scratch refresh is explicit via `rl_update_to_scratch()`.
- Most vec-return helpers used by JS follow this bridge pattern:
  - C computes native value return (`vec2_t`, etc.)
  - wasm bridge writes to scratch (`*_to_scratch`)
  - JS wrapper reads from `rl_scratch.js`

---
