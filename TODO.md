# TODO

## Short Term

- Handle system rewrite (first):
  - migrate all remaining subsystems to `rl_handle_pool` (slot + generation)
  - remove legacy monotonic-ID code paths
  - validate stale-handle behavior consistently across all destroy/set/get APIs
- External ID mapping layer:
  - add optional `external_id -> internal_handle` mapping
  - allow caller-supplied IDs while preserving internal handle safety
  - define replace/update behavior when an external ID is reused
- Lua integration:
  - desktop: Lua C module (`require`) path first
  - target Lua 5.2 + LuaJIT compatibility
  - wasm: evaluate JS-side Lua bridge vs embedded Lua VM approach
- Frame snapshot submission API:
  - define a compact frame command/snapshot structure using `rl_handle_t`
  - add one-call submit path for per-frame draw state/commands
  - start with clear + camera + model/text/rect primitives
- API/docs sync after recent camera/input refactor:
  - status: mostly done
  - keep examples current when scratch bridge functions are renamed/removed
  - add/maintain a short "wasm-only bridge API" table in docs (`*_to_scratch` functions + JS wrapper names)
- URI/path follow-up:
  - add URL normalization examples to docs
  - decide whether cache keys should canonicalize host casing
- Asset versioning + manifest:
  - add per-asset version metadata so cached files can be upgraded/replaced safely
  - define a manifest format (Babylon-style) listing assets, versions, hashes, and URLs
  - on startup/load, compare manifest vs local cache and invalidate stale entries
- IDBFS lifecycle hardening: done (single sync path + overlap guard + documented ready-state timing)
- FileIO logging cleanup: done
  - standardized FileIO message style and capitalization
  - switched FileIO logging calls to shared `logger/log` API
  - moved logger implementation from `src/vendor/logger` to `src/logger`
- Audio support baseline: done
  - added `rl_music` (streaming BGM) and `rl_sound` (SFX) subsystems
  - wired lifecycle into `rl_init()` / `rl_deinit()`
  - exported APIs in C + JS + Nim bindings and documented in `docs/API.md`
  - C example now includes BGM + click SFX playback
- Developer handoff docs: done (`docs/DEV_NOTES.md`)

## Parking Lot

### API Consistency

- Re-evaluate model animation GPU prep path:
  - confirm warning behavior is once-per-instance
  - document/validate missing-normal-VBO fallback behavior
- Consider caching animation GPU-state readiness per model instance to avoid per-frame mesh scans.
- Picking follow-up:
  - broad-phase checks before narrow-phase ray tests: done (model world-AABB and sprite billboard-sphere early reject)
  - add a scene-level "what's under the mouse" API that returns closest hit target + hit data

### Build / Tooling

- Build/test smoke target: done (`make test` now runs desktop + wasm unit tests, plus desktop `uri_test` and wasm artifact checks)
- C example wasm target naming cleanup: done (`wasm-debug-smap` merged into `wasm-debug`)
- Consider formatting/lint guidance for C, JS, and Nim.

### Product Roadmap

- Proper test suites:
  - unit tests for core subsystems
  - integration tests for desktop and wasm flows
  - regression tests for model loading/animation edge cases
- Flush out API for bindings:
  - formalize a stable binding-oriented API surface
  - ensure JS/Nim wrappers map cleanly to all intended features
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

### Follow-up Cleanup

- Review all headers for stale declarations after recent refactors: ongoing
- Expand `docs/API.md` to function-by-function docs:
  - call order expectations
  - return/error semantics
  - platform-specific notes (desktop vs web)
- Include source-of-truth pointers in docs for build/runtime internals:
  - public usage in `README.md`
  - maintainer internals in `docs/DEV_NOTES.md`
- Expand `docs/BINDINGS.md` with minimal usage examples for JS and Nim.
