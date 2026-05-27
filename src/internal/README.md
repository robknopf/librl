# Internal Headers

This directory contains **internal-only** headers used to share implementation details across `src/*.c` files.

## Why This Exists

- Keep the public API surface small and stable (`include/*.h`).
- Avoid exposing unnecessary lifecycle/store internals to bindings and external consumers
- Make it clear which interfaces are safe for external use vs subject to change.

## What Belongs Here

- Per-module internal headers (`rl_*.h`) for private lifecycle hooks and cross-`src/*.c` declarations
- Export/attribute implementation helpers (`exports.h`)

## What Does Not Belong Here

- Public API declarations intended for consumers/bindings.
- Types/functions that should be stable across versions.

Public-facing headers stay in `include/`.

## C symbol naming

- **`static` functions** in one `.c` file: **do not** use the `rl_<subsystem>_` prefix. They are translation-unit private; local names make that obvious at a glance.
- **Symbols shared across `src/*.c` files** (non-`static`, internal linkage to the library): use the usual **`rl_<subsystem>_...`** shape and declare them **only** in headers under this directory (`src/internal/rl_*.h`). They are **not** public API unless also added to `include/`.
