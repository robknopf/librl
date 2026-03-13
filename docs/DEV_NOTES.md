# Development Notes

Internal maintainer notes for quick session handoff. Keep this practical and current.

## Fast Start

From repo root:

```bash
make deps
make desktop
make wasm
make -C examples/c desktop
make test
```

Useful variants:

```bash
make DEV=1 desktop
make DEV=1 wasm
make -C tests test_desktop
make -C tests test_wasm
make clean
cd examples/nim && nim clean
```

## Build and Flag Conventions

- WebGL2 is the default target in project wasm builds:
  - `-s MIN_WEBGL_VERSION=2`
  - `-s MAX_WEBGL_VERSION=2`
- `MIN/MAX_WEBGL_VERSION` are linker settings and should be passed in LDFLAGS (not compile-only CFLAGS), otherwise emcc warns they are ignored.
- `deps/libraylib/Makefile` controls raylib wasm graphics API for `libraylib.wasm.a`.
- Default raylib wasm graphics is ES3 (`GRAPHICS_API_OPENGL_ES3`), but builders can override:

```bash
make -C deps/libraylib wasm_release RAYLIB_WASM_GRAPHICS=GRAPHICS_API_OPENGL_ES2
```

## Nested Repo Note (`deps/libraylib`)

- `deps/libraylib` is its own git repo.
- Main repo commits do not include nested repo history changes.
- If `git status` in the main repo shows `deps/libraylib` changed, that means nested repo HEAD/working tree differs from the commit currently referenced by the parent checkout.
- Handle nested repo updates explicitly in that repo.

## Logging and Output Notes

- raylib logs are rerouted via `SetTraceLogCallback(...)` in `examples/c/main.c`.
- We map raylib levels into wgutils logger levels and currently emit via:
  - `log_message(level, "raylib", 0, "%s", msg);`
- `log_message` supports optional source metadata:
  - file present + line > 0: emits file and line
  - file present + line <= 0: emits file only
  - file null: emits no source suffix
- Keep redirected raylib logs source-light unless source info is reliable.

## Naming Conventions

- Prefer subsystem-first public API names:
  - `rl_window_init`
  - `rl_text_draw`
  - `rl_frame_runner_run`
  - `rl_module_lua_get_api`
- For async starters that return a pollable task, make that explicit with `_async`:
  - `rl_loader_import_asset_async`
  - `rl_loader_restore_fs_async`
  - `fileio_restore_async`
  - `fetch_url_async`
- Keep async task lifecycle verbs readable and non-suffixed:
  - `*_poll_task`
  - `*_finish_task`
  - `*_free_task`
- Callback entry points should use `on_<name>` when they are invoked by another system:
  - `on_init`
  - `on_tick`
  - `on_shutdown`
- Internal processing helpers should use `handle_<name>`:
  - `handle_boot_restore`
  - `handle_boot_prepare`
- Avoid `<name>_handler` naming unless there is a strong reason.
- Module implementation naming should follow `rl_module_<backend>_*`:
  - file/header: `rl_module_lua.c`, `rl_module_lua.h`
  - getter: `rl_module_lua_get_api()`
- Module identity strings like `"lua"` are runtime identifiers, not a reason to use older `rl_lua_*` symbol naming.

## Audio API State

- `rl_music` and `rl_sound` subsystems are available in C/JS/Nim bindings.
- C example currently uses:
  - background music stream: `assets/music/ethernight_club.mp3`
  - click SFX on left mouse press: `assets/sounds/click_004.ogg`
- Cleanup order in example is explicit: destroy handles, then `rl_deinit()`, then `CloseWindow()`.

## Raylib Loader Split

- Not all raylib resource loaders honor `SetLoadFileDataCallback(...)` the same way.
- In this repo, callback-aware resource paths are:
  - textures:
    - `rl_texture_create()` -> `LoadTexture()`
    - raylib texture loading uses `LoadFileData()` through the callback-aware core path
  - models:
    - `rl_model_create()` -> `LoadModel()` / `LoadModelAnimations()`
    - raylib model loading uses callback-aware `LoadFileData()` internally
  - fonts:
    - `rl_font_create()` -> `LoadFileData()` -> `LoadFontFromMemory()`
    - this goes through the callback-aware core file loader before font decode
  - music:
    - `rl_music_create()` -> `LoadFileData()` -> `LoadMusicStreamFromMemory()`
    - this also goes through the callback-aware core file loader first
- Non-callback / bespoke path:
  - sounds:
    - `rl_sound_create()` -> `LoadSound()`
    - in the vendored raylib, `raudio.c` uses its own private `LoadFileData()` helper that falls back to `fopen()` directly
    - because of that, sound creation still assumes the file is already local before `LoadSound()` runs
- Practical implication:
  - if a file-backed resource mysteriously ignores the loader callback path, check whether raylib is using a subsystem-local loader instead of the callback-aware `rcore` path
  - sound loading is the known case today

## Web/Vite Workflow Notes

- Web examples import from `/lib/librl.js`; if `make clean` removes generated outputs while Vite is running, browser requests can fail until rebuild completes.
- Vite may not always recover automatically from a missing generated entry file (`main.js`/bundled artifacts) without a new file-change trigger.
- Practical flow:
  1. Rebuild wasm/js outputs (`make wasm` or target-specific make).
  2. Touch or re-save relevant entry file if HMR does not recover.
  3. Restart Vite only if file watching still does not pick up rebuilt outputs.

## Scripting Runtime Direction

- Current module/handle architecture is intentionally pointed at a "scripts own gameplay, host owns resources" model.
- Long-term target:
  - build the native or wasm host once
  - edit plain text scripts for gameplay iteration
  - let scripts drive per-frame logic and generate the visual/audio frame
  - keep the option to ship without a permanent interpreter if a future backend supports native/AOT output
- Lua is currently a useful reference/runtime bootstrap, not necessarily the final scripting backend.
- TinyCC and/or daslang remain plausible follow-up experiments behind the same module boundary.

### Scripting Language Criteria

- The "right" scripting language is the one that best matches these goals:
  - very fast iteration with plain text editing and hot reload
  - natural fit for immediate-mode per-frame logic
  - easy embedding behind a narrow C/module host API
  - low friction when issuing handle-based draw/audio/resource commands
  - acceptable debugging and error reporting during iteration
  - viable wasm story for web builds
  - viable native production story without forcing a permanent interpreter into shipping builds
- Lua is strong on embedding speed, maturity, and iteration, but weak on the "no interpreter in production" goal.
- TinyCC is attractive for fast C-like iteration and a more direct path to native execution, but has tradeoffs in safety, tooling, and portability.
- daslang is attractive if the priority is "script fast, ship native-ish later," but it carries more integration complexity.
- Keep the module boundary stable enough that backend experiments can be compared honestly without redesigning the host each time.

### Intended Per-Frame Contract

- Host gathers frame inputs and timing:
  - `dt`
  - keyboard snapshot
  - mouse snapshot
  - window/screen info as needed
- Host calls script `update(...)` once per tick.
- Script owns gameplay state and emits transient frame commands using host-managed handles.
- After script update, the thin host drains the frame command buffer and performs:
  - draw calls
  - audio playback commands
  - other immediate frame-side effects
- Frame commands should be cleared every frame. Do not make render state persistent by default.
- Current status:
  - `include/rl_module.h` now contains the typed frame-command ABI
  - `examples/c/main.c` is the current reference thin host
  - the host resets and drains a per-tick command buffer in clear / audio / 3D / 2D passes
  - Lua now owns almost all demo-specific scene/resource behavior
  - the Lua module keeps its own small caches so reloads can reuse stable script-visible handles for already-requested resources/colors

### API Shape We Want

- Keep handles as the main bridge between script-side logic and host-owned assets/resources.
- Prefer explicit host API calls for resource lifecycle:
  - create/load resource
  - destroy resource
  - query lightweight state if needed
- Prefer a transient per-frame command buffer for hot-path operations:
  - draw
  - play/stop audio
  - similar immediate commands
- Events are acceptable for orchestration and notifications, but should not become the primary render/audio command surface.
- Prefer a typed command structure or tagged union over stringly-typed event payloads for per-frame work.
- A ring buffer remains a reasonable future refinement if fixed-capacity/no-allocation frame submission is desirable.

### Practical Goal

- In the ideal workflow, the existing C example should be usable as a thin host shell where gameplay can be authored in scripts with a basic text editor.
- To make that real, the script layer still needs a coherent contract for:
  - `init/update/draw`-style lifecycle or equivalent
  - input access
  - resource creation returning handles
  - handle-based draw/audio commands
  - predictable hot reload behavior
  - good source-aware logging/errors

## Current Lua Runtime Shape

- Current Lua entrypoints:
  - `get_config()`
  - `init()`
  - `load()`
  - `update(frame)`
  - `unload()`
  - `serialize()`
  - `unserialize(state)`
  - `shutdown()`
- Ordering in the C example:
  1. host initializes librl and Lua module
  2. host emits `lua.add_path("assets/scripts/lua")`
  3. host emits `lua.do_file("main.lua")`
  4. host asks the module for config through `api->get_config`
  5. host creates window / sets target FPS
  6. host calls module `start`
  7. Lua runs one-time `init()` if present
  8. Lua runs `load()` if present
  9. host calls Lua `update(frame)` every tick
  10. on reload, Lua runs `serialize()` -> `unload()` -> new chunk -> `load()` -> `unserialize(state)`
  11. on module teardown, Lua runs `unload()` and then `shutdown()`
- `get_config()` currently supports:
  - `width`
  - `height`
  - `title`
  - `target_fps`
  - `flags`
- Lua module currently exposes common window flag constants for `get_config()`.
- Lifecycle intent:
  - `init()` is one-time constructor-style runtime setup
  - `load()` / `unload()` are reloadable code-lifetime hooks
  - `serialize()` / `unserialize(state)` are optional state transfer hooks for HCR
  - `shutdown()` is one-time destructor-style teardown

## Current Lua Support Modules

- Lua modules now exist under `examples/www/public/assets/scripts/lua/`:
  - `color.lua`
  - `model.lua`
  - `texture.lua`
  - `sprite3d.lua`
  - `sound.lua`
  - `music.lua`
  - `camera3d.lua`
  - `font.lua`
- These are intended to be the first layer of a Lua-side standard library:
  - C stays flat and handle-based
  - Lua gets object-like helpers with state and methods
- Current pattern:
  - `Color.create(r, g, b, a)` returns a wrapper around a runtime-created color handle with `:destroy()`
  - `Model.load(path)` returns a table with transform/animation fields and `:draw()`, `:pick()`, `:destroy()`
  - similar shape for texture/sprite/sound/music/font/camera wrappers

## Immediate Next Steps

- Decide how Lua event listener ownership should work across reloads:
  - current script-facing API exists: `event_on`, `event_off`, `event_emit`
  - current temporary policy is script-managed listener teardown
  - follow-up is ownership/generation tracking so reload cleanup can be selective
- Decide whether the host fallback `ClearBackground(RAYWHITE)` remains in `main.c` or whether Lua fully owns frame clear.
- Harden the current frame-command path instead of redesigning it from scratch:
  - clarify overflow behavior
  - decide whether the host-local fixed buffer is enough or should become shared infrastructure
  - document the current command drain order and ownership more explicitly
- HCR follow-up after adding `load/unload/serialize/unserialize`:
  - decide exact persistence rules for script globals vs restored state
  - decide whether reload should stay in the same VM or move toward new-VM swap later
  - decide whether unload/load should become mandatory for script modules or remain optional hooks
  - decide whether event listeners should remain script-managed or become auto-cleaned once listener ownership metadata exists
- Document the Lua script-facing surface in a smaller user-facing note once the lifecycle and wrappers stabilize.

## Assets and Credits

- Credits file is at `examples/www/public/assets/CREDITS.md`.
- Current credits include:
  - Kevin MacLeod track attribution (CC BY 3.0)
  - `click_004.ogg` attribution to Kenney (CC0/public domain)

## Common Gotchas

- Seeing `GLSL ES 1.00` at startup means you are effectively on WebGL1 path.
- Seeing NPOT warning (`limited NPOT support`) usually indicates WebGL1 constraints or non-mipmap/non-repeat constraints for NPOT textures.
- Duplicate/buried wasm flags can happen between root, examples, tests, and deps makefiles; prefer a single shared variable per makefile where possible.
- Binding changes should be reflected in:
  - `bindings/js/rl.js`
  - `bindings/nim/rl.nim`
  - `docs/API.md`
