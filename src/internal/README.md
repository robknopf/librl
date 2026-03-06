# Internal Headers

This directory contains **internal-only** headers used to share implementation details across `src/*.c` files.

## Why This Exists

- Keep the public API surface small and stable (`include/*.h`).
- Avoid exposing lifecycle/store internals to bindings and external consumers.
- Make it clear which interfaces are safe for external use vs subject to change.

## What Belongs Here

- Internal subsystem lifecycle wiring (`rl_subsystems.h`)
- Internal store/access headers (`*_store.h`)
- Internal cross-module runtime state (`rl_camera3d_store.h`)
- Export/attribute implementation helpers (`exports.h`)

## What Does Not Belong Here

- Public API declarations intended for consumers/bindings.
- Types/functions that should be stable across versions.

Public-facing headers stay in `include/`.
