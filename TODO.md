# TODO

## Active Next

- Remote client / networking:
  - Add desktop websocket support (currently a stub; evaluate libwebsockets or upgraded libcurl 7.86+)
  - Add client→server communication for input states
  - Move to binary protocol (swappable serialization layer?)
- HEADLESS follow-up:
  - leverage `HEADLESS` beyond tests for Node/Bun/server-oriented builds
  - define what runtime pieces no-op or return defaults in headless mode:
    - input
    - windowing
    - frame pacing
    - audio
  - add a minimal runnable headless host path so wasm logic can execute outside the browser
  - use that path to improve automated runtime verification beyond compile-only checks
- API/docs sync:
  - keep examples current as APIs change
  - add a short wasm-only bridge table for scratch helpers (`*_to_scratch` and JS wrapper names)
  - keep `README.md`, `docs/API.md`, `docs/BINDINGS.md`, and `docs/DEV_NOTES.md` aligned when the Lua/module surface changes
- Naming convention cleanup:
  - Rename `async/wg_*` to drop the `wg_` prefix (align with `websocket_`, `fetch_url_`)
- Audit bindings to ensure they haven't gotten stale (JS + Nim)
- Frame command path hardening:
  - current typed command path exists through `rl_render_command_t` and the C example host buffer
  - **v2 encoding proposal**: Lua table batch submission for reduced crossing overhead
    - Format: `[VERSION, FLAGS, count_sprite2d_xform, (data...), count_sprite2d_draw, (data...), ...]`
    - Fixed section order by convention (compile-time schema)
    - Zero-length sections skip data entirely (1 count value cost)
    - Single Lua→C crossing per frame regardless of element count
    - Debug mode (FLAGS bit): each section prefixed with `[type_tag, count, ...]` for verification
    - Inner loops are tight and cache-friendly (no per-element dispatch)
    - **Lua buffer pattern**:
      - Pre-allocate: `local buf = {}`
      - Per-frame reset: `local idx = 1`
      - Pack: `buf[idx] = handle; idx = idx + 1; buf[idx] = x; idx = idx + 1; ...`
      - Submit: `rl.submit_frame(buf)` — C reads sequentially, no re-entry
      - Reuse: Table grows once, Lua GC never touched per frame
  - next step is to expand and harden it rather than redesign it from scratch
  - decide whether to keep the current host-owned fixed-capacity buffer shape or promote a more general transient command queue/ring buffer
  - grow the command set carefully as needed:
    - ~~clear background~~ ✓
    - ~~camera control / active camera intent~~ ✓
    - ~~draw text~~ ✓
    - ~~draw model~~ ✓ (split transform/draw)
    - ~~draw sprite3d~~ ✓ (split transform/draw)
    - ~~draw sprite2d~~ ✓ (split transform/draw)
    - ~~draw texture~~ ✓
    - ~~play sound~~ ✓
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
  - if Lua gets a general event API later, decide whether script listeners bind to immediate events, queued events, or both
- Loader / FS bootstrap:
  - evaluate adding a higher-level init helper that triggers a default filesystem restore and lets `rl_run` gate `init` on `rl_loader_is_ready`
  - keep low-level restore/import APIs available for advanced callers
  - WASM `fetch_url_head()`: requires async state machine refactor to support HEAD-then-GET pattern for download progress tracking (Content-Length from HEAD response)

## In Progress Conceptually

- Thin host + externally-driven gameplay is now the active direction:
  - host owns bootstrap, window/frame boundaries, networking, and resource execution
  - a remote server is now the most promising gameplay driver for wasm/runtime iteration
  - current reference implementation is `examples/remote`
  - current remote example still reaches into `wgutils` directly (`json/json.h`, `websocket/websocket.h`)
  - once the remote client shape is settled, move the transport/protocol pieces into `rl` proper so examples can consume librl without knowing about that dependency layer
- Frame command transport is no longer hypothetical:
  - typed command ABI exists in `include/rl_module.h`
  - remote/server code now emits commands over the websocket protocol
  - the host drains those commands in clear / audio / 3D / 2D passes

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

## Parked For Now

- Lua binding architecture:
  - Keep Lua bindings as .c files for maximum build flexibility (static, shared, WASM)
  - Location: `bindings/lua/liblua_rl.c` (following `lib<target>.c` convention)
  - Enables future `librl.so` (desktop shared) or `librl.wasm` with embedded Lua support
  - Desktop LuaJIT path: FFI bindings loading `librl.so` directly (bypass C bindings entirely)
  - PUC Lua path: Standard `luaopen_rl` C binding as now
  - Batch frame submission: Lua table → single C crossing → direct `rl_*` calls (v2 encoding)
  - Wrapper: `rl.lua` detects LuaJIT → FFI bindings, else → C bindings
- Lua module frame command wiring:
  - ~~all `draw_*` bindings now emit frame commands~~ ✓
  - `draw_model`, `draw_sprite3d`, `draw_sprite2d` use split transform/draw pattern
  - `draw_texture`, `draw_text`, `clear`, `play_sound` emit commands
  - verify `lua_vm_install_searcher` handles wasm async correctly (blocking fetch before `luaL_loadfile`), same pattern as hellolua/core `lua_register_fetch_loader`
- Scripting backend module design (beyond Lua):
  - the module boundary (`rl_module_api_t` — `init/update/shutdown/serialize/unserialize`) is language-agnostic
  - candidate backends to evaluate against the same boundary:
    - **hxcpp + cppia**: typed Haxe in dev (cppia fast reload), compiled native in prod — zero interpreter tax at ship time
    - **TinyCC**: C scripts compiled at runtime, near-native speed, no GC, wasm feasibility unclear
    - **daslang**: statically typed scripting, designed for games, compiles to native or interpreted
  - each backend emits frame commands into the same `rl_frame_command_buffer_t`
  - key evaluation axes: hot reload latency, wasm feasibility, typed authoring, prod story (interpreter-free or not)
  - hxcpp/cppia is the strongest candidate if Haxe is the primary game logic language
- Lua bootstrap/import cleanup after Asyncify removal:
  - current startup path works, but it is still an adapter layer made of:
    - host-driven script preload
    - `boot.lua`
    - local-only `require(...)`
    - event-driven `script.import`
    - coroutine resume via `import_pump()`
  - current state is useful as a stopgap, not a final scripting model
  - likely simplification path:
    - host localizes a single well-known Lua manifest/boot file up front
    - that file returns the preload/boot graph
    - host localizes the declared scripts before running lifecycle
    - keep runtime async import as a separate feature, not the startup path
  - delete complexity once that decision is made:
    - `boot.lua` deferred lifecycle queue
    - bootstrap coroutine glue
    - startup-time `script.import` reliance
  - re-evaluate whether startup should be:
    - `boot.lua`
    - `manifest.lua`
    - or some other well-known host-owned entry file
  - document the current interim rule clearly:
    - `require(...)` is synchronous and local-only
    - `import(...)` is async underneath
    - coroutine import is available, but only inside managed coroutine flows
  - HCR warning:
    - do not build hot code reload on top of the current bootstrap shim
    - simplify boot/import ownership first, or HCR will be a mess
- Lua runtime follow-up:
  - track Lua event listener ownership by script/generation so reload cleanup can be selective
  - decide whether host fallback clear stays in `examples/c-lua/main.c` or Lua fully owns frame clear
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
- Wasm + embedded scripting direction:
  - decide later whether wasm Lua should be:
    - embedded Lua VM
    - JS-side Lua bridge
    - something else entirely
  - keep the thin-host boundary stable enough that this can be swapped without redesigning the runtime

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
  - create tests for module/lua
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

- Sprite2D module:
  - C implementation with handle pool, split transform/draw pattern
  - Lua bindings and wrapper (`sprite2d.lua`)
  - Remote server support (TypeScript bindings, protocol parsing)
  - Nim/Haxe bindings (direct API only, no frame commands)
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
