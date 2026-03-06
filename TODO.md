# TODO

## Short Term

- Handle system rewrite (first):
  - replace monotonic IDs with generational handles (slot + generation)
  - add free-list reuse so create/destroy cycles remain stable
  - invalidate stale handles cleanly on destroy
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
  - document `rl_camera3d_*` flow + default camera behavior
  - document `rl_begin_mode_3d()` active-camera semantics
  - document mouse state access parity (`getMouseState` / `rl_get_mouse_state`)
- URI/path follow-up:
  - add URL normalization examples to docs
  - decide whether cache keys should canonicalize host casing

## Parking Lot

### API Consistency

- Re-evaluate model animation GPU prep path:
  - confirm warning behavior is once-per-instance
  - document/validate missing-normal-VBO fallback behavior
- Consider caching animation GPU-state readiness per model instance to avoid per-frame mesh scans.

### Build / Tooling

- Add a `make test` target (or equivalent smoke targets) for:
  - desktop build + basic run
  - wasm build artifact check
- Consider formatting/lint guidance for C, JS, and Nim.

### Product Roadmap

- Proper test suites:
  - unit tests for core subsystems
  - integration tests for desktop and wasm flows
  - regression tests for model loading/animation edge cases
- Flush out API for bindings:
  - formalize a stable binding-oriented API surface
  - ensure JS/Nim wrappers map cleanly to all intended features
- Audio support:
  - SFX playback API
  - BGM stream support (play/pause/seek/loop/volume)
- Input I/O hooks/callbacks:
  - mouse callbacks/events
  - keyboard callbacks/events
- Evaluate collision/physics support scope and architecture.
- Evaluate NavMesh support (Recast/Detour integration path).
- Evaluate tilemap support (e.g. Tiled pipeline and runtime representation).

### Follow-up Cleanup

- Review all headers for stale declarations after recent refactors.
- Expand `docs/API.md` to function-by-function docs:
  - call order expectations
  - return/error semantics
  - platform-specific notes (desktop vs web)
- Expand `docs/BINDINGS.md` with minimal usage examples for JS and Nim.
