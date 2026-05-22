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

- **Binding parity (audit snapshot)** — `python3 tools/audit_binding_parity.py` (173 public C functions in `docs/API.md`; excludes scratch/SAB, `rl_init_values*`, logger macros, `examples/remote/`):

  | Binding | Covered | Gaps |
  |---------|--------:|-----:|
  | JS (`bindings/js/rl.js`) | 173/173 | 0 |
  | Haxe (`bindings/haxe/rl/*`) | 172/173 | 1 |
  | Nim desktop (`bindings/nim/impl/rl_native.nim`) | 166/173 | 7 |
  | Lua (`bindings/lua/`) | 169/173 | 4 |

  **Fix (Nim desktop — 7):**
  - `rl_fs_normalize_path`, `rl_fs_read`, `rl_fs_read_free`
  - `rl_sprite2d_get_default_texture`, `rl_sprite3d_get_default_texture`, `rl_sprite3d_get_transform`
  - `rl_init_config_sizeof` (optional — FFI internal; wasm/JS only today)

  **Fix (Lua — 4):**
  - `rl_sprite2d_get_default_texture`, `rl_sprite3d_get_default_texture`, `rl_sprite3d_get_transform`
  - `rl_init_config_sizeof` (optional — FFI internal)

  **Fix (Haxe — 1):**
  - `rl_init_config_sizeof` (optional — cpp uses struct layout directly; **remove** if init flattening backlog lands)

  Re-run the audit script after binding changes. Intentional non-gaps: scratch/SAB, `rl_init_values*`, `rl_frame_command*` — see `docs/BINDINGS.md`.

- Binding tooling for agents/maintainers — see `docs/MAINTAINER.md` § Tools (Python-first policy; generators, parity audit, `make binding-types` / `binding-version`).
- remove scratch/ABI bindings from non-JS bindings — done for `scratch_refresh` / `scratchRefresh` / `rl_scratch_refresh` (commented in sources; see `docs/BINDINGS.md`); audit for any other `*_to_scratch` / `*_from_scratch` if added later
- align logging ergonomics across Nim/Haxe/Lua (`log.debug/info/warn/error/...` style)
- **JS binding tests:** extend `tests/bindings/js` beyond version stamps (e.g. headless `rl.init` / core `RL` API smoke with Node ≥25 / JSPI)
- API/docs sync:
  - keep examples current as APIs change
  - keep `README.md`, `docs/API.md`, `docs/BINDINGS.md`, and `docs/MAINTAINER.md` aligned when the Lua/module surface changes
  - expand `tools/gen_librl_dts.py` `SIGNATURE_OVERRIDES` for model/sprite/camera methods (most still emit generic `unknown` signatures)
- Naming convention cleanup (remaining):
  - rename `async/wg_*` to drop the `wg_` prefix (align with `websocket_`, `fetch_url_`)
  - optional: verb-first pass on `debug*` / `logger*` (currently kept section-first as module namespaces)

### Lua / scripting host

- Lua event listener ownership across reloads:
  - current script-facing API: `event_on`, `event_off`, `event_emit`
  - current temporary policy is script-managed listener teardown
  - add ownership/generation tracking so reload cleanup can be selective
- Decide whether the host fallback `ClearBackground(RAYWHITE)` remains in `examples/c-lua/main.c` or Lua fully owns frame clear.
- Hot reload / HCR follow-up (`load/unload/serialize/unserialize` exist):
  - define what survives reload vs what is reconstructed
  - decide exact persistence rules for script globals vs restored state
  - decide whether reload should stay in the same VM or move toward new-VM swap later
  - decide whether unload/load should become mandatory for script modules or remain optional hooks
  - make error/reporting behavior predictable during reload
- Document the Lua script-facing surface in a smaller user-facing note once lifecycle and wrappers stabilize.

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

### Init / C ABI (wasm-friendly flattening)

Today: **`RL.initAsync()`** already calls **`rl_init_values_async`** (flat args). **`RL.init()`** still marshals `rl_init_config_t` by hand via **`rl_init_config_sizeof`** + wasm heap layout — redundant with the values helpers.

**Near-term (bindings only, no C contract change):**
- Change **`RL.init()`** to call **`rl_init_values`** with the same flattened fields as `initAsync` (sync fs path vs async fs path stays the difference).
- Delete duplicated struct-packing in `bindings/js/rl.js` (`_callInitWithOptions*` else branches).
- Document **`rl_init_config_sizeof`** as wasm-internal / candidate for removal once JS no longer uses it.

**Consider (C ABI reshape — needs explicit approval per `AGENTS.md`):**
- Make **`rl_init_values` / `rl_init_values_async`** the primary **exported** init entry points for wasm (FFI-friendly scalars + strings).
- Demote **`rl_init` / `rl_init_async`** (`const rl_init_config_t *`) from the public wasm ABI:
  - keep as **desktop C helpers** (inline or `static inline` in header, or internal symbols) that build config and call the values functions, **or**
  - keep in `include/rl.h` for native hosts (`examples/c-simple`, `examples/remote`, Nim/Lua desktop) but **drop from `EXPORTED_FUNCTIONS`** / wasm link.
- Remove **`rl_init_config_sizeof`** from public C API + wasm exports if nothing else needs struct sizing.
- Bindings unchanged at the user surface: still `init(config)` / `initAsync(config)` with native config types; impl always flattens to values API internally.
- Audit callers: `examples/*`, `tests/bindings/nim`, Lua `rl_init(&cfg)` — migrate to values API or struct helper as needed.
- Empty-string → NULL normalization in `rl_init_values` may fix subtle default-title/cache differences vs current JS struct path (verify in tests).

### API consistency

- Re-evaluate model animation GPU prep path:
  - confirm warning behavior is once-per-instance
  - document/validate missing-normal-VBO fallback behavior
- Consider caching animation GPU-state readiness per model instance to avoid per-frame mesh scans.

---

## Research

Needs evaluation or a design decision before implementation.

- Scripting backend evaluation:
  - keep Lua as the reference implementation for module-hosted scripting
  - compare TinyCC, daslang, and Haxe/cppia against the same flat `rl_*` API
  - evaluate: hot reload latency, host API friction, debugging quality, wasm feasibility, native production story without a permanent interpreter, ergonomics for handle-based host calls
  - Haxe/cppia-specific: does it provide a strong "same source in dev + native production later" path without unacceptable C++/toolchain friction?
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

### Scripting backend candidates (beyond Lua)

- **hxcpp + cppia**: typed Haxe in dev (cppia fast reload), compiled native in prod
- **TinyCC**: C scripts compiled at runtime
- **daslang**: statically typed scripting
- All backends should call the same flat `rl_*` C API (same as current bindings)

### Lua bootstrap / import cleanup

- Current startup path is an adapter layer (`boot.lua`, local-only `require`, event-driven `script.import`, `import_pump()` coroutine glue) — stopgap, not final model
- Likely simplification: host localizes a single manifest/boot file up front; declared scripts localized before lifecycle; runtime async import stays separate from startup
- Re-evaluate entry file: `boot.lua` vs `manifest.lua` vs host-owned alternative
- HCR warning: do not build hot code reload on top of the current bootstrap shim — simplify boot/import ownership first

### Lua runtime polish

- Decide whether window bootstrap should grow beyond `get_config()` (min/max size, vsync hint, other window policy flags)
- Document the Lua standard-library layer for script authors (`color.lua`, `model.lua`, etc.)

### Wasm + embedded scripting

- Decide later whether wasm Lua should be: embedded Lua VM, JS-side Lua bridge, or something else
- Keep the thin-host boundary stable enough that this can be swapped without redesigning the runtime

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

- Binding parity audit (2025-05):
  - `tools/audit_binding_parity.py` added; 173 C functions audited
  - JS 173/173; Haxe 172/173; Nim desktop 166/173; Lua 169/173
  - gap table in **Next → Binding parity** above
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
  - auto-generated `types/librl.d.ts` via `tools/gen_librl_dts.py` + `make binding-types`
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
