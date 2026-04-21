# AGENTS

## Binding Parity Policy

- When public C API in `include/*.h` changes, update bindings in the same pass:
  - JavaScript (`bindings/js/*`)
  - Nim (`bindings/nim/*`)
  - Haxe (`bindings/haxe/*`)
  - Lua (`bindings/lua/*`)
- Default policy is clean updates only.
  - Do not add aliases or backward-compatibility shims unless explicitly requested.
- If a binding intentionally does not expose an API, document that decision in `docs/BINDINGS.md`.
