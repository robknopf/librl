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

Used by:

- `examples/web/index.js`

Notes:

- This is the primary browser-facing API layer.
- It includes async-oriented wrappers for asset-backed calls like model/font creation.
- Input state uses `getMouseState()` (x/y/wheel/buttons) and `getKeyboard()`.
- IDBFS readiness helpers:
  - `RL.isIdbfsReady()` returns true only after wasm-side restore from IndexedDB completes.
  - `RL.waitForIdbfsReady(timeoutMs)` polls readiness and resolves to a boolean.
  - During `RL.deinit()`, wasm marks readiness false immediately before triggering a best-effort async flush to IndexedDB.

## Nim Binding

File:

- `bindings/nim/rl.nim`

Role:

- Exposes `librl` APIs through Nim `importc` declarations.
- Uses `rl.h` for core APIs and subsystem headers (`rl_model.h`, `rl_font.h`) where needed.
- Maps handle-based APIs to Nim (`RLHandle = uint32`).

Used by:

- `examples/desktop/nim/src/main.nim`

Notes:

- This binding is direct/low-level and close to the C surface.
- Keep declarations synchronized with header changes in `include/`.
- It now includes a small `RLMouse` record helper via `rl_get_mouse_state()`.

## Status and Scope

- Active: JavaScript, Nim
- Not treated as a primary binding surface: generated/auxiliary JS artifacts used for Haxe interop in this repo

## Sync Guidance (Mostly for myself)
When public C headers change:

1. Update `include/*.h`.
2. Update binding layers (`bindings/js/*`, `bindings/nim/rl.nim`) that expose affected functions.
3. Smoke test:
   - web: `examples/web/index.js`
   - desktop Nim: `examples/desktop/nim/src/main.nim`
