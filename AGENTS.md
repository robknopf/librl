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
- When changing the JS binding (`bindings/js/rl.js`), run `make binding-types` in the same pass to regenerate `types/librl.d.ts` (also runs automatically with `make wasm`, `make desktop`, and `make shared`). Do not edit `types/librl.d.ts` by hand.
- **Init API:** public binding surfaces expose only `init(config)` and `initAsync(config)` with native config types. Do not expose `rl_init_values` / `rl_init_values_async` (or positional `initValues*` wrappers) on binding public APIs — bindings flatten config and call those C helpers internally. See `docs/BINDINGS.md` init contract.
- **Scratch / SAB bridge (JS/wasm only):** do not expose `rl_scratch_refresh`, `*_to_scratch`, `*_from_scratch`, or other scratch-only wasm bridge symbols on **Haxe, Lua, or Nim** public surfaces. JavaScript (`bindings/js/rl.js`) owns the scratch area and maps bridges to normal methods (`refreshScratch()`, `getScreenSize()`, `pickModel()`, …). Desktop Haxe/Lua/Nim use direct C struct returns where available; wasm Haxe/Nim rely on `tick()` forwarding to the JS binding (which calls `refreshScratch()` internally). If a symbol looks “missing” during parity review, check for commented-out stubs with rationale in binding sources before re-adding. See `docs/BINDINGS.md` (wasm scratch bridge table).

## Binding Naming Policy

Bindings mirror C API shape and intent, but use idiomatic naming per target. C is the template: subsystem-first `rl_<section>_<action>` (e.g. `rl_frame_buffer_submit`).

| Binding | Style | Examples |
|---------|-------|----------|
| **JavaScript** (`bindings/js/rl.js`) | Verb-first for handle/instance methods; section-first namespaces for modules | `setText2dFont`, `getDefaultTexture`, `getVersionMajor`, `animateModel`; keep `fileio*`, `logger*` |
| **Haxe** (`bindings/haxe/rl/RL.hx`) | Section-first lowerCamelCase | `text2dSetFont`, `fileioEnsure`, `versionMajor` |
| **Nim** | snake_case aligned with C | `rl_text2d_set_font`, `rl_fileio_ensure` |
| **Lua** | lower snake_case aligned with C | `text2d_set_font`, `fileio_ensure` |

Cross-binding rules:
- **Haxe JS bridge** (`RLImpl.js.hx`) maps Haxe section-first names to JS verb-first names at the boundary — do not rename Haxe public API to match JS.
- **Nim JS backend** (`impl/rl_js.nim`) maps Nim/C names to JS verb-first `importjs` strings.
- Do not add backward-compat aliases when renaming JS methods; update call sites and regenerate types instead.
- Full rationale and edge cases: `docs/BINDINGS.md` § Binding Naming.

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

## API Documentation

- `docs/API.md` is the authoritative reference for the public C API. **When any function, type, constant, or enum in `include/*.h` is added, removed, or changed, update `docs/API.md` in the same pass.**
- Each section in `docs/API.md` maps to one header. If a new header is added, add a new section. If a header is removed, remove its section.
- Do not document internal-only symbols (e.g. `rl_window_open`, `rl_window_close`) — only symbols that appear in the public `include/` headers.

## Commit Workflow

- Before any commits, update relevant documentation (`docs/*`, API notes, and binding docs) to match behavior and API changes in the commit.
- After renaming or adding JS binding methods/constants in `bindings/js/rl.js`, run `make binding-types` (or `make wasm` / `make desktop`) in the same pass and include the regenerated `types/librl.d.ts` in the commit. Do not hand-edit `types/librl.d.ts`.

## Testing

- **Desktop:** `make -C tests test_desktop` — no special Node requirement.
- **Wasm / JS bindings:** `make -C tests test_wasm` (or full `make -C tests test`) requires a Node runtime with **JSPI** support (`WebAssembly.Suspending` must be a function). Use the **system Node ≥ 25** (e.g. via nvm), not an IDE-bundled older Node that may appear first on `PATH`.
  - Quick check: `node -e "console.log(typeof WebAssembly.Suspending)"` → expect `function`.
  - Override when needed: `make -C tests test_wasm NODE=/path/to/node` (Makefiles honor `NODE=`).
  - Symptom of wrong Node: `TypeError: WebAssembly.Suspending is not a constructor` during wasm JS binding or Haxe JS boot tests.
