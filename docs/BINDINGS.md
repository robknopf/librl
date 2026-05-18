# Bindings

This project currently maintains four primary bindings in an 'add as I need' cycle:

- JavaScript (wasm runtime wrapper)
- Nim (C FFI imports)
- Haxe (hxcpp / C++ FFI)
- Lua (C module + Lua-side helpers)

## Native Type Policy

All user-facing binding APIs must expose native language types — not C FFI types. C FFI types (`cint`, `cfloat`, `cstring`, `Int32`, etc.) are an implementation detail of the C bridge layer and must not appear in public proc/method signatures or constants.

| Binding | Public types | C bridge types (private) |
|---------|-------------|--------------------------|
| Nim | `int`, `float`, `string`, `bool` | `cint`, `cfloat`, `cstring` in `_c`/`_raw` procs |
| Haxe | `Int`, `Float`, `String`, `Bool` | hxcpp externs stay inside `RLImpl.*.hx` |
| Lua | Lua number, string | C types internal to `bindings/lua/*.c` |
| JS | JS `number`, `string` | `ccall` / Emscripten internals stay in `bindings/js/rl.js` |

**Rule:** if a user would need to write `.cint`, `.cfloat`, `.cstring`, or an explicit integer cast at the call site, the binding is incomplete and needs a wrapper.

**Pattern (Nim example):**
```nim
# private C bridge
proc rl_foo_c(x: cint): cint {.importc: "rl_foo", cdecl, header: "rl.h".}

# public user-facing wrapper
proc rl_foo*(x: int): int {.inline.} = rl_foo_c(x.cint).int
```

Constants follow the same rule: `RL_INIT_OK`, `RL_TICK_FAILED`, etc. must be the target language's native integer, not a C-cast literal.

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

Role:

- `lib/librl.js` + `lib/librl.wasm` are the raw Emscripten runtime artifacts.
- `bindings/js/rl.js` is the standalone JS binding wrapper that imports `lib/librl.js` and exposes the higher-level `RL` object.
- Calls C exports via `ccall`.
- Initializes and reads the scratch area bridge for vectors/input state.
- Provides browser-oriented runtime setup helpers (`canvas`, resize handling, module boot/init flow).
- Exposes explicit scratch refresh helpers for wasm input snapshot refresh (`refreshScratch()` in JS, `scratchRefresh()` in Haxe, `scratch_refresh` in Lua).

Scratch design goals:

- Use explicit bridge naming at the C/wasm boundary:
  - `*_to_scratch`: C writes result data into shared scratch memory for JS to read.
  - `*_from_scratch`: C reads host-provided data from scratch memory (used where needed).
- Keep JS-facing APIs abstracted from scratch internals:
  - JS wrappers expose normal methods (`getWindowPosition()`, `measureTextEx()`, etc.).
  - Internally, wrappers may call a `*_to_scratch` bridge and then read via `bindings/js/rl.js`.
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
  - `pickSprite3d(...)`
  - telemetry helpers:
    - `resetPickStats()`
    - `getPickStats()`
- JS `boot(opts)` instantiates the Emscripten module and prepares the scratch/color helpers without calling `rl_init(...)`.
  - This is useful when callers need the loader-only/bootstrap path first, for example `boot() -> fileioInit() -> init()`.
  - `boot(...)` is the canonical place for module/browser options such as `canvasId`, `modulePath`, `wasmPath`, `idealWidth`, `idealHeight`, and optional callback hooks like `print`, `printErr`, and `locateFile`.
  - `modulePath` selects the raw Emscripten JS runtime module (`lib/librl.js` by default, resolved relative to `bindings/js/rl.js`).
  - `init(...)` and `initAsync(...)` reuse the booted module instance when one already exists.
- JS `init(opts)` calls the default synchronous `rl_init()` with a wasm `rl_init_config_t` built from:
  - `windowWidth`, `windowHeight`, `windowTitle`, `windowFlags`, `assetHost`, `fileioBaseDir`
  - Example: `await rl.init({ windowWidth: 800, windowHeight: 600, windowTitle: "Title", windowFlags: rl.FLAG_MSAA_4X_HINT, assetHost })`
  - Init result constants are exposed (`INIT_OK`, `INIT_ERR_UNKNOWN`, `INIT_ERR_ALREADY_INITIALIZED`, `INIT_ERR_LOADER`, `INIT_ERR_ASSET_HOST`, `INIT_ERR_WINDOW`).
- JS `initValues(width, height, title, flags, assetHost, fileioBaseDir)` uses the flattened C helper `rl_init_values(...)` instead of marshaling `rl_init_config_t`.
- JS also exposes `initAsync(opts)` for the polling-style init path, now routed through the flattened `rl_init_values_async(...)` helper.
- JS exposes `initValuesAsync(width, height, title, flags, assetHost, fileioBaseDir)` for direct flattened polling-style init.
- In JS, polling-style `*Async` entrypoints keep the same immediate-return contract as the other bindings:
  - `initAsync(...)`, `initValuesAsync(...)`, and `fileioInitAsync(...)` return plain integer status codes.
  - task-style fileio APIs like `fileioRestoreAsync()` / `ensureAsync()` return task handles immediately.
- JS exposes `isInitialized()` for `rl_is_initialized()`.
- JS exposes `getPlatform()` for `rl_get_platform()`.
- Version queries (`rl_version_*` in `rl_version.h`) are exposed on all bindings:
  - JS: `versionMajor()`, `versionMinor()`, `versionPatch()`, `versionLabel()`, `versionNumber()`, `versionString()`
  - Nim: `rl_version_major()`, … (plus `RL_VERSION_*` constants)
  - Haxe: `RL.versionMajor()`, … (plus `RL.VERSION_*` constants)
  - Lua: `rl.version_major()`, …
- Binding/core alignment: `make binding-version` (runs with `desktop` / `shared` / `wasm` / `rl_lua`) writes `bindings/*/gen/*` from `include/rl_version.h`. Each binding queries `rl_version_*` from librl, compares to its stamp, logs both versions, and applies local policy (`validate_version()` / `validateVersion()` / `rl_validate_version()` return `0` ok, `1` patch drift, `< 0` fatal). Checks run at load/boot (not `init`): Lua on `require("rl")` and `rl.boot()`; JS after wasm load; Nim/Haxe on `rl_boot()` / `RL.boot()`.
- JS `pickModel(camera, model, mouseX, mouseY)` and `pickSprite3d(camera, sprite3d, mouseX, mouseY)` return local-space `point` / `normal` data from `rl_pick_result_t`.
- Fileio helpers currently exposed in JS:
  - `fileioInit([baseDir])`
  - `fileioInitAsync([baseDir])`
  - `fileioDeinit()`
  - `fileioIsReady()`
  - `fileioRestoreAsync()` → task handle for `rl_fileio_restore_async()`
  - `fileioEnsure(localPath, src?)` → Promise/integer result for `rl_fileio_ensure()`
    - JS warns when `filename` ends in `.gltf`, because this synchronous/JSPI path does not currently follow `.gltf` dependencies.
  - `fileioEnsureAsync(localPath, src?)` → task handle for `rl_fileio_ensure_async()`
  - `fileioEnsureGroupAsync(filenames)` → task handle via the scratch ABI and `rl_fileio_ensure_group_from_scratch_async()`
  - `waitForFileioEnsureAsync(localPath)` / `waitForFileioEnsureGroupAsync(filenames)` → Promise/integer convenience wrappers around the task-returning imports
  - `fileioRead(filename)` → `rl_fileio_read` (copy into a `Uint8Array`) or `null` on error / missing data pointer
  - `fileioRemove(filename)`
  - `fileioClear()`
- JS binding-level TaskGroup ergonomics:
  - `createTaskGroup(onComplete?, onError?, ctx?)`
  - `addTask`, `addImportTask`, `addImportTasks`
  - `tick()`, `process()`, `remainingTasks()`, `failedPaths()`
- JS `addTask(task, onSuccess?, onFailure?, ctx?)` now mirrors the Haxe/cpp callback contract by installing local JS springboard callbacks around `rl_fileio_add_task(...)`.
- JS `create*` helpers now match the other bindings: they create resources from paths that are already available in librl's local filesystem/cache.
  - Call `fileioEnsure(...)`, `waitForFileioEnsureAsync(...)`, task groups, or another fileio flow first when the asset is not local yet.
  - This applies to `createFont`, `createModel`, `createMusic`, `createSound`, `createTexture`, `createSprite3d`, and `createSprite2D`.
- JS task-returning fileio helpers use the same naming convention as C: `_async` means the call starts work and returns a task handle. Default names such as `fileioEnsure(...)` follow the synchronous/default contract, even though JS callers still `await` them when JSPI is involved.

## Nim Binding

File:

- `bindings/nim/rl.nim`

Role:

- Exposes `librl` APIs through Nim `importc` declarations.
- Uses `rl.h` for core APIs and subsystem headers (`rl_model.h`, `rl_font.h`) where needed.
- Maps handle-based APIs to Nim (`RLHandle = uint32`).

Used by:

- `examples/nim-simple/src/main.nim`

Notes:

- All public-facing Nim procs use native Nim types (`int`, `float`, `string`) — not C FFI types (`cint`, `cfloat`, `cstring`). C-imported procs that must use C types are named with a `_c` or `_raw` suffix and kept private. See the Native Type Policy in `AGENTS.md`.
- Keep declarations synchronized with header changes in `include/`.
- It maps `RLMouseState` directly to `rl_mouse_state_t` via `rl_input_get_mouse_state()`.
- It maps `RLKeyboardState` directly to `rl_keyboard_state_t` via `rl_input_get_keyboard_state()`.
- It exposes `rl_is_initialized()` and `rl_get_platform()` directly.
- Mouse button states use shared constants (plain `int`):
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
- Nim exposes `rl_boot([config])`.
  - On JS, `rl_boot` dynamically imports `bindings/js/rl.js`, boots the wrapper, and patches color constants.
  - `RLBootConfig` on JS currently exposes:
    - `bindingsPath`
    - `canvasId`
    - `modulePath`
    - `wasmPath`
    - `idealWidth`
    - `idealHeight`
    - `print`
    - `printErr`
    - `locateFile`
  - `bindingsPath` lets callers override the runtime path to `bindings/js/rl.js`; if omitted, Nim JS defaults to `"/bindings/js/rl.js"`.
  - On Nim JS, `print` and `printErr` are forwarded into the wrapper `env` object. `locateFile` is currently accepted for API parity but ignored with a warning.
  - On native targets, `rl_boot` loads nothing (static link) but still runs the binding/core version check, then returns `RL_INIT_OK`.
- Fileio helpers in Nim (all return native `int` or `bool`):
  - `rl_fileio_init([base_dir])` → `int`
  - `rl_fileio_init_async([base_dir])` → `int`
  - `rl_fileio_deinit()`
  - `rl_fileio_is_initialized()` → `bool`
  - `fileioPingAssetHost(assetHost?)` → `float` RTT ms, or `< 0` on failure
  - `rl_fileio_restore_async()` → `RLHandle`
  - `rl_fileio_ensure_async(localPath, src?)` → `RLHandle`
  - `rl_fileio_ensure(localPath, src?)` → `int` (`0` success)
  - `rl_fileio_ensure_group_async(filenames, count)` → `RLHandle`
  - `rl_fileio_poll(task)` → `bool`
  - `rl_fileio_finish(task)` → `int`
  - `rl_fileio_free(task)`
  - `rl_fileio_exists(filename)` → `bool`
  - `rl_fileio_remove(filename)` → `int`
  - `rl_fileio_clear()` → `int`
- Init result constants are exposed as `RL_INIT_OK` / `RL_INIT_ERR_*` (plain `int`).
- Nim also exposes `rl_init_async([config])`.

Binding-level async fileio ergonomics:

- `RLTaskGroup[T]` is available in Nim via `bindings/nim/rl.nim`:
  - `fileioCreateTaskGroup[T](ctx, onComplete?, onError?)`
  - `addTask`, `addImportTask`, `addImportTasks`
  - `tick()`, `process()`, `remainingTasks()`, `failedPaths()`
- The Nim example (`examples/nim-simple/src/main.nim`) is the canonical pattern:
  - `rl_run(onInit, onTick, onShutdown, addr ctx)` drives the main loop.
  - `if not ctx.loadingGroup.isNil and ctx.loadingGroup.process() > 0: return` gates frame work until imports finish.

## Haxe Binding

Files:

- `bindings/haxe/rl/RL.hx` — public `rl.RL` module used by authored Haxe code.
- `bindings/haxe/rl/impl/RLImpl.cpp.hx` — current hxcpp backend implementation. Contains all `@:native`, `untyped __cpp__`, `@:functionCode`, and bridge classes.
- `bindings/haxe/rl/impl/RLImpl.js.hx` — Haxe `js` backend. It is a thin adapter over the standalone JS binding exported from `bindings/js/rl.js`.
- `bindings/haxe/rl/impl/RLImpl.hx` — unsupported fallback that fails compilation for targets without a backend.
- `bindings/haxe/rl/RLHandle.hx` — shared integer handle type.
- `bindings/haxe/rl/impl/RLFileioImpl.cpp.hx` — current hxcpp-only fileio impl (`RLFileio` class).
- `bindings/haxe/rl/RLTaskGroup.hx` — pure Haxe task group helper; all methods are non-inline for cppia compatibility.
- `bindings/haxe/rl/InjectLibRL.hx`
- `examples/haxe-simple/src/Main.hx`

Role:

- Exposes `librl` APIs to Haxe via hxcpp externs (C++ FFI).
- `RL.hx` is the script-facing/public API module and must remain free of `cpp.*`, `@:native`, and `untyped __cpp__`.
- `RLImpl.cpp.hx` currently holds the hxcpp-specific backend and is compiled into the host binary with `-D scriptable`.
- Uses `@:buildXml`, `@:functionCode` in `RLImpl.cpp.hx` to:
  - Include `rl.h` / `rl_fileio.h`.
  - Inject link flags (`librl.a` / `librl.wasm.a`).
  - Bridge Haxe loader callbacks to `rl_fileio_add_task`.

### Haxe Architecture Notes

Current state:

- `RL.hx` is now a real façade class with no target branches in its public method bodies.
- `RL.hx` delegates into `rl.impl.RLImpl`, which resolves by target:
  - `RLImpl.cpp.hx` on `cpp`
  - `RLImpl.js.hx` on `js`
  - `RLImpl.hx` for unsupported targets, which fails at compile time
- `RL.boot(?config)` is the backend bootstrap hook:
  - On hxcpp/cppia it returns `Int`, runs the binding/core version check, and succeeds immediately when load is not required.
  - On Haxe JS it returns `js.lib.Promise<Int>` so the JS backend can import `bindings/js/rl.js`, which then instantiates `lib/librl.js` / `lib/librl.wasm` before normal `RL.init(...)` calls.
  - The current Haxe JS backend expects the generated raw `lib/librl.js` JSPI build plus the standalone wrapper in `bindings/js/rl.js`. If `WebAssembly.Suspending` / `WebAssembly.promising` are unavailable, `RL.boot()` returns an error code and leaves the backend unbooted.
  - Haxe JS uses a typed `RLBootConfig` surface with flattened fields like `bindingsPath`, `canvasId`, `modulePath`, `wasmPath`, `idealWidth`, `idealHeight`, `print`, `printErr`, and `locateFile`.
- Haxe JS returns Promises for blocking JSPI-backed calls:
  - `RL.init(...)`, `RL.initValues(...)`, `RL.deinit()`
  - `RL.fileioInit(...)`, `RL.fileioDeinit()`, `RL.fileioEnsure(...)`
  - The `*Async` task-starting APIs keep their C semantics: they return immediate status/task handles and are polled/finished through the fileio task API.
- The Haxe JS backend now reuses `bindings/js/*` exclusively. `RLImpl.js.hx` no longer calls the wasm exports directly; all browser-side behavior flows through the JS binding layer.
- On Haxe JS, `RL.scratchRefresh()` forwards to the JS binding's scratch refresh path. Call it in the tick/frame loop before reading scratch-backed state such as mouse or keyboard snapshots.
- `RLImpl.cpp.hx` keeps the raw C extern table private as `RLExterns`; authored code never imports it directly.
- There is no generic runtime fallback. New targets must add an explicit backend such as `RLImpl.lua.hx`.
- `examples/haxe-js-simple` is the current compile/run smoke test for the Haxe `js` backend. It exercises `RL.boot()` and fileio init/deinit; in runtimes without JSPI support, boot returns an error code without instantiating wasm.

Target-neutral direction:

- `rl.RL` should be the stable public façade that authored Haxe code imports on every target.
- `rl.RL` should own public helpers and forward calls into a backend module; it should not collapse into a `typedef` alias of an hxcpp implementation type.
- Target-specific implementation should live under backend files selected by target, for example:
  - `bindings/haxe/rl/impl/RLImpl.cpp.hx`
  - `bindings/haxe/rl/impl/RLImpl.js.hx`
  - `bindings/haxe/rl/impl/RLImpl.lua.hx`
- The same pattern should be applied to fileio internals:
  - `bindings/haxe/rl/impl/RLFileioImpl.cpp.hx`
  - `bindings/haxe/rl/impl/RLFileioImpl.lua.hx`

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
  - `examples/haxe-simple/src/InjectWasmExports.hx`
  - Keep app/runtime export lists out of `bindings/haxe/rl/InjectLibRL.hx`; it should stay focused on librl link/config flags.
- `examples/haxe-simple` is the canonical Haxe example and the canonical host/runtime ABI example for Haxe in this repo.

Async fileio sugar:

- The binding exposes both init contracts:
  - `RL.init(...)`
  - `RL.initAsync(...)`
  - `RL.fileioInit([baseDir])`
  - `RL.fileioInitAsync([baseDir])`
  - `RL.fileioIsInitialized(): Bool`
- The binding exposes:
  - `RL.fileioPingAssetHost(assetHost?): Float` → RTT ms, or `< 0` on failure
  - `RL.fileioEnsureAsync(localPath: String, ?src: String): RLHandle`
  - `RLFileio.fileioAddTask(task, onSuccess, onFailure, userData)` with the callback path derived from `RLFileio.fileioGetPath(task)`
  - `RL.fileioPoll(task: RLHandle): Bool`
  - `RL.fileioFinish(task: RLHandle): Int`
  - `RL.fileioCreateTaskGroup<T>(onComplete?, onError?, ctx?)`
  - `RLTaskGroup.addImportTask(path, onSuccess?, onError?)`
  - `RLTaskGroup.process()`, `RLTaskGroup.remainingTasks()`, `RLTaskGroup.failedPaths()`
  - `RL.fileioAddTask(task, onSuccess, onFailure, ctx)`
- `rl_fileio_add_task` is wrapped so Haxe fileio callbacks use plain `(path, ctx)` handlers:
  - `RL.fileioAddTask(task, onAssetReady, onAssetFailed, ctx)`
- `RL.fileioAddTask(...)` consumes the task handle when queueing succeeds; use task groups or callbacks rather than polling the same handle after queueing it.
- The example (`examples/haxe-simple/src/Main.hx`) is the canonical reference for:
  - Direct `RL.init` / frame loop / `RL.deinit` usage.
  - Non-blocking async import gating via `loadingGroup.process()`.
  - Per-task import callbacks receiving `(path, ctx)` for handle construction.

## Lua Binding

Files:

- `bindings/lua/rl_lua.c`
- `bindings/lua/rl_lua_fileio.c`
- `bindings/lua/rl_task_group.lua` (optional reference; logic is native in `rl_lua_task_group.c`)

Role:

- `bindings/lua/rl_lua*.c` exposes direct C-backed Lua APIs.
- **`rl.fileio_create_task_group`** is implemented in C (`rl_lua_task_group.c`), same role as:
  - Haxe: `RL.fileioCreateTaskGroup` → `RLTaskGroup` (`rl/RL.hx`, `rl/RLTaskGroup.hx`)
  - Nim: `fileioCreateTaskGroup` / `RLTaskGroup` in `rl.nim`

Notes:

- The returned userdata exposes `add_task`, `add_import_task`, `add_import_tasks`, `tick`, `process`, `failed_paths`, etc.
- Lua exposes mouse button state constants (`rl.RL_BUTTON_UP`, `rl.RL_BUTTON_PRESSED`, `rl.RL_BUTTON_DOWN`, `rl.RL_BUTTON_RELEASED`).
- Lua exposes handle constants `rl.RL_CAMERA3D_DEFAULT` and `rl.RL_FONT_DEFAULT`.
- Lua exposes `rl.boot()`, which runs the binding/core version check and returns `rl.RL_INIT_OK` (same check as `require("rl")`). Use `boot() -> fileio_init() -> init()` when mirroring JS/Haxe lifecycle; `require` alone already validated at load.
- Lua exposes `rl.fileio_ping_asset_host([asset_host])`, returning RTT ms or `< 0` on failure, for proactive asset-host diagnostics before importing.
- Lua exposes `rl.fileio_init([base_dir])` and `rl.fileio_deinit()` for fileio-only bootstrap without full `rl.init()`.
- Lua also exposes `rl.fileio_init_async([base_dir])` and `rl.init_async([config])` for the polling-style fallback path.
- Lua exposes `rl.fileio_is_ready()` for `rl_fileio_is_ready()`.
- Lua exposes `rl.fileio_is_initialized()` for `rl_fileio_is_initialized()`.
- Lua exposes `rl.fileio_ensure_async(local_path, src?)` for `rl_fileio_ensure_async()`.
- Lua exposes `rl.fileio_ensure(local_path, src?)` → integer return code (`0` success); on wasm this follows the same constraints as the C API (see `rl_fileio_ensure` in `rl_fileio.h`).
- Lua `rl.fileio_add_task(task, on_success?, on_failure?, ctx?)` derives the callback path from `rl_fileio_get_path(task)`. Fileio callbacks receive `(path, ctx)`.
- Lua exposes fileio queue result constants (`rl.RL_FILEIO_ADD_TASK_OK`, `rl.RL_FILEIO_ADD_TASK_ERR_INVALID`, `rl.RL_FILEIO_ADD_TASK_ERR_QUEUE_FULL`).
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
  - Nim: snake_case aligned with C names, but all public procs use native Nim types (`int`/`float`/`string`). Internal C bridge procs use `_c` or `_raw` suffix.
  - Haxe: lowerCamelCase method names.
    - examples: `frameBufferSubmit`, `windowGetScreenSize`
- Avoid inventing alternate verb ordering in bindings if the C API is clear.
  - prefer section-first semantics equivalent to `rl_<section>_<action>`.

## Sync Guidance (Mostly for myself)
When public C headers change:

1. Update `include/*.h`.
2. Update binding layers (`bindings/js/*`, `bindings/nim/rl.nim`, `bindings/haxe/rl/RL.hx`) that expose affected functions.
3. Smoke test:
   - web (JS binding): `examples/www/?example=simple`
   - desktop Nim: `examples/nim-simple/src/main.nim`
   - desktop Haxe: `examples/haxe-simple/src/Main.hx`
   - wasm Nim: `npm run build:nim:wasm` + `?example=nim-wasm-simple`
   - wasm Haxe: `npm run build:haxe:wasm` + `?example=haxe-wasm-simple`
