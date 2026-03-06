# TODO

## Short Term

- Add `rl_sprite3d` system:
  - handle-based sprite3d creation/draw/destroy API
  - initial implementation as textured billboard for rapid prototyping
  - bind through JS/Nim once C API is stable
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

- Align `include/rl_model.h` with implementation names:
  - `rl_model_set_animation_looping` vs `rl_model_set_animation_loop`
  - remove stale `RL_MODEL_DEFAULT` declarations if fully deprecated
  - remove stale `rl_model_get_default()` declaration if not implemented
- Review all headers for stale declarations after recent refactors.
- Sync Nim binding (`bindings/nim/rl.nim`) with current C headers:
  - remove/import missing symbols that changed recently
  - verify looping function name matches header/API
- Expand `docs/API.md` to function-by-function docs:
  - call order expectations
  - return/error semantics
  - platform-specific notes (desktop vs web)
- Expand `docs/BINDINGS.md` with minimal usage examples for JS and Nim.
