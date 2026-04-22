# API Reference (Draft)

This document summarizes the current public C API exposed by `include/*.h`.  As with the rest of this library, it is a work in progress. Caveat Emptor!

## Conventions

- Most resource APIs use `rl_handle_t` (`unsigned int`) as an opaque handle.
- `0` is generally an invalid handle unless a subsystem documents otherwise.
- Call `rl_init()` before using subsystem APIs, and `rl_deinit()` at shutdown.

## Resource Lifetime Semantics

- Not all handle-backed resources use the same storage/lifetime policy.
- Colors are lightweight pooled value handles (RGBA) and are not refcounted shared GPU assets.
- Textures are shared GPU assets with path-based deduplication and internal refcounting.
- Music streams are handle-backed runtime resources; each handle owns its decoded stream/data until destroyed.
- Sounds are handle-backed runtime resources intended for short one-shot SFX.
- This difference is intentional: textures are expensive to allocate/upload, colors are cheap values.

## Core (`include/rl.h`)

Main responsibilities:

- Runtime lifecycle (`rl_init`, `rl_deinit`)
- App loop lifecycle (`rl_start`, `rl_tick`, `rl_stop`, `rl_run`, `rl_set_target_fps`)
- Render lifecycle (`rl_render_begin`, `rl_render_end`)
- Basic drawing (text, fps helpers)
- 2D/3D mode switching
- Mouse/keyboard input helpers (`rl_input_get_mouse*`, `rl_input_get_keyboard_state`)
- Basic lighting toggles and parameters
- Timing helpers (`rl_get_time`, `rl_get_delta_time`)
- Text measurement helpers

Header note:

- `rl.h` is the primary/core header for runtime/frame/draw APIs.
- Shared base types (`rl_handle_t`, math/data structs) live in `rl_types.h`.
- For many integrations, including only `rl.h` is enough.
- If you need subsystem-specific APIs (window/model/font/color/loader/scratch/shape), include their corresponding headers explicitly.

## Window (`include/rl_window.h`)

Main responsibilities:

- Window open/close lifecycle (`rl_window_open(width, height, title, flags)`, `rl_window_close()`)
- Size/position/title helpers
- Monitor/screen/window queries

Notes:

- `rl_init()` initializes the runtime/subsystems; it does not open a window.
- `rl_window_close()` is window-only lifecycle and no longer performs hidden `rl_deinit()` work.

## Shape (`include/rl_shape.h`)

Main responsibilities:

- Immediate shape drawing helpers
- Current primitives:
  - `rl_shape_draw_cube(...)`
  - `rl_shape_draw_rectangle(...)`

## Camera3D (`include/rl_camera3d.h`)

Main responsibilities:

- Handle-based camera creation/update/activation
- Active camera tracking (`rl_camera3d_get_active`)
- Reserved default camera handle (`RL_CAMERA3D_DEFAULT` / `rl_camera3d_get_default`)

Notes:

- `rl_render_begin_mode_3d()` uses the current active camera.
- If no active camera is set, `rl_render_begin_mode_3d()` falls back to the default camera.

## Colors (`include/rl_color.h`)

Main responsibilities:

- Built-in color handles (e.g. `RL_COLOR_WHITE`, `RL_COLOR_BLACK`, etc.)
- Create/destroy runtime color handles

Notes:

- Built-in color constants are stable `rl_handle_t` values, not raw array indices.
- Color handles resolve through the shared handle-pool machinery and get stale-handle protection after destroy.
- Built-in colors are global singleton handles and are not caller-owned; destroying them is invalid.
- Runtime colors created with `rl_color_create(...)` are lightweight value handles, not shared/refcounted assets.

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
- Model instances now own transform state.
- Use `rl_model_set_transform(...)` to update position / XYZ rotation / non-uniform scale on the instance.
- `rl_model_draw(handle, tint)` draws using the stored transform.

## Picking (`include/rl_pick.h`)

Main responsibilities:

- Model picking from screen-space mouse coordinates with camera + model handles
- Sprite3D billboard picking from screen-space mouse coordinates with camera + sprite handles
- Return collision details (`hit`, `distance`, world-space `point` and `normal`)
- Wasm bridge helpers for JS (`rl_pick_model_to_scratch`, `rl_pick_sprite3d_to_scratch`)

Notes:

- `rl_pick_model(...)` currently targets one model handle at a time.
- `rl_pick_sprite3d(...)` targets one sprite handle at a time and uses billboard-quad collision.
- Pick inputs still take explicit transform values and have not yet been collapsed to instance-owned state.
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
- Instance-owned billboard transform (`rl_sprite3d_set_transform(...)`)
- Billboard drawing in active 3D camera context
- Sprite handle destruction

Notes:

- Sprite3D instances now own position/size state.
- `rl_sprite3d_draw(handle, tint)` draws using the stored transform.

## Sprite2D (`include/rl_sprite2d.h`)

Main responsibilities:

- 2D sprite creation from path or texture handle
- Instance-owned 2D transform (`rl_sprite2d_set_transform(...)`)
- 2D drawing with position, scale, and rotation
- Sprite handle destruction

API:

```c
rl_handle_t rl_sprite2d_create(const char *filename);           // load from file
rl_handle_t rl_sprite2d_create_from_texture(rl_handle_t texture); // from existing texture
void rl_sprite2d_set_transform(rl_handle_t sprite, float x, float y, float scale, float rotation);
void rl_sprite2d_draw(rl_handle_t sprite, rl_handle_t tint);
void rl_sprite2d_destroy(rl_handle_t sprite);
```

Notes:

- Sprite2D instances own position/scale/rotation state separate from the underlying texture.
- Use `rl_sprite2d_set_transform()` to update transform; `rl_sprite2d_draw()` uses the stored values.
- This matches the split transform/draw pattern used by `rl_model` and `rl_sprite3d`.
- For Lua/remote contexts, emit `SET_SPRITE2D_TRANSFORM` then `DRAW_SPRITE2D` frame commands.

## Debug (`include/rl_debug.h`)

Main responsibilities:

- Optional debug overlay helpers
- Built-in FPS display configuration

Notes:

- `rl_debug_enable_fps(x, y, font_size, font_path)` enables an FPS overlay and optionally loads a custom font for it.
- `rl_debug_disable()` turns the overlay off and releases any font owned by the debug subsystem.
- The current implementation draws the debug overlay automatically during `rl_render_end()`.

## App Loop (`include/rl.h`)

Main responsibilities:

- One-time app startup (`rl_start(init_fn, tick_fn, shutdown_fn, user_data)`)
- Manual stepping (`rl_tick()`)
- Loop stop/teardown (`rl_stop()`)
- Convenience one-stop run (`rl_run(init_fn, tick_fn, shutdown_fn, user_data)`)

Notes:

- `rl_start(...)` blocks until loader readiness, then runs `init_fn` once.
- `rl_tick()` is for manual stepping and returns `0` on success, `-1` for invalid usage/state.
- `rl_stop()` breaks `rl_run(...)` loops; outside loop mode it performs shutdown teardown.
- `rl_run(...)` is the convenience wrapper that starts, loops, and stops for you.

## Frame Commands (`include/rl_frame_commands.h`)

Main responsibilities:

- Fixed-capacity per-frame command buffer type (`rl_frame_command_buffer_t`)
- Append helper for module-emitted frame commands
- Ordered execution helpers for clear / audio / 3D / 2D passes

Notes:

- `rl_frame_commands_append(...)` appends one `rl_module_frame_command_t` into the buffer.
- The command buffer is intentionally host-owned; `rl_frame_runner` does not depend on it.
- The C example uses this subsystem to capture commands emitted by the Lua module, then drains them in phase order during each frame.

## Loader (`include/rl_loader.h`)

Main responsibilities:

- Asset-host configuration:
  - `rl_loader_set_asset_host(asset_host)`
  - `rl_loader_get_asset_host()`
- Async restore / import operations:
  - `rl_loader_restore_fs_async()`
  - `rl_loader_import_asset_async(filename)`
  - `rl_loader_import_assets_async(filenames, count)`
- Async task lifecycle:
  - `rl_loader_poll_task(task)`
  - `rl_loader_finish_task(task)`
  - `rl_loader_free_task(task)`
- Local cache queries and maintenance:
  - `rl_loader_is_local(filename)`
  - `rl_loader_uncache_file(filename)`
  - `rl_loader_clear_cache()`

Notes:

- The loader no longer performs hidden blocking fetches during synchronous file reads.
- Synchronous consumers like raylib file callbacks are expected to read already-local files.
- On wasm, the intended flow is:
  - start restore once
  - begin one or more prepare operations
  - poll/finish those ops across frames
  - only then call APIs that synchronously consume the prepared assets
- `rl_loader_import_asset_async(...)` is dependency-aware for assets like `.gltf` that may require additional files at load time.
- `rl_loader_import_assets_async(...)` is the convenience batch entry point used by the C example bootstrap flow.
- URL and file-path normalization flow is centralized through `path_normalize()`.
- URL normalization preserves scheme/authority/query/fragment and normalizes only URL path segments.

## Modules (`include/rl_module.h`)

Main responsibilities:

- Generic module ABI for host-driven plugin lifecycle (`init`, optional `get_config`, optional `start`, `update`, `deinit`)
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

/* The real Lua-driven host example lives in examples/c-lua/main.c. */
void run_lua_module_example(void)
{
    rl_module_host_api_t host = {0};
    rl_module_config_t config = {800, 600, 60, 0, "module example"};
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
    (void)rl_event_emit("lua.add_path", "assets/scripts/lua");
    (void)rl_event_emit("lua.do_file", "boot.lua");

    if (rl_module_get_config_instance(lua.api, lua.state, &config) == 0) {
        /* host can now create the window/runtime from config */
    }

    if (rl_module_start_instance(lua.api, lua.state) != 0) {
        fprintf(stderr, "failed to start lua module\n");
    }

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
- In the current example host, the Lua search root is `assets/scripts/lua`, so entry scripts are emitted relative to that path.
- Lua module is built as a separate archive (`modules/lua/lib/librl_lua.a` / `.wasm.a`) and linked by the host app.
- The module host API also includes `frame_command`, which is the current typed path for transient draw/audio commands emitted by scripting modules.

## Lua Module Runtime (`modules/lua`)

Current Lua module responsibilities:

- embeds the Lua VM behind the generic module ABI
- installs a Lua `require(...)` searcher backed by `lua.add_path`
- exposes script-facing bindings for:
  - frame commands (`clear`, `draw_text`, `draw_texture`, `draw_sprite3d`, `draw_model`, `play_sound`)
  - resource lifecycle (`create_color` / `destroy_color`, `load_*`, `destroy_*`)
  - stateful music control
  - camera creation/update/activation
  - model/sprite picking
  - immediate event pub/sub (`event_on`, `event_off`, `event_emit`)
  - logging with source-aware file/line reporting

Current status notes:

- The frame-command path is already active, not just planned:
  - Lua emits typed transient commands through the host `frame_command` callback
  - the current reference host in `examples/c-lua/main.c` buffers and drains them each tick
- The Lua module also keeps its own small resource/color caches so repeated script requests can reuse the same script-visible handles across HCR/reload within the same module lifetime.
- For HCR-friendly scripts, `load()` should generally reacquire cached handles while `unload()` removes side effects and script-local references rather than aggressively destroying shared cached resources.
- Lua scripts can subscribe and emit through the host event bus with `event_on`, `event_off`, and `event_emit`.
- Current event payload support is intentionally narrow: Lua currently treats event payloads as `string` or `nil`.
- Current reload caveat: Lua event listeners are not yet tracked by script/generation, so listener teardown is currently script-managed rather than auto-pruned on reload.
- Current command set is intentionally small:
  - clear background
  - draw text
  - draw sprite3d
  - draw model
  - draw texture
  - play sound
- Music control currently remains stateful resource API usage rather than a transient frame command.

### Script Lifecycle

Current Lua script entrypoints:

- `get_config()`
- `init()`
- `load()`
- `update(frame)`
- `unload()`
- `serialize()`
- `unserialize(state)`
- `shutdown()`

Current host ordering in the C example:

1. initialize `librl`
2. initialize Lua module with `rl_module_init("lua", ...)`
3. emit `lua.add_path`
4. emit `lua.do_file` for the entry script
5. call `rl_module_get_config_instance(...)`
6. create the window / set target FPS
7. call `rl_module_start_instance(...)`
8. Lua runs one-time `init()` if present
9. Lua runs `load()` for the active script if present
10. call `api->update(...)` every frame
11. on reload, Lua runs `serialize()` -> `unload()` -> new chunk -> `load()` -> `unserialize(state)`
12. on module teardown, Lua runs `unload()` and then one-time `shutdown()`

Lifecycle intent:

- `init()` is the one-time constructor for the script runtime instance
- `load()` / `unload()` are the code-lifetime hooks used for first load and HCR
- `serialize()` / `unserialize(state)` are optional state-transfer hooks for HCR
- `shutdown()` is the one-time destructor for the script runtime instance

`get_config()` currently supports:

- `width`
- `height`
- `title`
- `target_fps`
- `flags`

### `frame` Table Shape

`update(frame)` currently receives a reused Lua table with:

- `frame.dt`
- `frame.screen_w`
- `frame.screen_h`
- `frame.mouse`
- `frame.keyboard`

`frame.mouse` currently contains:

- `x`
- `y`
- `wheel`
- `left`
- `right`
- `middle`
- `buttons`

Mouse button values use the shared `RL_BUTTON_*` state encoding:

- `0`: up
- `1`: pressed
- `2`: down
- `3`: released

`frame.keyboard` currently contains:

- `keys`
- `pressed_key`
- `pressed_char`
- `num_pressed_keys`
- `pressed_keys`
- `num_pressed_chars`
- `pressed_chars`

Notes:

- `pressed_key` / `pressed_char` are event-style values, not persistent held-state indicators.
- held-state lives in `keyboard.keys[keycode]`.
- `pressed_keys[]` drains the full `GetKeyPressed()` queue for the frame.
- `pressed_chars[]` drains the full `GetCharPressed()` queue for the frame.
- The host is expected to rebuild transient frame commands every tick rather than treating them as persistent render state.

### Current Lua Built-in Globals

The Lua module currently injects a small set of constants/globals, including:

- event helpers:
  - `event_on`
  - `event_off`
  - `event_emit`
- colors:
  - `COLOR_WHITE`
  - `COLOR_BLACK`
  - `COLOR_BLUE`
  - `COLOR_RAYWHITE`
  - `COLOR_DARKBLUE`
- font:
  - `FONT_DEFAULT`
- camera:
  - `CAMERA_PERSPECTIVE`
  - `CAMERA_ORTHOGRAPHIC`
  - `CAMERA3D_DEFAULT`
- window flags for `get_config()`:
  - `FLAG_VSYNC_HINT`
  - `FLAG_FULLSCREEN_MODE`
  - `FLAG_WINDOW_RESIZABLE`
  - `FLAG_WINDOW_UNDECORATED`
  - `FLAG_WINDOW_HIDDEN`
  - `FLAG_WINDOW_MINIMIZED`
  - `FLAG_WINDOW_MAXIMIZED`
  - `FLAG_WINDOW_UNFOCUSED`
  - `FLAG_WINDOW_TOPMOST`
  - `FLAG_WINDOW_ALWAYS_RUN`
  - `FLAG_WINDOW_TRANSPARENT`
  - `FLAG_WINDOW_HIGHDPI`
  - `FLAG_MSAA_4X_HINT`
  - `FLAG_INTERLACED_HINT`

### Current Lua Resource Wrapper Modules

The example Lua runtime now layers small object-style wrappers on top of the flat C bindings:

- `color.lua`
- `model.lua`
- `texture.lua`
- `sprite3d.lua`
- `sound.lua`
- `music.lua`
- `camera3d.lua`
- `font.lua`

These currently live under `examples/www/public/assets/scripts/lua/`.

These are not part of the C ABI, but they are the current recommended Lua-side usage pattern.

## Wasm File I/O Lifecycle (IDBFS)

Notes:

- On wasm, `fileio_init()` mounts IDBFS and starts an async restore (`FS.syncfs(true, ...)`) through a single internal sync path.
- `Module.fileio_idbfs_ready` is `false` from init start until restore succeeds.
- `Module.fileio_idbfs_ready` is set back to `false` at deinit start before a best-effort async flush (`FS.syncfs(false, ...)`).
- A sync-overlap guard (`Module.fileio_idbfs_syncing`) prevents concurrent sync operations.
- JS callers that need cache-first behavior should wait for readiness before first asset-backed load.

## Logging

Notes:
- Logging goes through the shared wrapper logger (`deps/wgutils/include/logger/logger.h`), not direct `fprintf`/`printf`.
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
