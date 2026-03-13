# Bindings

This project currently maintains two primary bindings in a 'add as I need' cycle:

- JavaScript (wasm runtime wrapper)
- Nim (C FFI imports)

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

- `examples/js/simple_example.js`

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
- JS `initWindow(width, height, title, flags)` maps directly to C flags.
  - Example: `rl.initWindow(800, 600, "Title", rl.FLAG_MSAA_4X_HINT)`
- Loader/cache helpers currently exposed in JS:
  - `uncacheFile(filename)`
  - `clearCache()`
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
  - `rl_loader_begin_restore()`
  - `rl_loader_begin_prepare_file(filename)`
  - `rl_loader_begin_prepare_model(filename)`
  - `rl_loader_begin_prepare_paths(filenames, count)`
  - `rl_loader_poll_op(op)`
  - `rl_loader_finish_op(op)`
  - `rl_loader_free_op(op)`
  - `rl_loader_is_local(filename)`
  - `rl_loader_uncache_file(filename)`
  - `rl_loader_clear_cache()`

## Status and Scope

- Active: JavaScript, Nim
- Not treated as a primary binding surface: generated/auxiliary artifacts

## Sync Guidance (Mostly for myself)
When public C headers change:

1. Update `include/*.h`.
2. Update binding layers (`bindings/js/*`, `bindings/nim/rl.nim`) that expose affected functions.
3. Smoke test:
   - web: `examples/js/simple_example.js`
   - desktop Nim: `examples/nim/src/main.nim`
