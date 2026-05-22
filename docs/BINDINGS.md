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
| JS | JS `number`, `string` | `ccall` / Emscripten internals stay in `bindings/js/dist/rl.js` |

**Rule:** if a user would need to write `.cint`, `.cfloat`, `.cstring`, or an explicit integer cast at the call site, the binding is incomplete and needs a wrapper.

**Pattern (Nim example):**
```nim
# private C bridge
proc rl_foo_c(x: cint): cint {.importc: "rl_foo", cdecl, header: "rl.h".}

# public user-facing wrapper
proc rl_foo*(x: int): int {.inline.} = rl_foo_c(x.cint).int
```

Constants follow the same rule: `RL_INIT_OK`, `RL_TICK_FAILED`, etc. must be the target language's native integer, not a C-cast literal.

## Architecture: Direct API

All bindings (Nim, Haxe, Lua, JS) call the C API directly. There is no frame command layer in librl — that is an application-level concern handled by individual examples (e.g., `examples/remote/`).

## JavaScript Binding

Files:

- `bindings/js/dist/rl.js`

Role:

- `lib/librl.js` + `lib/librl.wasm` are the raw Emscripten runtime artifacts.
- `bindings/js/dist/rl.js` is the standalone JS binding wrapper that imports `lib/librl.js` and exposes the higher-level `RL` object.
- Calls C exports via `ccall`.
- Initializes and reads the scratch area bridge for vectors/input state.
- Provides browser-oriented runtime setup helpers (`canvas`, module boot/init flow).
- Window/viewport resize and letterboxing are host/runner concerns (for example `examples/www/public/js/example_runner.js`); the JS binding does not install browser resize listeners or call `rl_window_set_size` during init.
- Exposes explicit scratch refresh on JS only (`refreshScratch()` in `bindings/js/dist/rl.js`, invoked automatically at the start of `tick()`). Haxe/Lua/Nim do not expose scratch-bridge entry points — desktop uses direct C struct returns; wasm Haxe/Nim use `tick()` which forwards to the JS binding.

Scratch design goals:

- Use explicit bridge naming at the C/wasm boundary:
  - `*_to_scratch`: C writes result data into shared scratch memory for JS to read.
  - `*_from_scratch`: C reads host-provided data from scratch memory (used where needed).
- Keep JS-facing APIs abstracted from scratch internals:
  - JS wrappers expose normal methods (`getWindowPosition()`, `measureTextEx()`, etc.).
  - Internally, wrappers may call a `*_to_scratch` bridge and then read via `bindings/js/dist/rl.js`.
- Reduce boundary overhead:
  - For vec/struct-like return values, one wasm call + one scratch read is preferred over many scalar calls.

Wasm-only scratch bridge table (maintainer reference; JS callers use the right-hand `RL.*` methods only):

| C export | Direction | JS public API | Scratch read |
|----------|-----------|---------------|--------------|
| `rl_scratch_refresh` | C → scratch (input snapshot) | `refreshScratch()`, also called at start of `tick()` | mouse, keyboard, gamepads, touchpoints |
| `rl_window_get_screen_size_to_scratch` | C → scratch | `getScreenSize()` | `vector2` |
| `rl_window_get_position_to_scratch` | C → scratch | `getWindowPosition()` | `vector2` |
| `rl_window_get_monitor_position_to_scratch` | C → scratch | `getMonitorPosition(monitor?)` | `vector2` |
| `rl_input_get_mouse_position_to_scratch` | C → scratch | `getMousePosition()` | `vector2` |
| `rl_text_measure_ex_to_scratch` | C → scratch | `measureTextEx(font, text, fontSize, spacing?)` | `vector2` (width/height) |
| `rl_pick_model_to_scratch` | C → scratch | `pickModel(camera, model, mouseX, mouseY)` | `vector3` (point), `vector4` (normal xyz + distance w) |
| `rl_pick_sprite3d_to_scratch` | C → scratch | `pickSprite3d(camera, sprite3d, mouseX, mouseY)` | `vector3` (point), `vector4` (normal xyz + distance w) |
| `rl_asset_ensure_many_from_scratch_async` | scratch → C | `RL.asset.ensureGroupAsync(filenames)` | JS writes string table via internal `writeScratchStringTable()` first |

Direct scratch reads (no `*_to_scratch` call; require `refreshScratch()` or `tick()` first so C has populated the snapshot):

| JS public API | Scratch region |
|---------------|----------------|
| `getMouseState()` | mouse (x, y, wheel, buttons) |
| `getKeyboardState()` | keyboard keys/queues |
| `getGamepads()` / `getGamepad(id)` | gamepad array |
| `getTouchpoints()` / `getTouchpoint(id)` | touchpoint array |

Notes:

- C symbols in the first table are wasm export/implementation details — do not call them from application JS; use the `RL.*` wrapper.
- `bindings/js/dist/rl.js` reads scratch through internal module helpers (`getVector2`, `getVector3`, `getVector4`, `getMouseState`, …) initialized at boot from `rl_scratch_get_base()` and `rl_scratch_get_offsets()`.
- Haxe/Lua/Nim intentionally omit `scratch_refresh` / `scratchRefresh` / `rl_scratch_refresh` on their public surfaces (commented in binding sources with rationale). Wasm Haxe/Nim callers rely on `tick()` → JS `refreshScratch()`. Layout and lifecycle details: `docs/API.md` § Scratch Area.

Used by:

- `examples/www/js_example.js`

Notes:

- This is the primary browser-facing API layer.
- It includes async-oriented wrappers for asset-backed calls like model/font creation.
- Input state uses `getMouseState()` (x/y/wheel/left/right/middle/buttons) and `getKeyboardState()`.
  - Gamepad and touch snapshots are exposed as `getGamepads()` / `getGamepad(id)` and `getTouchpoints()` / `getTouchpoint(id)` (scratch-backed; call `refreshScratch()` or `tick()` first).
  - button states use shared constants exposed on `rl`:
    - `rl.BUTTON_UP`
    - `rl.BUTTON_PRESSED`
    - `rl.BUTTON_DOWN`
    - `rl.BUTTON_RELEASED`
- Window close polling is exposed as `isWindowCloseRequested()`.
- Picking helpers available in JS:
  - `pickModel(...)`
  - `pickSprite3d(...)`
  - `resetPickStats()` on `rl` (C API)
  - aggregated pick telemetry on `rl.helpers.getPickStats()`
- JS `boot(opts)` instantiates the Emscripten module and prepares the scratch/color helpers without calling init.
  - Named palette handles live on `rl.color` (e.g. `rl.color.GREEN`, `rl.color.RAYWHITE`); `boot()` patches them from wasm exports.
  - Returns `BOOT_*` codes (not `INIT_*`): `BOOT_OK` (0), `BOOT_ERR_UNKNOWN` (-10), `BOOT_ERR_LOADER` (-11), `BOOT_ERR_VERSION_MISMATCH` (-12).
  - This is useful when callers need the loader-only/bootstrap path first, for example `boot() -> RL.fs.init() -> init()`.
  - `boot(...)` is the canonical place for module/browser options such as `canvasId`, `modulePath`, `wasmPath`, `idealWidth`, `idealHeight`, and optional callback hooks like `print`, `printErr`, and `locateFile`.
  - `modulePath` selects the raw Emscripten JS runtime module (`lib/librl.js` by default, resolved relative to `bindings/js/dist/rl.js`).
  - `init(...)` and `initAsync(...)` reuse the booted module instance when one already exists.
- **C init entry points:** `rl_init_values` / `rl_init_values_async` (scalar args; see `docs/API.md`). **`rl_init` / `rl_init_async` (struct pointer) and `rl_init_config_sizeof` are removed** — no struct-based init in the public C ABI.
- **Init contract (all bindings):** public API is config/table/object only — `init(config)` (run to completion; JS/wasm returns a Promise because init may suspend on fs/JSPI) and `initAsync(config)` (immediate return; poll `tick()` until `RL_TICK_RUNNING`). Bindings accept native config types and call `rl_init_values*` internally. Do not re-add positional `initValues*` wrappers on user-facing binding APIs.
- JS `init(opts)` and `initAsync(opts)` flatten opts and call `rl_init_values(...)` / `rl_init_values_async(...)` internally (`init` may suspend via JSPI during fs restore).
- Example: `await rl.init({ windowWidth: 800, windowHeight: 600, windowTitle: "Title", windowFlags: rl.FLAG_MSAA_4X_HINT, assetHost })`
- Init result constants are exposed (`INIT_OK`, `INIT_ERR_UNKNOWN`, `INIT_ERR_ALREADY_INITIALIZED`, `INIT_ERR_LOADER`, `INIT_ERR_ASSET_HOST`, `INIT_ERR_WINDOW`).
- In JS, polling-style `*Async` init/fs entrypoints keep the immediate-return contract:
  - `initAsync(...)` and `RL.fs.initAsync(...)` return plain integer status codes.
  - task-style asset APIs like `RL.fs.restoreAsync()` / `RL.asset.ensureAsync()` return task handles immediately.
- JS exposes `isInitialized()` for `rl_is_initialized()`.
- JS exposes `getPlatform()` for `rl_get_platform()`.
- Version queries (`rl_version_*` in `rl_version.h`) are exposed on all bindings:
  - JS version helpers: `getVersionMajor()`, `getVersionMinor()`, `getVersionPatch()`, `getVersionLabel()`, `getVersionNumber()`, `getVersionString()`
  - Nim: `rl_version_major()`, … (plus `RL_VERSION_*` constants)
  - Haxe: `RL.versionMajor()`, … (plus `RL.VERSION_*` constants)
  - Lua: `rl.version_major()`, …
- Binding/core alignment: `make binding-version` (runs with `desktop` / `shared` / `wasm` / `rl_lua`) writes `bindings/*/gen/*` from `include/rl_version.h`. Each binding queries `rl_version_*` from librl, compares to its stamp, logs both versions, and applies local policy (`validate_version()` / `validateVersion()` / `rl_validate_version()` return `0` ok, `1` patch drift, `< 0` fatal). Checks run at load/boot (not `init`): Lua on `require("rl")` and `rl.boot()`; JS after wasm load; Nim/Haxe on `rl_boot()` / `RL.boot()`.
- JS TypeScript declarations: `make binding-types` (runs with `desktop` / `shared` / `wasm`) esbuild-bundles `bindings/js/src/rl.ts` → `bindings/js/dist/rl.js` and emits `bindings/js/dist/rl.d.ts` from `bindings/js/src/types.ts` via `npm run build --prefix bindings/js`. Do not hand-edit generated outputs. After adding or renaming JS binding methods/constants, update `bindings/js/src/types.ts` when signatures change, then run `make binding-types` (or any of those build targets).
- **Binding tooling (maintainers/agents):** full table, platform policy, and workflow in `docs/MAINTAINER.md` § Tools.
  - `python3 tools/audit_binding_parity.py` — gap report vs `docs/API.md`; update `docs/ROADMAP.md` after binding work
  - `make binding-version` → `tools/gen_binding_versions.py`
  - `make binding-types` → `npm run build --prefix bindings/js` (esbuild bundle + `tsc` declarations from `bindings/js/src/types.ts`)
  - `python3 tools/gen_haxe_public_sections.py` — Haxe section façades
- JS `pickModel(camera, model, mouseX, mouseY)` and `pickSprite3d(camera, sprite3d, mouseX, mouseY)` return local-space `point` / `normal` data from `rl_pick_result_t`.
- JS fs/asset namespaces (mirror `rl_fs.h` / `rl_asset.h`):
  - `RL.fs.init([rootDir])`, `RL.fs.initAsync([rootDir])`, `RL.fs.deinit()`, `RL.fs.isReady()`, `RL.fs.getRootDir()`, `RL.fs.normalizePath(path)`, `RL.fs.restoreAsync()`, `RL.fs.read(filename)`, `RL.fs.remove(filename)`, `RL.fs.clear()`, …
  - `RL.asset.setHost(assetHost)` / `RL.asset.getHost()` — map to `rl_asset_set_host` / `rl_asset_get_host`
  - `RL.asset.ensure(localPath, src?)` → Promise/integer result for `rl_asset_ensure()`
    - JS warns when `localPath` ends in `.gltf`, because this synchronous/JSPI path does not currently follow `.gltf` dependencies.
  - `RL.asset.ensureAsync(localPath, src?)` → task handle for `rl_asset_ensure_async()`
  - `RL.asset.ensureGroupAsync(filenames)` → task handle via the scratch ABI and `rl_asset_ensure_many_from_scratch_async()`
  - `RL.asset.pingHost([assetHost])`, `RL.asset.pollTask(task)`, `RL.asset.finishTask(task)`, `RL.asset.addTask(...)`, `RL.asset.tick()`
- JS binding helpers (`RL.helpers.*`) — compositional sugar, not part of the C API:
  - `waitForFsReady(timeoutMs?)` — polls `RL.fs.isReady()` until restore completes (for `RL.fs.initAsync()` / boot-before-init flows)
  - `taskIsValid(task)`
  - `waitForTask(task, pollMs?)`, `waitForFsRestoreAsync()`, `waitForAssetEnsureAsync(localPath, src?)`, `waitForAssetEnsureGroupAsync(filenames)`
  - `createTaskGroup(onComplete?, onError?, ctx?)` with `addTask`, `addImportTask`, `addImportTasks`, `tick()`, `process()`, `remainingTasks()`, `failedPaths()`
  - `getScreenWidth()` / `getScreenHeight()` — convenience over `getScreenSize()`
  - `getPickStats()` — aggregates the four `rl_pick_get_*` telemetry calls
- Rule: symbols that map 1:1 to `include/*.h` (or documented scratch bridges for struct returns) live on `RL` or nested namespaces (`RL.fs`, `RL.asset`, …). Helpers that compose multiple C calls or add JS/async sugar live on `RL.helpers`.
- JS `RL.asset.addTask(task, onSuccess?, onFailure?, ctx?)` mirrors the Haxe/cpp callback contract by installing local JS springboard callbacks around `rl_asset_add_task(...)`.
- JS `create*` helpers now match the other bindings: they create resources from paths that are already available in librl's local filesystem/cache.
  - Call `RL.asset.ensure(...)`, `RL.helpers.waitForAssetEnsureAsync(...)`, `RL.helpers.createTaskGroup(...)`, or another asset flow first when the asset is not local yet.
  - This applies to `createFont`, `createModel`, `createMusic`, `createSound`, `createTexture`, `createSprite3d`, and `createSprite2d`.
- JS shape/debug/logger helpers:
  - `drawRectangle(x, y, width, height, color)` → `rl_shape_draw_rectangle`
  - `debugEnableFps(x, y, fontSize, [font])` / `debugDisable()` → `rl_debug_*` (`font` is an `rl_handle_t`, `0` for default)
  - `loggerMessage(level, message)` / `loggerMessageSource(level, sourceFile, sourceLine, message)` / `loggerSetLevel(level)`
  - Logger levels exposed as `LOGGER_LEVEL_*`; window flags as `FLAG_*` (including all `RL_WINDOW_FLAG_*` values)
- JS texture/sprite helpers:
  - `getDefaultTexture()` → `rl_texture_get_default`
  - `getSprite3dTransform(sprite)` → `rl_sprite3d_get_transform` (returns `{ positionX, positionY, positionZ, size }` or `null`)
  - `getDefaultFont()` → `rl_font_get_default`
  - `getDefaultCamera3d()` → `rl_camera3d_get_default`
  - Default handles use getters only (no binding-level `FONT_DEFAULT` / `CAMERA3D_DEFAULT` constants; C symbols remain for internal use)
- JS handle-instance methods use verb-first naming (`setText2dFont`, `setSprite3dTransform`, `setModelAnimation`, `animateModel`, …). Haxe public section classes use verb-first names (`Text2d.setFont`, `Sprite3d.setTransform`, …); the impl layer keeps C-aligned names (`RLImpl.text2dSetFont`, …). Nim/Lua keep section-first names aligned with C.
- JS task-returning asset helpers use the same naming convention as C: `_async` / `*Async` means the call starts work and returns a task handle. Default names such as `RL.asset.ensure(...)` follow the synchronous/default contract, even though JS callers still `await` them when JSPI is involved.

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
- Picking helpers available in Haxe: `Pick.model(camera, model, mouseX, mouseY)` and `Pick.sprite3d(camera, sprite3d, mouseX, mouseY)`, returning `RLPickResult` (`hit`, `distance`, `point: RLVec3`, `normal: RLVec3`). Transform is read from the stored instance. Stats helpers: `Pick.resetStats`, `Pick.getBroadphaseTests`, `Pick.getBroadphaseRejects`, `Pick.getNarrowphaseTests`, `Pick.getNarrowphaseHits`.
- **`point` and `normal` in `RLPickResult` / `rl_pick_result_t` are in local (object) space, not world space:**
  - For `pickModel`: world hit point inverse-transformed by the model's world matrix (position + rotation + scale). Origin is the model's local origin.
  - For `pickSprite3d`: `(local_x, local_y, 0)` on the billboard surface, with normal on local `+/-Z`. `local_x` and `local_y` are signed offsets from the sprite center in world units — e.g. `(-0.5, -0.5)` is bottom-left corner, `(+0.5, +0.5)` is top-right corner for a size-1 sprite.
- Window config flags are exposed in Nim:
  - `rl_window_init(width, height, title, flags)`
  - `RL_FLAG_MSAA_4X_HINT`
- Window close polling is exposed in Nim as `rl_window_close_requested()`.
- Nim exposes `rl_boot([config])`.
  - On JS, `rl_boot` dynamically imports `bindings/js/dist/rl.js`, boots the wrapper, and patches `rl.color.*` preset handles.
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
  - `bindingsPath` lets callers override the runtime path to `bindings/js/dist/rl.js`; if omitted, Haxe JS and Nim JS resolve it relative to `document.baseURI` (subpath-safe).
  - On Nim JS, `print` and `printErr` are forwarded into the wrapper `env` object. `locateFile` is currently accepted for API parity but ignored with a warning.
  - On native targets, `rl_boot` loads nothing (static link) but still runs the binding/core version check, then returns `RL_INIT_OK`.
- Fs/asset helpers in Nim (all return native `int` or `bool`):
  - `rl_fs_init([base_dir])` → `int`
  - `rl_fs_init_async([base_dir])` → `int`
  - `rl_fs_deinit()`
  - `rl_fs_is_initialized()` → `bool`
  - `rl_asset_set_host(assetHost)` / `rl_asset_get_host()`
  - `assetPingHost(assetHost?)` → `float` RTT ms, or `< 0` on failure
  - `rl_fs_restore_async()` → `RLHandle`
  - `rl_asset_ensure_async(localPath, src?)` → `RLHandle`
  - `rl_asset_ensure(localPath, src?)` → `int` (`0` success)
  - `rl_asset_ensure_many_async(filenames, count)` → `RLHandle`
  - `rl_asset_poll_task(task)` → `bool`
  - `rl_asset_finish_task(task)` → `int`
  - `rl_asset_free_task(task)`
  - `rl_fs_exists(filename)` → `bool`
  - `rl_fs_remove(filename)` → `int`
  - `rl_fs_clear()` → `int`
- Init result constants are exposed as `RL_INIT_OK` / `RL_INIT_ERR_*` (plain `int`).
- Nim also exposes `rl_init_async(config)` (polling init; immediate return).

Binding-level async asset ergonomics:

- `RLTaskGroup[T]` is available in Nim via `bindings/nim/rl.nim`:
  - `assetCreateTaskGroup[T](ctx, onComplete?, onError?)`
  - `addTask`, `addImportTask`, `addImportTasks`
  - `tick()`, `process()`, `remainingTasks()`, `failedPaths()`
- The Nim example (`examples/nim-simple/src/main.nim`) is the canonical pattern:
  - `rl_run(onInit, onTick, onShutdown, addr ctx)` drives the main loop.
  - `if not ctx.loadingGroup.isNil and ctx.loadingGroup.process() > 0: return` gates frame work until imports finish.

## Haxe Binding

Files:

- `bindings/haxe/rl/RL.hx` — core lifecycle only: `boot`, `init`, `deinit`, `tick`, version, timing, shared init/tick constants.
- `bindings/haxe/rl/{Fs,Asset,Window,Render,Model,...}.hx` — one public class per C API section in `package rl` (e.g. `rl.Fs.init()`, `rl.Asset.ensure()`). Method names are verb-first within each class; the impl layer keeps C-aligned names (`RLImpl.fsInit`, …).
- `bindings/haxe/rl/helpers/*.hx` — binding ergonomics (not C API), e.g. `rl.helpers.TaskGroup.create()`, `rl.helpers.Log.info()`, `rl.helpers.Wait.waitForTask()`. JS equivalent bucket: `RL.helpers.*` (where applicable).
- `tools/gen_haxe_public_sections.py` — regenerates section façade files from the `SECTIONS` map (see MAINTAINER § Binding tooling).
- `bindings/haxe/rl/impl/RLImpl.cpp.hx` — current hxcpp backend implementation. Contains all `@:native`, `untyped __cpp__`, `@:functionCode`, and bridge classes.
- `bindings/haxe/rl/impl/RLImpl.js.hx` — Haxe `js` backend. It is a thin adapter over the standalone JS binding exported from `bindings/js/dist/rl.js`.
- `bindings/haxe/rl/impl/RLImpl.hx` — unsupported fallback that fails compilation for targets without a backend.
- `bindings/haxe/rl/Types.hx` — shared binding types (`RLHandle`, `RLVec2`, config structs, input state, …).
- `bindings/haxe/rl/impl/RLFileioImpl.cpp.hx` — current hxcpp-only fs/asset impl (`RLFileio` internal class).
- `bindings/haxe/rl/helpers/TaskGroup.hx` — binding helper (not C API); uses `Asset.*` for task polling.
- `bindings/haxe/rl/InjectLibRL.hx`
- `examples/haxe-simple/src/Main.hx`

Role:

- Exposes `librl` APIs to Haxe via hxcpp externs (C++ FFI).
- Section façade classes (`rl.Fs`, `rl.Asset`, …) and `RL.hx` are script-facing/public API modules and must remain free of `cpp.*`, `@:native`, and `untyped __cpp__`.
- `RLImpl.cpp.hx` currently holds the hxcpp-specific backend and is compiled into the host binary with `-D scriptable`.
- Uses `@:buildXml`, `@:functionCode` in `RLImpl.cpp.hx` to:
  - Include `rl.h` / `rl_fs.h` / `rl_asset.h`.
  - Inject link flags (`librl.a` / `librl.wasm.a`).
  - Bridge Haxe loader callbacks to `rl_asset_add_task`.

### Haxe Architecture Notes

Current state:

- `RL.hx` owns core lifecycle and shared constants only.
- Subsystem APIs live in sibling classes under `package rl` (`Fs`, `Asset`, `Window`, `Render`, `Model`, …).
- Each section class delegates into `rl.impl.RLImpl`, which resolves by target:
  - `RLImpl.cpp.hx` on `cpp`
  - `RLImpl.js.hx` on `js`
  - `RLImpl.hx` for unsupported targets, which fails at compile time
- `RL.boot(?config)` is the backend bootstrap hook:
  - Returns `RL.BOOT_*` codes (not `RL.INIT_*`): `BOOT_OK` (0), `BOOT_ERR_UNKNOWN` (-10), `BOOT_ERR_LOADER` (-11, wasm/module/JSPI load failure), `BOOT_ERR_VERSION_MISMATCH` (-12).
  - On hxcpp/cppia it returns `Int`, runs the binding/core version check, and succeeds immediately when load is not required.
  - On Haxe JS it returns `js.lib.Promise<Int>` so the JS backend can import `bindings/js/dist/rl.js`, which then instantiates `lib/librl.js` / `lib/librl.wasm` before normal `RL.init(...)` calls.
  - The current Haxe JS backend expects the generated raw `lib/librl.js` JSPI build plus the standalone wrapper in `bindings/js/dist/rl.js`. If `WebAssembly.Suspending` / `WebAssembly.promising` are unavailable, `RL.boot()` returns an error code and leaves the backend unbooted.
  - Haxe JS uses a typed `RLBootConfig` surface with flattened fields like `bindingsPath`, `canvasId`, `modulePath`, `wasmPath`, `idealWidth`, `idealHeight`, `print`, `printErr`, and `locateFile`.
- Haxe JS returns Promises for blocking JSPI-backed calls:
  - `RL.init(...)`, `RL.initAsync(...)`, `RL.deinit()`
  - `Fs.init(...)`, `Fs.deinit()`, `Asset.ensure(...)`
  - The `*Async` task-starting APIs keep their C semantics: they return immediate status/task handles and are polled/finished through the asset task API.
- The Haxe JS backend now reuses `bindings/js/*` exclusively. `RLImpl.js.hx` no longer calls the wasm exports directly; all browser-side behavior flows through the JS binding layer.
- On Haxe JS, scratch refresh is internal to `RL.tick()` (forwards to `bindings/js/dist/rl.js` `refreshScratch()`). `RL.scratchRefresh()` is intentionally not on the Haxe public surface.
- `RLImpl.cpp.hx` keeps the raw C extern table private as `RLExterns`; authored code never imports it directly.
- There is no generic runtime fallback. New targets must add an explicit backend such as `RLImpl.lua.hx`.
- `examples/haxe-js-simple` is the current compile/run smoke test for the Haxe `js` backend. It exercises `RL.boot()` and fs init/deinit; in runtimes without JSPI support, boot returns an error code without instantiating wasm.

Target-neutral direction:

- `rl.RL` remains the entry point for lifecycle/version/timing.
- Subsystem calls use `rl.Fs`, `rl.Asset`, `rl.Window`, etc. Authored code should not import `rl.impl.*`.
- `rl.RL` and section classes forward into a backend module; they should not collapse into `typedef` aliases of hxcpp implementation types.
- Target-specific implementation should live under backend files selected by target, for example:
  - `bindings/haxe/rl/impl/RLImpl.cpp.hx`
  - `bindings/haxe/rl/impl/RLImpl.js.hx`
  - `bindings/haxe/rl/impl/RLImpl.lua.hx`
- The same pattern should be applied to fs/asset internals:
  - `bindings/haxe/rl/impl/RLFileioImpl.cpp.hx`
  - `bindings/haxe/rl/impl/RLFileioImpl.lua.hx`

Design rules for that split:

- `RL.hx` and section façade classes stay target-neutral:
  - no `cpp.*`
  - no `@:native`
  - no `untyped __cpp__`
- `RLImpl.*.hx` owns target-specific plumbing.
- The backend contract is structural: each `RLImpl.<target>.hx` must provide the static members called by section classes and `RL.hx`.
- Do not use `RLImpl.hx` as an implementation shim; it exists only to fail clearly for unsupported targets.
- Authored/gameplay code should import `rl.RL` plus the section classes it needs, not `rl.impl.*`.
- Public handle types exposed from `rl.*` should be stable across targets; backend-specific representations such as `cpp.UInt64` should stay internal to the backend layer.

Practical implication:

- If Haxe-to-Lua support is added, the Lua backend should expose the same public `rl.RL` API through `RLImpl.lua.hx`, rather than reusing hxcpp-generated implementation names.

Used by:

- `examples/haxe-simple/src/Main.hx`

Notes:

- Public Haxe API mirrors C sections, with verb-first methods inside each class:
  - `Model.create`, `Sprite3d.create`, `Camera3d.create`, `Fs.init`, `Asset.ensure`, etc.
  - Section constants: `Window.FLAG_MSAA_4X_HINT`, `Camera3d.PERSPECTIVE`, `Logger.LEVEL_INFO`, `Asset.ADD_TASK_OK`, `Input.BUTTON_UP`, …
  - Core constants on `RL`: `RL.INIT_OK`, `RL.TICK_RUNNING`, …
  - Boot result constants on `RL` (binding-only; distinct from init): `RL.BOOT_OK`, `RL.BOOT_ERR_UNKNOWN`, `RL.BOOT_ERR_LOADER`, `RL.BOOT_ERR_VERSION_MISMATCH`. Compare `RL.boot()` against these, not `RL.INIT_*`.
  - `Input.getGamepads()` / `Input.getTouchpoints()` mirror JS scratch-backed snapshots on wasm; desktop returns empty/null.
  - Picking: `Pick.model(...)`, `Pick.sprite3d(...)`, returning `RLPickResult`.
  - `RL.isInitialized()` wraps `rl_is_initialized()`.
  - `RL.getPlatform()` wraps `rl_get_platform()`.
  - `Window.closeRequested()` wraps `rl_window_close_requested()`.
- WASM builds use hxcpp's emscripten toolchain with `MODULARIZE=1` and `EXPORT_ES6=1`:
  - `examples/haxe-simple/build.wasm.hxml`
  - `examples/haxe-simple/build.hxml` dispatches between the desktop and wasm build configs.
  - `InjectLibRL.hx` adds the emcc linker flags and links against `librl.wasm.a`.
- Example-specific wasm exports live in example-local `@:buildXml` classes:
  - `examples/haxe-simple/src/InjectWasmExports.hx`
  - Keep app/runtime export lists out of `bindings/haxe/rl/InjectLibRL.hx`; it should stay focused on librl link/config flags.
- `examples/haxe-simple` is the canonical Haxe example and the canonical host/runtime ABI example for Haxe in this repo.

Async fs/asset sugar:

- The binding exposes both init contracts:
  - `RL.init(...)` / `RL.initAsync(...)`
  - `Fs.init([rootDir])` / `Fs.initAsync([rootDir])`
  - `Fs.isInitialized(): Bool`
- Asset helpers:
  - `Asset.setHost(assetHost: String): Int` / `Asset.getHost(): String`
  - `Asset.pingHost(assetHost?): Float` → RTT ms, or `< 0` on failure
  - `Asset.ensureAsync(localPath: String, ?src: String): RLHandle`
  - `RLFileio.assetAddTask(task, onSuccess, onFailure, userData)` with the callback path derived from `RLFileio.assetGetTaskPath(task)` (internal cpp class)
  - `Asset.pollTask(task: RLHandle): Bool`
  - `Asset.finishTask(task: RLHandle): Int`
  - `TaskGroup.create<T>(onComplete?, onError?, ctx?)` (`rl.helpers.TaskGroup`)
  - `Wait.waitForTask(task)`, `Wait.waitForFsReady()`, `Wait.waitForAssetEnsureAsync(...)` (`rl.helpers.Wait`; JS `RL.helpers.*` equivalents)
  - `TaskGroup.addImportTask(path, onSuccess?, onError?)`
  - `TaskGroup.process()`, `TaskGroup.remainingTasks()`, `TaskGroup.failedPaths()`
  - `Asset.addTask(task, onSuccess, onFailure, ctx)`
- `rl_asset_add_task` is wrapped so Haxe asset callbacks use plain `(path, ctx)` handlers:
  - `RL.assetAddTask(task, onAssetReady, onAssetFailed, ctx)`
- `RL.assetAddTask(...)` consumes the task handle when queueing succeeds; use task groups or callbacks rather than polling the same handle after queueing it.
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
- **`rl.asset_create_task_group`** is implemented in C (`rl_lua_task_group.c`), same role as:
  - Haxe: `TaskGroup.create` → `rl.helpers.TaskGroup` (`bindings/haxe/rl/helpers/TaskGroup.hx`); JS equivalent: `RL.helpers.createTaskGroup()`
  - Nim: `assetCreateTaskGroup` / `RLTaskGroup` in `rl.nim`

Notes:

- The returned userdata exposes `add_task`, `add_import_task`, `add_import_tasks`, `tick`, `process`, `failed_paths`, etc.
- Lua module constants drop the C `RL_` prefix on the `rl` table (e.g. `rl.INIT_OK`, `rl.COLOR_GREEN`, `rl.BUTTON_UP`, `rl.WINDOW_FLAG_MSAA_4X_HINT`). Boot codes use the binding-only `rl.BOOT_*` names (same values as JS/Haxe).
- Lua exposes mouse button state constants (`rl.BUTTON_UP`, `rl.BUTTON_PRESSED`, `rl.BUTTON_DOWN`, `rl.BUTTON_RELEASED`).
- Lua exposes `rl.font_get_default()`, `rl.camera3d_get_default()`, and `rl.texture_get_default()` (no default handle constants on the module table).
- Lua exposes `rl.init({...})` and `rl.init_async({...})` with a config table (same init contract as other bindings; no `init_values` / `init_values_async`).
- Lua exposes `rl.boot()`, a lifecycle stub on native/desktop (version check runs at `require("rl")`; fatal mismatch throws). Returns `rl.BOOT_OK`. Compare boot against `rl.BOOT_*`, init against `rl.INIT_*`. Use `boot() -> fs_init() -> init()` when mirroring JS/Haxe lifecycle.
- Boot result constants (binding-only; same values as JS/Haxe): `rl.BOOT_OK`, `rl.BOOT_ERR_UNKNOWN`, `rl.BOOT_ERR_LOADER`, `rl.BOOT_ERR_VERSION_MISMATCH`.
- Lua exposes `rl.asset_set_host(asset_host)` and `rl.asset_get_host()`.
- Lua exposes `rl.asset_ping_host([asset_host])`, returning RTT ms or `< 0` on failure, for proactive asset-host diagnostics before importing.
- Lua exposes `rl.fs_init([root_dir])` and `rl.fs_deinit()` for fs-only bootstrap without full `rl.init()`.
- Lua also exposes `rl.fs_init_async([root_dir])` and `rl.init_async([config])` for the polling-style fallback path.
- Lua exposes `rl.fs_is_ready()` for `rl_fs_is_ready()`.
- Lua exposes `rl.fs_is_initialized()` for `rl_fs_is_initialized()`.
- Lua exposes `rl.asset_ensure_async(local_path, src?)` for `rl_asset_ensure_async()`.
- Lua exposes `rl.asset_ensure(local_path, src?)` → integer return code (`0` success); on wasm this follows the same constraints as the C API (see `rl_asset_ensure` in `rl_asset.h`).
- Lua `rl.asset_add_task(task, on_success?, on_failure?, ctx?)` derives the callback path from `rl_asset_get_task_path(task)`. Asset callbacks receive `(path, ctx)`.
- Lua exposes asset queue result constants (`rl.ASSET_ADD_TASK_OK`, `rl.ASSET_ADD_TASK_ERR_INVALID`, `rl.ASSET_ADD_TASK_ERR_QUEUE_FULL`).
- Lua exposes init result constants (`rl.INIT_OK`, `rl.INIT_ERR_UNKNOWN`, `rl.INIT_ERR_ALREADY_INITIALIZED`, `rl.INIT_ERR_LOADER`, `rl.INIT_ERR_ASSET_HOST`, `rl.INIT_ERR_WINDOW`).
- Lua exposes tick result constants (`rl.TICK_RUNNING`, `rl.TICK_WAITING`, `rl.TICK_FAILED`).
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
  - Haxe: verb-first methods on section classes (`Fs.init`, `Asset.ensure`, `Text2d.setFont`, …); impl layer is C-aligned.
    - examples: `frameBufferSubmit`, `windowGetScreenSize`
  - JavaScript (`bindings/js/dist/rl.js`): nested namespaces per C header (`RL.fs`, `RL.asset`, …); verb-first for handle-instance methods (`setText2dFont`, `createSprite3d`, `getDefaultTexture`).
- Avoid inventing alternate verb ordering in Haxe/Lua/Nim if the C API is clear.
  - prefer section-first semantics equivalent to `rl_<section>_<action>` on those bindings.

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
