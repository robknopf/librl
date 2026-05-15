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
- Window close polling is exposed as `isWindowCloseRequested()`.
- Picking helpers available in JS:
  - `pickModel(...)`
  - `pickSprite3D(...)`
  - telemetry helpers:
    - `resetPickStats()`
    - `getPickStats()`
- JS `boot(opts)` instantiates the Emscripten module and prepares the scratch/color helpers without calling `rl_init(...)`.
  - This is useful when callers need the loader-only/bootstrap path first, for example `boot() -> loaderInit() -> init()`.
  - `init(...)` and `initAsync(...)` reuse the booted module instance when one already exists.
- JS `init(opts)` calls the default synchronous `rl_init()` with a wasm `rl_init_config_t` built from:
  - `windowWidth`, `windowHeight`, `windowTitle`, `windowFlags`, `assetHost`, `loaderCacheDir`
  - (plus `idealWidth` / `idealHeight` for browser resize/aspect heuristics)
  - Example: `await rl.init({ windowWidth: 800, windowHeight: 600, windowTitle: "Title", windowFlags: rl.FLAG_MSAA_4X_HINT, assetHost })`
  - Init result constants are exposed (`INIT_OK`, `INIT_ERR_UNKNOWN`, `INIT_ERR_ALREADY_INITIALIZED`, `INIT_ERR_LOADER`, `INIT_ERR_ASSET_HOST`, `INIT_ERR_WINDOW`).
- JS `initValues(width, height, title, flags, assetHost, loaderCacheDir)` uses the flattened C helper `rl_init_values(...)` instead of marshaling `rl_init_config_t`.
- JS also exposes `initAsync(opts)` for the polling-style init path, now routed through the flattened `rl_init_values_async(...)` helper.
- JS exposes `initValuesAsync(width, height, title, flags, assetHost, loaderCacheDir)` for direct flattened polling-style init.
- JS exposes `isInitialized()` for `rl_is_initialized()`.
- JS exposes `getPlatform()` for `rl_get_platform()`.
- JS `pickModel(camera, model, mouseX, mouseY)` and `pickSprite3D(camera, sprite3d, mouseX, mouseY)` return local-space `point` / `normal` data from `rl_pick_result_t`.
- Loader/cache helpers currently exposed in JS:
  - `loaderInit([mountPoint])`
  - `loaderInitAsync([mountPoint])`
  - `loaderIsReady()`
  - `restoreFSAsync()` → task handle for `rl_loader_restore_fs_async()`
  - `importAsset(filename)` → Promise/integer result for `rl_loader_import_asset()`
  - `importAssetAsync(filename)` → task handle for `rl_loader_create_import_task()`
  - `importAssetsAsync(filenames)` → task handle via the scratch ABI and `rl_loader_import_assets_from_scratch_async()`
  - `waitForImportAssetAsync(filename)` / `waitForImportAssetsAsync(filenames)` → Promise/integer convenience wrappers around the task-returning imports
  - `uncacheAsset(filename)`
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
- JS task-returning loader helpers use the same naming convention as C: `_async` means the call starts work and returns a task handle. Default names such as `importAsset(...)` follow the synchronous/default contract, even though JS callers still `await` them when JSPI is involved.

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
- It exposes `rl_is_initialized()` and `rl_get_platform()` directly.
- Mouse button states use shared constants:
  - `RL_BUTTON_UP`
  - `RL_BUTTON_PRESSED`
  - `RL_BUTTON_DOWN`
  - `RL_BUTTON_RELEASED`
- Picking helpers available in Nim:
  - `rl_pick_model(...)`
  - `rl_pick_sprite3d(...)`
- Nim `rl_pick_model(camera, model, mouseX, mouseY)` and `rl_pick_sprite3d(camera, sprite3d, mouseX, mouseY)` read stored instance transforms; no explicit transform args remain.
- Picking helpers available in Haxe: `RL.pickModel(camera, model, mouseX, mouseY)` and `RL.pickSprite3d(camera, sprite3d, mouseX, mouseY)`, returning `RLPickResult` (`hit`, `distance`, `point: RLVec3`, `normal: RLVec3`). Transform is read from the stored instance. Stats helpers: `pickResetStats`, `pickGetBroadphaseTests`, `pickGetBroadphaseRejects`, `pickGetNarrowphaseTests`, `pickGetNarrowphaseHits`.
- **`point` and `normal` in `RLPickResult` / `rl_pick_result_t` are in local (object) space, not world space:**
  - For `pickModel`: world hit point inverse-transformed by the model's world matrix (position + rotation + scale). Origin is the model's local origin.
  - For `pickSprite3d`: `(local_x, local_y, 0)` on the billboard surface, with normal on local `+/-Z`. `local_x` and `local_y` are signed offsets from the sprite center in world units — e.g. `(-0.5, -0.5)` is bottom-left corner, `(+0.5, +0.5)` is top-right corner for a size-1 sprite.
- Window config flags are exposed in Nim:
  - `rl_window_init(width, height, title, flags)`
  - `RL_FLAG_MSAA_4X_HINT`
- Window close polling is exposed in Nim as `rl_window_close_requested()`.
- Nim exposes `rl_boot()`, which currently returns `RL_INIT_OK` without additional work. This keeps the binding lifecycle aligned with JS/Haxe callers that may use `boot() -> loader_init() -> init()`.
- Loader helpers in Nim:
  - `rl_loader_init([mount_point])`
  - `rl_loader_init_async([mount_point])`
  - `rl_loader_deinit()`
  - `rl_loader_is_initialized()` → `bool`
  - `loaderPingAssetHost(assetHost?)` → RTT ms, or `< 0` on failure
  - `rl_loader_restore_fs_async()` → `RLHandle`
  - `rl_loader_create_import_task(filename)` → `RLHandle`
  - `rl_loader_import_asset(filename)` → `cint` (`0` success)
  - `rl_loader_import_assets_async(filenames, count)` → `RLHandle`
  - `rl_loader_poll_task(task)`
  - `rl_loader_finish_task(task)`
  - `rl_loader_free_task(task)`
  - `rl_loader_is_asset_cached(filename)`
  - `rl_loader_uncache_asset(filename)`
  - `rl_loader_clear_cache()`
- Init result constants are exposed as `RL_INIT_OK` / `RL_INIT_ERR_*`.
- Nim also exposes `rl_init_async([config])`.

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

- `bindings/haxe/rl/RL.hx` — public `rl.RL` module used by authored Haxe code.
- `bindings/haxe/rl/impl/RLImpl.cpp.hx` — current hxcpp backend implementation. Contains all `@:native`, `untyped __cpp__`, `@:functionCode`, and bridge classes.
- `bindings/haxe/rl/impl/RLImpl.js.hx` — Haxe `js` backend. It imports the generated Emscripten module (`librl.js` / `librl.wasm`) directly.
- `bindings/haxe/rl/impl/RLImpl.hx` — unsupported fallback that fails compilation for targets without a backend.
- `bindings/haxe/rl/RLHandle.hx` — shared integer handle type.
- `bindings/haxe/rl/impl/RLLoaderImpl.cpp.hx` — current hxcpp-only loader impl (`RLLoader` class).
- `bindings/haxe/rl/RLTaskGroup.hx` — pure Haxe task group helper; all methods are non-inline for cppia compatibility.
- `bindings/haxe/rl/InjectLibRL.hx`
- `examples/haxe-simple/src/Main.hx`

Role:

- Exposes `librl` APIs to Haxe via hxcpp externs (C++ FFI).
- `RL.hx` is the script-facing/public API module and must remain free of `cpp.*`, `@:native`, and `untyped __cpp__`.
- `RLImpl.cpp.hx` currently holds the hxcpp-specific backend and is compiled into the host binary with `-D scriptable`.
- Uses `@:buildXml`, `@:functionCode` in `RLImpl.cpp.hx` to:
  - Include `rl.h` / `rl_loader.h`.
  - Inject link flags (`librl.a` / `librl.wasm.a`).
  - Bridge Haxe loader callbacks to `rl_loader_add_task`.

### Haxe Architecture Notes

Current state:

- `RL.hx` is now a real façade class with no target branches in its public method bodies.
- `RL.hx` delegates into `rl.impl.RLImpl`, which resolves by target:
  - `RLImpl.cpp.hx` on `cpp`
  - `RLImpl.js.hx` on `js`
  - `RLImpl.hx` for unsupported targets, which fails at compile time
- `RL.boot(?options)` is the backend bootstrap hook:
  - On hxcpp/cppia it returns `Int` and currently succeeds immediately.
  - On Haxe JS it returns `js.lib.Promise<Int>` so the JS backend can import/instantiate `librl.js` / `librl.wasm` before normal `RL.init(...)` calls.
  - The current Haxe JS backend expects the generated `librl.js` JSPI build. If `WebAssembly.Suspending` / `WebAssembly.promising` are unavailable, `RL.boot()` returns an error code and leaves the backend unbooted.
- Haxe JS returns Promises for blocking JSPI-backed calls:
  - `RL.init(...)`, `RL.initValues(...)`, `RL.deinit()`
  - `RL.loaderInit(...)`, `RL.loaderDeinit()`, `RL.loaderImportAsset(...)`
  - The `*Async` task-starting APIs keep their C semantics: they return immediate status/task handles and are polled/finished through the loader task API.
- The Haxe JS backend is separate from `bindings/js/*`; it does not use the standalone JS wrapper or scratch/SAB helper layer.
- `RLImpl.cpp.hx` keeps the raw C extern table private as `RLExterns`; authored code never imports it directly.
- There is no generic runtime fallback. New targets must add an explicit backend such as `RLImpl.lua.hx`.
- `examples/haxe-js-simple` is the current compile/run smoke test for the Haxe `js` backend. It exercises `RL.boot()` and loader init/deinit; in runtimes without JSPI support, boot returns an error code without instantiating wasm.

Target-neutral direction:

- `rl.RL` should be the stable public façade that authored Haxe code imports on every target.
- `rl.RL` should own public helpers and forward calls into a backend module; it should not collapse into a `typedef` alias of an hxcpp implementation type.
- Target-specific implementation should live under backend files selected by target, for example:
  - `bindings/haxe/rl/impl/RLImpl.cpp.hx`
  - `bindings/haxe/rl/impl/RLImpl.js.hx`
  - `bindings/haxe/rl/impl/RLImpl.lua.hx`
- The same pattern should be applied to loader internals:
  - `bindings/haxe/rl/impl/RLLoaderImpl.cpp.hx`
  - `bindings/haxe/rl/impl/RLLoaderImpl.lua.hx`

Design rules for that split:

- `RL.hx` stays target-neutral:
  - no `cpp.*`
  - no `@:native`
  - no `untyped __cpp__`
- `RLImpl.*.hx` owns target-specific plumbing.
- The backend contract is currently structural: each `RLImpl.<target>.hx` must provide the static members called by `RL.hx`.
- Do not use `RLImpl.hx` as an implementation shim; it exists only to fail clearly for unsupported targets.
- Authored/gameplay code should import only `rl.RL`, not `rl.impl.*`.
- Public handle types exposed from `rl.*` should be stable across targets; backend-specific representations such as `cpp.UInt64` should stay internal to the backend layer.

Practical implication:

- If Haxe-to-Lua support is added, the Lua backend should expose the same public `rl.RL` API through `RLImpl.lua.hx`, rather than reusing hxcpp-generated implementation names.

Used by:

- `examples/haxe-simple/src/Main.hx`

Notes:

- The Haxe binding mirrors the C naming:
  - `RL.modelCreate`, `RL.sprite3dCreate`, `RL.camera3dCreate`, etc.
  - Constants like `RL.FLAG_MSAA_4X_HINT`, `RL.CAMERA_PERSPECTIVE`.
  - Init result constants like `RL.INIT_OK`, `RL.INIT_ERR_ALREADY_INITIALIZED`.
  - `RL.isInitialized()` wraps `rl_is_initialized()`.
  - `RL.getPlatform()` wraps `rl_get_platform()`.
  - `RL.windowCloseRequested()` wraps `rl_window_close_requested()`.
- WASM builds use hxcpp's emscripten toolchain with `MODULARIZE=1` and `EXPORT_ES6=1`:
  - `examples/haxe-simple/build.wasm.hxml`
  - `examples/haxe-simple/build.hxml` dispatches between the desktop and wasm build configs.
  - `InjectLibRL.hx` adds the emcc linker flags and links against `librl.wasm.a`.
- Example-specific wasm exports live in example-local `@:buildXml` classes:
  - `examples/haxe-simple/src/ExampleWasmExports.hx`
  - `examples/haxe-runtime/src/RuntimeWasmExports.hx`
  - Keep app/runtime export lists out of `bindings/haxe/rl/InjectLibRL.hx`; it should stay focused on librl link/config flags.
- `examples/haxe-simple` is the canonical direct-librl example. It is not a host/runtime ABI example.
- `examples/haxe-runtime` is a preserved host/runtime ABI experiment. Its `rt_*` ABI helpers live inside that example, not in the librl Haxe binding.

Async loader sugar:

- The binding exposes both init contracts:
  - `RL.init(...)`
  - `RL.initAsync(...)`
  - `RL.loaderInit([mountPoint])`
  - `RL.loaderInitAsync([mountPoint])`
  - `RL.loaderIsInitialized(): Bool`
- The binding exposes:
  - `RL.loaderPingAssetHost(assetHost?): Float` → RTT ms, or `< 0` on failure
  - `RL.loaderImportAssetAsync(path: String): RLHandle`
  - `RLLoader.loaderAddTask(task, onSuccess, onFailure, userData)` with the callback path derived from `RLLoader.loaderGetTaskPath(task)`
  - `RL.loaderPollTask(task: RLHandle): Bool`
  - `RL.loaderFinishTask(task: RLHandle): Int`
  - `RL.loaderCreateTaskGroup<T>(onComplete?, onError?, ctx?)`
  - `RLTaskGroup.addImportTask(path, onSuccess?, onError?)`
  - `RLTaskGroup.process()`, `RLTaskGroup.remainingTasks()`, `RLTaskGroup.failedPaths()`
  - `RL.loaderAddTask(task, onSuccess, onFailure, ctx)`
- `rl_loader_add_task` is wrapped so Haxe loader callbacks use plain `(path, ctx)` handlers:
  - `RL.loaderAddTask(task, onAssetReady, onAssetFailed, ctx)`
- `RL.loaderAddTask(...)` consumes the task handle when queueing succeeds; use task groups or callbacks rather than polling the same handle after queueing it.
- The example (`examples/haxe-simple/src/Main.hx`) is the canonical reference for:
  - Direct `RL.init` / frame loop / `RL.deinit` usage.
  - Non-blocking async import gating via `loadingGroup.process()`.
  - Per-task import callbacks receiving `(path, ctx)` for handle construction.

## Lua Binding

Files:

- `bindings/lua/rl_lua.c`
- `bindings/lua/rl_lua_loader.c`
- `bindings/lua/rl_task_group.lua` (optional reference; logic is native in `rl_lua_task_group.c`)

Role:

- `bindings/lua/rl_lua*.c` exposes direct C-backed Lua APIs.
- **`rl.loader_create_task_group`** is implemented in C (`rl_lua_task_group.c`), same role as:
  - Haxe: `RL.loaderCreateTaskGroup` → `RLTaskGroup` (`rl/RL.hx`, `rl/RLTaskGroup.hx`)
  - Nim: `loaderCreateTaskGroup` / `RLTaskGroup` in `rl.nim`

Notes:

- The returned userdata exposes `add_task`, `add_import_task`, `add_import_tasks`, `tick`, `process`, `failed_paths`, etc.
- Lua exposes mouse button state constants (`rl.RL_BUTTON_UP`, `rl.RL_BUTTON_PRESSED`, `rl.RL_BUTTON_DOWN`, `rl.RL_BUTTON_RELEASED`).
- Lua exposes handle constants `rl.RL_CAMERA3D_DEFAULT` and `rl.RL_FONT_DEFAULT`.
- Lua exposes `rl.boot()`, which currently returns `rl.RL_INIT_OK` without additional work. This keeps the binding lifecycle aligned with JS/Haxe callers that may use `boot() -> loader_init() -> init()`.
- Lua exposes `rl.loader_ping_asset_host([asset_host])`, returning RTT ms or `< 0` on failure, for proactive asset-host diagnostics before importing.
- Lua exposes `rl.loader_init([mount_point])` and `rl.loader_deinit()` for loader-only bootstrap without full `rl.init()`.
- Lua also exposes `rl.loader_init_async([mount_point])` and `rl.init_async([config])` for the polling-style fallback path.
- Lua exposes `rl.loader_is_ready()` for `rl_loader_is_ready()`.
- Lua exposes `rl.loader_is_initialized()` for `rl_loader_is_initialized()`.
- Lua exposes `rl.loader_create_import_task(filename)` for `rl_loader_create_import_task()`.
- Lua exposes `rl.loader_import_asset(filename)` → integer return code (`0` success); on wasm this follows the same constraints as the C API (see `rl_loader_import_asset` in `rl_loader.h`).
- Lua `rl.loader_add_task(task, on_success?, on_failure?, ctx?)` derives the callback path from `rl_loader_get_task_path(task)`. Loader callbacks receive `(path, ctx)`.
- Lua exposes loader queue result constants (`rl.RL_LOADER_QUEUE_TASK_OK`, `rl.RL_LOADER_QUEUE_TASK_ERR_INVALID`, `rl.RL_LOADER_QUEUE_TASK_ERR_QUEUE_FULL`).
- Lua exposes init result constants (`rl.RL_INIT_OK`, `rl.RL_INIT_ERR_UNKNOWN`, `rl.RL_INIT_ERR_ALREADY_INITIALIZED`, `rl.RL_INIT_ERR_LOADER`, `rl.RL_INIT_ERR_ASSET_HOST`, `rl.RL_INIT_ERR_WINDOW`).
- Lua exposes `rl.is_initialized()` for `rl_is_initialized()`.
- Lua exposes `rl.get_platform()` for `rl_get_platform()`.
- Lua exposes `rl.window_close_requested()` for `rl_window_close_requested()`.

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
   - desktop Haxe: `examples/haxe-simple/src/Main.hx`
   - wasm Nim: `npm run build:nim:wasm` + `?example=nim`
   - wasm Haxe: `npm run build:haxe:wasm` + `?example=haxe`
