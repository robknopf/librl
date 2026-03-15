# Internal Headers

This directory contains **internal-only** headers used to share implementation details across `src/*.c` files.

## Why This Exists

- Keep the public API surface small and stable (`include/*.h`).
- Avoid exposing lifecycle/store internals to bindings and external consumers.
- Make it clear which interfaces are safe for external use vs subject to change.

## What Belongs Here

- Per-module internal headers (`rl_*.h`) for private lifecycle hooks and cross-`src/*.c` declarations
- Export/attribute implementation helpers (`exports.h`)

## What Does Not Belong Here

- Public API declarations intended for consumers/bindings.
- Types/functions that should be stable across versions.

Public-facing headers stay in `include/`.
