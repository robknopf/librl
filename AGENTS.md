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

## Native Type Policy

User-facing binding APIs must use the target language's native types — not C FFI types — for all parameters and return values:

| Layer | Rule |
|-------|------|
| Public / user-facing | Native types only: Nim `int`/`float`/`string`, Haxe `Int`/`Float`/`String`, Lua numbers/strings |
| Internal C bridge | C FFI types allowed: `cint`, `cfloat`, `cstring`, `Int32`, etc. |

Concrete rules:
- **Nim**: public procs use `int`, `float`, `string`. C-imported procs that return or take `cint`/`cfloat`/`cstring` are named with a `_c` or `_raw` suffix and kept private. Public wrappers convert at the boundary (`.int`, `.cint`, `.cstring`, etc.).
- **Haxe**: public `RL.*` methods use `Int`, `Float`, `String`. FFI plumbing stays inside `RLImpl.*.hx`.
- **Lua**: Lua numbers and strings are the only surface types. C types are internal to `bindings/lua/*.c`.
- **Constants**: binding-level constants (e.g. `RL_INIT_OK`, `RL_TICK_FAILED`) must be the target language's native integer type, not a C-cast integer.

The two-layer pattern for Nim (and analogously for other bindings with explicit FFI types):
```nim
# private C bridge — stays unexported
proc rl_foo_c(x: cint): cint {.importc: "rl_foo", cdecl, header: "rl.h".}

# public user-facing wrapper — Nim types only
proc rl_foo*(x: int): int {.inline.} = rl_foo_c(x.cint).int
```

When adding new procs to any binding, always check: would a user need to write `.cint`, `.cfloat`, or `.cstring` at the call site? If yes, the binding is incomplete — add the wrapper.

## Commit Workflow

- Before any commits, update relevant documentation (`docs/*`, API notes, and binding docs) to match behavior and API changes in the commit.
