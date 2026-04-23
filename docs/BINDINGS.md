# Bindings

This project currently maintains four primary bindings in an 'add as I need' cycle:

- JavaScript (wasm runtime wrapper)
- Nim (C FFI imports)
- Haxe (hxcpp / C++ FFI)
- Lua (C module + Lua-side helpers)

## Architecture: Direct API vs Frame Commands

Native bindings (Nim, Haxe) call the C API directly. Frame commands are reserved for contexts where direct calls have overhead or serialization needs:

| Context | Pattern | Rationale |
|---------|---------|-----------|
| Nim, Haxe | Direct C API calls (`rl_sprite2d_draw()`) | Native code, no boundary overhead |
| Lua module | Frame commands (`RL_RENDER_CMD_DRAW_SPRITE2D`) | VM boundary, batching, host-managed buffer |
| Remote server | Frame commands over WebSocket | Network serialization, protocol abstraction |

**Rule of thumb:**
- Writing C/Nim/Haxe? Use direct API calls.
- Writing Lua or remote gameplay code? Emit frame commands into the host buffer.

Frame command types (for Lua/remote contexts only):
- `RL_RENDER_CMD_SET_SPRITE2D_TRANSFORM` (17)
- `RL_RENDER_CMD_DRAW_SPRITE2D` (18)

Native bindings do not define frame command structs — they are an implementation detail of the Lua/remote transport layer.

## JavaScript Binding

Files:

- `bindings/js/rl.js`
- `bindings/js/rl_scratch.js`
- `bindings/js/rl_module_export.js`

Role:

- Wraps the Emscripten `Module` and exposes a higher-level `RL` object.
- Calls C exports via `ccall`.
- Initializes and reads the scratch area bridge for vectors/input state.
- Provides browser-oriented runtime setup helpers (`canvas`, output wiring, resize handling).
- Exposes a single per-frame update entrypoint (`RL.update()`) that maps to `rl_update_to_scratch()` for wasm input snapshot refresh.

Scratch design goals:

- Use explicit bridge naming at the C/wasm boundary:
  - `*_to_scratch`: C writes result data into shared scratch memory for JS to read.
  - `*_from_scratch`: C reads host-provided data from scratch memory (used where needed).
- Keep JS-facing APIs abstracted from scratch internals:
  - JS wrappers expose normal methods (`getWindowPosition()`, `measureTextEx()`, etc.).
  - Internally, wrappers may call a `*_to_scratch` bridge and then read via `rl_scratch.js`.
- Reduce boundary overhead:
  - For vec/struct-like return values, one wasm call + one scratch read is preferred over many scalar calls.

Used by:

- `examples/www/js_example.js`

Notes:

- This is the primary browser-facing API layer.
- It includes async-oriented wrappers for asset-backed calls like model/font creation.
- Input state uses `getMouseState()` (x/y/wheel/left/right/middle/buttons) and `getKeyboardState()`.
  - button states use shared constants exposed on `rl`:
    - `rl.BUTTON_UP`
    - `rl.BUTTON_PRESSED`
    - `rl.BUTTON_DOWN`
    - `rl.BUTTON_RELEASED`
- Picking helpers available in JS:
  - `pickModel(...)`
  - `pickSprite3D(...)`
  - telemetry helpers:
    - `resetPickStats()`
    - `getPickStats()`
- JS `init(opts)` calls `rl_init()` with a wasm `rl_init_config_t` built from:
  - `windowWidth`, `windowHeight`, `windowTitle`, `windowFlags`, `assetHost`, `loaderCacheDir`
  - (plus `idealWidth` / `idealHeight` for browser resize/aspect heuristics)
  - Example: `await rl.init({ windowWidth: 800, windowHeight: 600, windowTitle: "Title", windowFlags: rl.FLAG_MSAA_4X_HINT, assetHost })`
- Loader/cache helpers currently exposed in JS:
  - `uncacheFile(filename)`
  - `clearCache()`
- JS binding-level TaskGroup ergonomics:
  - `createTaskGroup(onComplete?, onError?, ctx?)`
  - `addTask`, `addImportTask`, `addImportTasks`
  - `tick()`, `process()`, `remainingTasks()`, `failedPaths()`
- JS local-create helpers for staged imports:
  - `createModelFromLocal(path)`
  - `createSprite3DFromLocal(path)`
  - `createFontFromLocal(path, fontSize)`
  - `createMusicFromLocal(path)`
- JS still carries some older wasm cache/readiness convenience helpers.
  - Treat those as compatibility wrappers until the JS binding is fully migrated to the new async loader-op API.

## Nim Binding

File:

- `bindings/nim/rl.nim`

Role:

- Exposes `librl` APIs through Nim `importc` declarations.
- Uses `rl.h` for core APIs and subsystem headers (`rl_model.h`, `rl_font.h`) where needed.
- Maps handle-based APIs to Nim (`RLHandle = uint32`).

Used by:

- `examples/nim/src/main.nim`

Notes:

- This binding is direct/low-level and close to the C surface.
- Keep declarations synchronized with header changes in `include/`.
- It maps `RLMouseState` directly to `rl_mouse_state_t` via `rl_input_get_mouse_state()`.
- It maps `RLKeyboardState` directly to `rl_keyboard_state_t` via `rl_input_get_keyboard_state()`.
- Mouse button states use shared constants:
  - `RL_BUTTON_UP`
  - `RL_BUTTON_PRESSED`
  - `RL_BUTTON_DOWN`
  - `RL_BUTTON_RELEASED`
- Picking helpers available in Nim:
  - `rl_pick_model(...)`
  - `rl_pick_sprite3d(...)`
- Window config flags are exposed in Nim:
  - `rl_window_init(width, height, title, flags)`
  - `RL_FLAG_MSAA_4X_HINT`
- Loader helpers in Nim:
  - `rl_loader_restore_fs_async()`
  - `rl_loader_import_asset_async(filename)`
  - `rl_loader_import_assets_async(filenames, count)`
  - `rl_loader_poll_task(task)`
  - `rl_loader_finish_task(task)`
  - `rl_loader_free_task(task)`
  - `rl_loader_is_local(filename)`
  - `rl_loader_uncache_file(filename)`
  - `rl_loader_clear_cache()`

Binding-level async loader ergonomics:

- `RLTaskGroup[T]` is available in Nim via `bindings/nim/rl.nim`:
  - `loaderCreateTaskGroup[T](ctx, onComplete?, onError?)`
  - `addTask`, `addImportTask`, `addImportTasks`
  - `tick()`, `process()`, `remainingTasks()`, `failedPaths()`
- The Nim example (`examples/nim/src/main.nim`) is the canonical pattern:
  - `rl_run(onInit, onTick, onShutdown, addr ctx)` drives the main loop.
  - `if not ctx.loadingGroup.isNil and ctx.loadingGroup.process() > 0: return` gates frame work until imports finish.

## Haxe Binding

Files:

- `bindings/haxe/rl/RL.hx`
- `bindings/haxe/rl/RLTaskGroup.hx`
- `examples/haxe/src/InjectLibRL.hx`
- `examples/haxe/src/Main.hx`

Role:

- Exposes `librl` APIs to Haxe via hxcpp externs (C++ FFI).
- Uses `@:cppInclude`, `@:buildXml`, and `@:functionCode` to:
  - Include `rl.h` / `rl_loader.h`.
  - Inject link flags (`librl.a` / `librl.wasm.a`).
  - Bridge static Haxe methods to C callbacks for `rl_run` and `rl_loader_queue_task`.

Used by:

- `examples/haxe/src/Main.hx`

Notes:

- The Haxe binding mirrors the C naming:
  - `RL.modelCreate`, `RL.sprite3dCreate`, `RL.camera3dCreate`, etc.
  - Constants like `RL.FLAG_MSAA_4X_HINT`, `RL.CAMERA_PERSPECTIVE`.
- WASM builds use hxcpp's emscripten toolchain with `MODULARIZE=1` and `EXPORT_ES6=1`:
  - `examples/haxe/build.wasm.hxml`
  - `examples/haxe/build.hxml` dispatches between the desktop and wasm build configs.
  - `InjectLibRL.hx` adds the emcc linker flags and links against `librl.wasm.a`.

Async loader sugar:

- The binding exposes:
  - `RL.loaderImportAssetAsync(path: String): RLLoaderTaskPtr`
  - `RL.loaderPollTask(task: RLLoaderTaskPtr): Bool`
  - `RL.loaderFinishTask(task: RLLoaderTaskPtr): Int`
  - `RL.loaderCreateTaskGroup<T>(onComplete?, onError?, ctx?)`
  - `RLTaskGroup.addImportTask(path, onSuccess?, onError?)`
  - `RLTaskGroup.process()`, `RLTaskGroup.remainingTasks()`, `RLTaskGroup.failedPaths()`
  - `RL.loaderQueueTask(task, path, onSuccess, onFailure, ctx)`
- `rl_run` is wrapped so Haxe passes plain lifecycle functions with a Haxe context object:
  - `RL.run(onInit, onTick, onShutdown, ctx)`
- `rl_loader_queue_task` is wrapped so Haxe loader callbacks use plain `(path, ctx)` handlers:
  - `RL.loaderQueueTask(task, path, onAssetReady, onAssetFailed, ctx)`
- The example (`examples/haxe/src/Main.hx`) is the canonical reference for:
  - Using `rl_run` with `init/tick/shutdown`.
  - Non-blocking async import gating via `loadingGroup.process()`.
  - Per-task import callbacks receiving `(path, ctx)` for handle construction.

## Lua Binding

Files:

- `bindings/lua/rl_lua.c`
- `bindings/lua/rl_lua_loader.c`
- `bindings/lua/rl_task_group.lua`

Role:

- `bindings/lua/rl_lua*.c` exposes direct C-backed Lua APIs.
- `bindings/lua/rl_task_group.lua` provides helper ergonomics for non-blocking multi-task loader orchestration.

Notes:

- Keep direct C binding files separate from helper/ergonomic Lua modules.
- Lua TaskGroup helper mirrors the same non-blocking pattern used in Haxe/JS/Nim:
  - `create(on_complete?, on_error?, ctx?)`
  - `add_import_task(...)`, `tick()`, `process()`, `failed_paths()`

## Status and Scope

- Active primary bindings: JavaScript, Nim, Haxe, Lua
- Not treated as a primary binding surface: generated/auxiliary artifacts

## Binding Naming

- Bindings should mirror the C API shape and intent, but use naming that is idiomatic for the target language/runtime.
- The C API naming convention is the template:
  - subsystem-first, lower snake case: `rl_<section>_<action>`
  - example: `rl_frame_buffer_submit`
- Per-binding naming style:
  - Lua: lower snake case function names.
    - examples: `frame_buffer_submit`, `window_get_screen_size`
  - Nim: close to C surface (snake_case / importc-aligned naming).
  - Haxe: lowerCamelCase method names.
    - examples: `frameBufferSubmit`, `windowGetScreenSize`
- Avoid inventing alternate verb ordering in bindings if the C API is clear.
  - prefer section-first semantics equivalent to `rl_<section>_<action>`.
- Note on macro-only C symbols:
  - `rl_module_register` is a C preprocessor macro helper, not a callable function symbol, so it is not exposed as a runtime binding API.

## Sync Guidance (Mostly for myself)
When public C headers change:

1. Update `include/*.h`.
2. Update binding layers (`bindings/js/*`, `bindings/nim/rl.nim`, `bindings/haxe/rl/RL.hx`) that expose affected functions.
3. Smoke test:
   - web (JS binding): `examples/www/?example=simple`
   - desktop Nim: `examples/nim/src/main.nim`
   - desktop Haxe: `examples/haxe/src/Main.hx`
   - wasm Nim: `npm run build:nim:wasm` + `?example=nim`
   - wasm Haxe: `npm run build:haxe:wasm` + `?example=haxe`
