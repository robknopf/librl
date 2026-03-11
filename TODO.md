# TODO

## Active Next

- Handle system cleanup:
  - finish migrating remaining legacy handle paths to `rl_handle_pool`
  - likely remaining holdouts:
    - model asset IDs / asset-instance split (`src/rl_model.c`)
  - validate stale-handle behavior consistently across destroy/set/get APIs
- Lua runtime follow-up:
  - add a general Lua-facing event API:
    - `event_on`
    - `event_off`
    - `event_emit`
  - decide whether host fallback clear stays in `examples/c/main.c` or Lua fully owns frame clear
  - decide whether window bootstrap should grow beyond `get_config()`:
    - min/max size
    - vsync hint
    - other window policy flags/settings
  - document the Lua standard-library layer more directly for script authors:
    - `color.lua`
    - `model.lua`
    - `texture.lua`
    - `sprite3d.lua`
    - `sound.lua`
    - `music.lua`
    - `camera3d.lua`
    - `font.lua`
- Frame command path hardening:
  - current typed command path exists through `rl_module_frame_command_t` and the C example host buffer
  - next step is to expand and harden it rather than redesign it from scratch
  - decide whether to keep the current host-owned fixed-capacity buffer shape or promote a more general transient command queue/ring buffer
  - grow the command set carefully as needed:
    - clear background
    - camera control / active camera intent
    - draw text
    - draw model
    - draw sprite/texture
    - play sound
    - music control if it belongs in the transient command path
  - clarify command ownership and overflow behavior
  - document the current host/script contract around command emission and drain order
- Hot reload lifecycle:
  - current lifecycle is `get_config/init/load/update/unload/shutdown`
  - current HCR state transfer hooks are `serialize/unserialize`
  - define what survives reload vs what is reconstructed
  - make error/reporting behavior predictable during reload
- External ID mapping layer:
  - add optional `external_id -> internal_handle` mapping
  - allow caller-supplied IDs while preserving internal handle safety
  - define replace/update behavior when an external ID is reused
- Event system follow-up:
  - add an explicit queue (`enqueue`) alongside immediate emit semantics
  - add queue processing/drain API
  - decide where queued events are drained:
    - core update loop
    - module update phase
    - caller-owned explicit drain point
  - if Lua gets a general event API, decide whether script listeners bind to immediate events, queued events, or both
- Wasm + scripting direction:
  - decide whether wasm Lua should be:
    - embedded Lua VM
    - JS-side Lua bridge
    - something else entirely
  - keep the thin-host boundary stable enough that this can be swapped without redesigning the runtime
- API/docs sync:
  - keep examples current as APIs change
  - add a short wasm-only bridge table for scratch helpers (`*_to_scratch` and JS wrapper names)
  - keep `README.md`, `docs/API.md`, `docs/BINDINGS.md`, and `docs/DEV_NOTES.md` aligned when the Lua/module surface changes

## In Progress Conceptually

- Thin host + scripted gameplay is now the active direction:
  - host owns bootstrap, window/frame boundaries, and resource execution
  - script owns gameplay state and emits transient frame commands
  - current reference implementation is the Lua module plus `examples/c/main.c`
- Frame command transport is no longer hypothetical:
  - typed command ABI exists in `include/rl_module.h`
  - Lua emits commands through the module host API
  - the C example drains those commands in clear / audio / 3D / 2D passes
- Lua-side wrapper modules exist and are the beginning of a script-facing standard library.

## Research / Evaluation

- Scripting backend evaluation:
  - keep Lua as the reference implementation for module-hosted scripting
  - compare TinyCC, daslang, and Haxe/cppia against the same module boundary
  - evaluate:
    - hot reload / edit-compile latency
    - host API friction
    - debugging quality
    - wasm feasibility
    - native production story without a permanent interpreter
    - ergonomics for handle-based host calls
  - Haxe/cppia-specific question:
    - does it provide a strong "same source in dev + native production later" path without unacceptable C++/toolchain friction?
- Event payload bridge for JS:
  - add scratch-area read/write helpers for event payloads so JS can exchange structured payload data with C listeners
  - define a stable payload layout/versioning strategy for JS/Nim/C safety
  - re-evaluate the long-term role of JS bindings if in-wasm scripting becomes the primary gameplay path
- Module SDK split:
  - define a separate module SDK package/repo for out-of-tree module builds
  - include stable `rl_module.h` ABI and documented versioning/compatibility policy
  - define how wgutils is provided in the SDK for module portability
  - keep module development in-tree until the SDK contract is stable
- URI/path follow-up:
  - add URL normalization examples to docs
  - decide whether cache keys should canonicalize host casing
- Asset versioning + manifest:
  - add per-asset version metadata so cached files can be upgraded/replaced safely
  - define a manifest format listing assets, versions, hashes, and URLs
  - compare manifest vs local cache on startup/load and invalidate stale entries

## Parking Lot

### API Consistency

- Re-evaluate model animation GPU prep path:
  - confirm warning behavior is once-per-instance
  - document/validate missing-normal-VBO fallback behavior
- Consider caching animation GPU-state readiness per model instance to avoid per-frame mesh scans.
- Picking follow-up:
  - broad-phase checks before narrow-phase ray tests: done
  - add a scene-level "what's under the mouse" API that returns closest hit target + hit data
  - determine ownership of scene graph/state (host app vs librl) for scene-level picking and related queries

### Build / Tooling

- Consider formatting/lint guidance for C, JS, and Nim.

### Product Roadmap

- Proper test suites:
  - unit tests for core subsystems
  - integration tests for desktop and wasm flows
  - regression tests for model loading/animation edge cases
- Flush out API for bindings:
  - formalize a stable binding-oriented API surface
  - ensure JS/Nim wrappers map cleanly to all intended features
  - re-evaluate the role of JS bindings after scripting-backend experiments:
    - keep current broad gameplay-facing bindings
    - or narrow them into system/bootstrap/tooling APIs around the wasm host
- Audio polish:
  - evaluate seek/time query APIs for music streams
  - consider fade in/out helpers and optional grouped volume controls
  - validate browser decode/runtime behavior across larger audio assets
- Input I/O hooks/callbacks:
  - mouse callbacks/events
  - keyboard callbacks/events
- Evaluate collision/physics support scope and architecture.
- Evaluate NavMesh support (Recast/Detour integration path).
- Evaluate tilemap support (e.g. Tiled pipeline and runtime representation).

## Done

- IDBFS lifecycle hardening:
  - single sync path
  - overlap guard
  - documented ready-state timing
- FileIO logging cleanup:
  - standardized FileIO message style and capitalization
  - switched FileIO logging calls to shared `logger/log` API
  - moved logger implementation from `src/vendor/logger` to `src/logger`
- Audio support baseline:
  - added `rl_music` (streaming BGM) and `rl_sound` (SFX) subsystems
  - wired lifecycle into `rl_init()` / `rl_deinit()`
  - exported APIs in C + JS + Nim bindings and documented in `docs/API.md`
  - C example includes BGM + click SFX playback
- Developer handoff docs:
  - `docs/DEV_NOTES.md` exists and is useful for session restart
- Build/test smoke target:
  - `make test` runs desktop + wasm unit tests, plus desktop `uri_test` and wasm artifact checks
- C example wasm target naming cleanup:
  - `wasm-debug-smap` merged into `wasm-debug`
- Picking broad-phase optimization:
  - model world-AABB early reject
  - sprite billboard-sphere early reject
