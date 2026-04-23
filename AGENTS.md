# AGENTS

## Behavior and contract changes

- **Do not** change **observable behavior**, **public API contracts**, or **cross-platform semantics** (e.g. lifecycle, init/run/tick order, loader/IDBFS timing, what callers may assume) without the maintainer’s **explicit approval in the thread first**.
- If a fix would alter when code runs, what is guaranteed, or how bindings or hosts behave, **stop and ask** before editing. Purely internal refactors with no behavioral impact are fine without that step.

## Binding Parity Policy

- When public C API in `include/*.h` changes, update bindings in the same pass:
  - JavaScript (`bindings/js/*`)
  - Nim (`bindings/nim/*`)
  - Haxe (`bindings/haxe/*`)
  - Lua (`bindings/lua/*`)
- Default policy is clean updates only.
  - Do not add aliases or backward-compatibility shims unless explicitly requested.
- When creating or updating bindings, keep non-C-API files (helpers, wrappers, ergonomics layers) separate from direct C-API binding files.
- If a binding intentionally does not expose an API, document that decision in `docs/BINDINGS.md`.
