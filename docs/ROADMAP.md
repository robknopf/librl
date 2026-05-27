# Roadmap

Single work-tracking doc for librl. Maintainer reference (build, conventions, architecture) lives in [MAINTAINER.md](MAINTAINER.md).

**Tiers:** Now → Next → Backlog → Research → Parked → Done

---

## Now

Nothing explicitly flagged in-flight. Move items here when actively working them.

---

## Next

Committed near-term work — pick up when Now is clear.

### Bindings and docs

- **Binding parity** — closed (172/172 all bindings). Re-run `python3 tools/audit_binding_parity.py` after C API or binding changes; see Done (2025-05).

- Binding tooling for agents/maintainers — see `docs/MAINTAINER.md` § Tools (Python-first policy; generators, parity audit, `make binding-types` / `binding-version`).
- remove scratch/ABI bindings from non-JS bindings — done for `scratch_refresh` / `scratchRefresh` / `rl_scratch_refresh` (commented in sources; see `docs/BINDINGS.md`); audit for any other `*_to_scratch` / `*_from_scratch` if added later
- align logging ergonomics across Nim/Haxe/Lua (`log.debug/info/warn/error/...` style)
- **JS binding tests** (`tests/bindings/js/` — Node ≥25 / JSPI):
  - done: boot smoke (`test_boot_smoke.mjs`), namespace shape (`test_namespace_smoke.mjs`), init preconditions / window boundary in Node (`test_init_smoke.mjs`), version stamp suite (existing)
  - next: browser headless init → tick → deinit smoke (wire `tests/headless/idbfs_probe_rl.html` or Puppeteer equivalent into `make test`)
  - next: fs restore / asset ensure smoke (Node or browser)
  - next: handle create/destroy round-trips for one resource type (e.g. `color`, `camera3d`) once init runs in CI
- API/docs sync:
  - keep examples current as APIs change
  - keep `README.md`, `docs/API.md`, `docs/BINDINGS.md`, and `docs/MAINTAINER.md` aligned when the Lua/module surface changes
- Naming convention cleanup (remaining):
  - rename `async/wg_*` to drop the `wg_` prefix (align with `websocket_`, `fetch_url_`)
  - optional: verb-first pass on `debug*` / `logger*` (currently kept section-first as module namespaces)

### Lua / scripting host (thin host — no HCR)

- Decide whether the host fallback `ClearBackground(RAYWHITE)` remains in `examples/c-lua/main.c` or Lua fully owns frame clear.
- Light docs for the current Lua script surface (`runtime_wrapper.lua`, wrapper modules under `examples/www/public/assets/scripts/lua/`) — document what exists today; no HCR lifecycle promises.

**Deferred:** Lua hot reload / HCR — see **Parked → Lua hot reload / HCR**. Prefer the working Haxe/cppia reload path (`examples/cppia/`, `ScriptableMain`) until scripting strategy is decided in **Research**.

### Platform / infrastructure

- Remote client / networking (`examples/remote/`):
  - add desktop websocket support (currently a stub; evaluate libwebsockets or upgraded libcurl 7.86+)
  - add client→server communication for input states
  - move to binary protocol (swappable serialization layer?)
  - once client shape settles, move transport/protocol into `rl` proper so examples consume librl without direct `wgutils` dependency
- HEADLESS follow-up:
  - leverage `HEADLESS` beyond tests for Node/Bun/server-oriented builds
  - define what runtime pieces no-op or return defaults in headless mode (input, windowing, frame pacing, audio)
  - add a minimal runnable headless host path so wasm logic can execute outside the browser
  - use that path to improve automated runtime verification beyond compile-only checks
- Loader / FS bootstrap:
  - evaluate adding a higher-level init helper that triggers a default filesystem restore and lets `rl_run` gate `init` on `rl_fs_is_ready`
  - keep low-level restore/import APIs available for advanced callers
  - WASM `fetch_url_head()`: requires async state machine refactor to support HEAD-then-GET pattern for download progress tracking (Content-Length from HEAD response)

### Core API follow-ups

- External ID mapping layer:
  - add optional `external_id -> internal_handle` mapping
  - allow caller-supplied IDs while preserving internal handle safety
  - define replace/update behavior when an external ID is reused
- Event system follow-up:
  - add an explicit queue (`enqueue`) alongside immediate emit semantics
  - add queue processing/drain API
  - decide where queued events are drained (core update loop, module update phase, caller-owned explicit drain)
  - if Lua gets a general event API later, decide whether script listeners bind to immediate events, queued events, or both

---

## Backlog

Designed enough to implement when prioritized.

### Picking

- **Batch pick API** — `pick_group(camera, handles, mouseX, mouseY)` (or similar):
  - one mouse ray per query (not one per handle)
  - one wasm crossing on JS instead of N
  - return closest hit (handle + distance + local point/normal); decide mixed model/sprite3d vs homogeneous lists
  - C: `rl_pick_group_to_scratch` (or `_from_scratch` handle list + scratch result slots), then binding parity (JS/Haxe/Nim/Lua)
  - optional frustum pre-pass before broadphase when iterating many candidates
  - determine ownership of scene graph/state (host app vs librl) for scene-level picking

### Rendering

- **Camera frustum culling** — optional pre-filter for pick and 3D draw paths:
  - today: neither `rl_pick_*` nor `rl_model_draw` / `rl_sprite3d_draw` test view frustum; broadphase pick is ray-vs-bounds only
  - raylib does **not** CPU-frustum-cull `DrawModel*` / `DrawBillboard` (no scene graph; culling is caller responsibility — see [raylib#3136](https://github.com/raysan5/raylib/issues/3136)); GPU clip volume still discards off-screen fragments, but draw calls and vertex submission still happen
  - reuse cached model local bounds + sprite3d position/size for `FrustumContainsBox` / sphere tests against active camera
  - candidates: opt-in on `pick_group`; optional skip in `rl_model_draw` / `rl_sprite3d_draw`
  - raylib frustum helpers live outside core API (e.g. raylib-extras / rcamera discussion in [raylib#4114](https://github.com/raysan5/raylib/issues/4114)) — decide vendoring vs small internal helper

### API consistency

- Re-evaluate model animation GPU prep path:
  - confirm warning behavior is once-per-instance
  - document/validate missing-normal-VBO fallback behavior
- Consider caching animation GPU-state readiness per model instance to avoid per-frame mesh scans.

---

## Research

Needs evaluation or a design decision before implementation.

- **`rl_scene` (retained presentation layer)** — design doc: [design/rl_scene.md](design/rl_scene.md). Scene membership + `rl_scene_draw` (Raylib) / `rl_scene_sync` (Defold future); builds on handle kinds in `rl_handle.h`. Prototype Raylib-only first.
- **Scripting backend strategy** (current leaning hypothesis):
  - **Preferred path:** Haxe host (`hxcpp` → emcc on wasm) + `MainScript.cppia` for dev iteration (`onUnload` / `onLoad` state handoff, file-watcher reload in `examples/cppia/ScriptableMain`) + compile script into the host for production (no permanent interpreter at ship time).
  - **Lua:** keep as reference thin-host and desktop option (`examples/c-lua`, `bindings/lua`); not the default wasm gameplay path unless evaluation overturns this.
  - **Open tradeoff:** always-on Lua VM (wasm bundle size, permanent interpreter, HCR design cost — VM lifecycle, `require` cache, event/handle ownership across reload) vs cppia-in-dev / compiled-in-for-prod.
  - Still compare if needed: TinyCC, daslang, embedded Lua on wasm vs JS-side Lua bridge.
  - Criteria: hot reload latency, host API friction, debugging quality, wasm feasibility and size, native production story without interpreter, ergonomics for handle-based host calls.
- Event payload bridge for JS:
  - add scratch-area read/write helpers for event payloads so JS can exchange structured payload data with C listeners
  - define a stable payload layout/versioning strategy for JS/Nim/C safety
  - re-evaluate the long-term role of JS bindings if in-wasm scripting becomes the primary gameplay path
- Module SDK split:
  - define a separate module SDK package/repo for out-of-tree module builds
  - include stable module ABI and documented versioning/compatibility policy
  - define how wgutils is provided in the SDK for module portability
  - keep module development in-tree until the SDK contract is stable
- URI/path follow-up:
  - add URL normalization examples to docs
  - decide whether cache keys should canonicalize host casing
- Asset versioning + manifest:
  - add per-asset version metadata so cached files can be upgraded/replaced safely
  - define a manifest format listing assets, versions, hashes, and URLs
  - compare manifest vs local cache on startup/load and invalidate stale entries

---

## Parked

Explicitly deferred — not on the near-term path.

### Lua binding architecture

- Keep Lua bindings as `.c` files for maximum build flexibility (static, shared, WASM)
- Location: `bindings/lua/rl_lua.c` (direct `rl_*` API; no frame commands)
- Entry point: `luaopen_rl()` following Lua module convention
- **Build flag:** `WITH_LUA=1` — includes `bindings/lua/rl_lua.c` into `librl.a`/`librl.wasm.a` (Lua headers only, no liblua link)
- Host provides Lua VM; bindings provide glue via `luaopen_rl()`
- Desktop LuaJIT path: FFI bindings loading `librl.so` directly, bypassing C bindings
- PUC Lua path: standard `luaopen_rl` C binding

### Scripting backend candidates

- **hxcpp + cppia** — **active in `examples/cppia/`** (typed Haxe in dev, cppia reload, compile-in for prod); not a hypothetical
- **TinyCC**: C scripts compiled at runtime
- **daslang**: statically typed scripting
- All backends should call the same flat `rl_*` C API (same as current bindings)

### Lua hot reload / HCR

Deferred until scripting strategy settles (see **Research → Scripting backend strategy**). Do not prioritize over the working cppia reload loop.

- Lua event listener ownership across reloads:
  - current script-facing API: `event_on`, `event_off`, `event_emit`
  - current temporary policy is script-managed listener teardown
  - add ownership/generation tracking so reload cleanup can be selective
- Hot reload / HCR follow-up (`load` / `unload` / `serialize` / `unserialize` sketched in `lua_demo.lua`; host sequence documented in `docs/MAINTAINER.md`):
  - define what survives reload vs what is reconstructed
  - decide exact persistence rules for script globals vs restored state
  - decide whether reload should stay in the same VM or move toward new-VM swap later
  - decide whether unload/load should become mandatory for script modules or remain optional hooks
  - make error/reporting behavior predictable during reload
- Document the full Lua script-facing surface (including HCR hooks) once lifecycle and boot/import ownership are stable

### Lua bootstrap / import cleanup

- Current startup path is an adapter layer (`boot.lua`, local-only `require`, event-driven `script.import`, `import_pump()` coroutine glue) — stopgap, not final model
- Likely simplification: host localizes a single manifest/boot file up front; declared scripts localized before lifecycle; runtime async import stays separate from startup
- Re-evaluate entry file: `boot.lua` vs `manifest.lua` vs host-owned alternative
- HCR warning: do not build hot code reload on top of the current bootstrap shim — simplify boot/import ownership first

### Lua runtime polish

- Decide whether window bootstrap should grow beyond `get_config()` (min/max size, vsync hint, other window policy flags)
- Document the Lua standard-library layer for script authors (`color.lua`, `model.lua`, etc.)

### Wasm + embedded scripting

- Default hypothesis: wasm gameplay scripting via Haxe/cppia (see **Research**), not a permanent embedded Lua VM — unless evaluation says otherwise.
- If Lua on wasm is revisited: embedded Lua VM vs JS-side Lua bridge vs other; keep the thin-host boundary stable enough that this can be swapped without redesigning the runtime

### Build / tooling

- Consider formatting/lint guidance for C, JS, and Nim.

### Product roadmap (long horizon)

- Proper test suites: unit tests for core subsystems, integration tests for desktop/wasm, model loading/animation regression tests
- Flush out binding-oriented API surface; re-evaluate JS binding role after scripting experiments
- Audio polish: seek/time query for music, fade helpers, grouped volume controls, larger-asset browser validation
- Input I/O hooks/callbacks (mouse, keyboard)
- Evaluate collision/physics support scope and architecture
- Evaluate NavMesh support (Recast/Detour integration path)
- Evaluate tilemap support (e.g. Tiled pipeline and runtime representation)

---

## Done

Changelog — trim periodically.

- Binding parity complete (2025-05): all bindings 172/172; `tools/audit_binding_parity.py`; Nim `rl_asset.h` FFI imports + string wrappers; `rl_fs_read*`, `rl_fs_normalize_path`, sprite default-texture/get-transform on Nim + Lua
- JS binding TypeScript source (2025-05): `bindings/js/src/rl.ts` + `types.ts`; `bindings/js/package.json` scripts (esbuild bundle + `tsc` declarations) emit `dist/rl.js` and `dist/rl.d.ts`; retired `tools/gen_librl_dts.py`
- C init ABI flattening (2025-05): public init is `rl_init_values` / `rl_init_values_async`; removed struct-based `rl_init*` and `rl_config.h`
- JS init flattening (2025-05): `RL.init()` calls `rl_init_values`; struct marshaling removed from `bindings/js/rl.js`
- Docs consolidation (2025-05):
  - single work tracker: `docs/ROADMAP.md` (now / next / backlog / research / parked / done)
  - maintainer reference renamed: `docs/DEV_NOTES.md` → `docs/MAINTAINER.md`
  - docs index: `docs/README.md`
- Frame-command architecture scrub (2025-05):
  - core librl/bindings use direct `rl_*` API; frame commands isolated to `examples/remote/` only
  - removed stale frame-command tasks and docs references
- JS binding naming + types (2025-05):
  - verb-first handle/instance methods on `bindings/js/rl.js`; `fileio*` / `logger*` stay section-first
  - Haxe/Nim/Lua keep section-first public names; Haxe/Nim JS bridges map to JS verb-first at the boundary
  - default handles: getters only; removed binding-level `FONT_DEFAULT` / `CAMERA3D_DEFAULT` and sprite default-texture helpers
  - `text2d` lowercase-`d` casing aligned across JS, examples, and generated types
  - auto-generated `bindings/js/dist/rl.d.ts` via `bindings/js/src/types.ts` + `npm run build --prefix bindings/js` + `make binding-types`
  - wasm scratch bridge table in `docs/BINDINGS.md`
- Sprite2D module:
  - C implementation with handle pool, split transform/draw pattern
  - Lua bindings and wrapper (`sprite2d.lua`)
  - Remote server support (TypeScript bindings, protocol parsing)
  - Nim/Haxe bindings (direct API only)
- Picking broad-phase optimization:
  - model world-AABB early reject
  - sprite billboard-sphere early reject
- IDBFS lifecycle hardening: single sync path, overlap guard, documented ready-state timing
- FileIO logging cleanup: standardized message style; shared `logger/log` API; moved logger to `src/logger`
- Audio support baseline: `rl_music` + `rl_sound`; lifecycle in `rl_init`/`rl_deinit`; C + JS + Nim bindings
- Build/test smoke target: `make test` (desktop + wasm unit tests, `uri_test`, wasm artifact checks)
- C example wasm target naming: `wasm-debug-smap` merged into `wasm-debug`
- Maintainer handbook: `docs/MAINTAINER.md` useful for session restart
