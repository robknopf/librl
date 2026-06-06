# AGENTS

## Behavior and contract changes

- **Do not** change **observable behavior**, **public API contracts**, or **cross-platform semantics** (e.g. lifecycle, init/run/tick order, loader/IDBFS timing, what callers may assume) without the maintainer’s **explicit approval in the thread first**.
- If a fix would alter when code runs, what is guaranteed, or how bindings or hosts behave, **stop and ask** before editing. Purely internal refactors with no behavioral impact are fine without that step.

## Confirm before implementing

- For **feature work, API design, or non-trivial fixes**, the agent should **outline the plan** (what will change, which files/surfaces, and any tradeoffs) and **wait for the maintainer’s explicit go-ahead in the thread** before editing, unless the user already directed implementation (e.g. “implement it”, “apply the patch”, “go ahead”).
- **Read-only** tasks (questions, reviews, exploration) do not require this step.
- This is in addition to the **Behavior and contract changes** rule above: any change that affects observable behavior or public contracts still needs approval there first.

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
- When changing the JS binding (`bindings/js/src/rl.ts`), run `make binding-types` in the same pass to regenerate `bindings/js/dist/rl.js` and `bindings/js/dist/rl.d.ts` (also runs automatically with `make wasm`, `make desktop`, and `make shared`). Do not edit generated files under `bindings/js/dist/` by hand.
- **Wasm exports:** when adding any new public C function that the JS binding calls via `ccall`, add it to the `EXPORTED_FUNCTIONS` list in `Makefile` (prefixed with `_`) in the same pass. `RL_KEEP` / `EMSCRIPTEN_KEEPALIVE` prevents dead-code stripping but does not make the symbol callable from JS — both are required.
- **Binding tooling:** after C API or binding changes, run `python3 tools/audit_binding_parity.py` and update the gap table in `docs/ROADMAP.md`. Generators and workflow: `docs/MAINTAINER.md` § Tools. Prefer **Python 3** for new repo tooling under `tools/` (not shell); invoke via `python3 tools/foo.py`.
- **Init API:** public binding surfaces expose only `init(config)` and `initAsync(config)` with native config types. Do not expose `rl_init_values` / `rl_init_values_async` (or positional `initValues*` wrappers) on binding public APIs — bindings flatten config and call those C helpers internally. See `docs/BINDINGS.md` init contract.
- **Scratch / SAB bridge (JS/wasm only):** do not expose `rl_scratch_refresh`, `*_to_scratch`, `*_from_scratch`, or other scratch-only wasm bridge symbols on **Haxe, Lua, or Nim** public surfaces. JavaScript (`bindings/js/dist/rl.js`) owns the scratch area and maps bridges to normal methods (`refreshScratch()`, `getScreenSize()`, `pickModel()`, …). Desktop Haxe/Lua/Nim use direct C struct returns where available; wasm Haxe/Nim rely on `tick()` forwarding to the JS binding (which calls `refreshScratch()` internally). If a symbol looks “missing” during parity review, check for commented-out stubs with rationale in binding sources before re-adding. See `docs/BINDINGS.md` (wasm scratch bridge table).

## Binding Naming Policy

Bindings mirror C API shape and intent, but use idiomatic naming per target. C is the template: subsystem-first `rl_<section>_<action>` (e.g. `rl_frame_buffer_submit`).

| Binding | Style | Examples |
|---------|-------|----------|
| **JavaScript** (`bindings/js/src/rl.ts` → `rl.js`) | Nested namespaces per C header; verb-first for handle/instance methods | `RL.fs.init`, `RL.asset.setHost`, `RL.asset.ensure`, `setText2dFont`, `getVersionMajor` |
| **Haxe** (`bindings/haxe/rl/RL.hx`) | Section-first lowerCamelCase | `fsInit`, `assetEnsure`, `text2dSetFont`, `versionMajor` |
| **Nim** | snake_case aligned with C | `rl_fs_init`, `rl_asset_ensure`, `assetCreateTaskGroup` |
| **Lua** | lower snake_case aligned with C | `fs_init`, `asset_ensure`, `text2d_set_font` |

Cross-binding rules:
- **Haxe JS bridge** (`RLImpl.js.hx`) maps Haxe section-first names to nested JS namespaces (`binding.fs.*`, `binding.asset.*`, …).
- **Nim JS backend** (`impl/rl_js.nim`) maps Nim/C names to nested JS `importjs` paths (`__gRl.fs.*`, `__gRl.asset.*`, …).
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

## C implementation naming (`src/`)

- **Public API** (`include/*.h`): subsystem-first `rl_<section>_<action>` (same template bindings mirror).
- **Cross-translation-unit** helpers (one `src/*.c` calling another’s symbol): use **`rl_<subsystem>_...`** and declare the prototype only in **`src/internal/*.h`** — not in `include/` unless promoted to the public API.
- **File-local `static` functions** (one `.c` only): **`static`** is the real contract; naming makes it obvious at a glance that the symbol is **not** public and **not** shared across `src/*.c`.
  - **Do not** use an **`rl_` prefix** on the function name (reserve `rl_*` for library-level symbols: public API and cross-TU internals above).
  - Prefer **`snake_case`** shaped as **`verb_noun`**. Prefer the **shortest name that stays unambiguous in this translation unit**; add an extra noun or qualifier (e.g. `_path`, `_host`) **only when** another helper in the same file would otherwise read the same or collide on meaning (e.g. two different “prepare” steps). Do not add redundant tokens such as **`_task`** solely because a `*_t *` parameter exists — use them **only if** they disambiguate (e.g. pointer- vs handle-based siblings already use **`_ptr`** per below). Examples: `split_url_host_and_path`, `sort_members_for_draw`, `prepare_single_asset` when context is clear.
  - **`_ptr` suffix:** use when the helper takes a **raw instance pointer** (e.g. `some_type_t *`) and related logic (or a sibling helper) uses a **`rl_handle_t`** — so call sites immediately see **pointer path** vs **handle path** (e.g. `poll_task_ptr` vs registering/polling by handle).
  - **Boolean predicates:** prefer **`is_*`** (or `has_*` when possession is the point).
  - **Handle → instance pointer** helpers: prefer **`resolve_*`** or **`lookup_*`** over bare `get_*` so they do not read like tiny public accessors.
  - Large files with several internal sub-areas may use a **short non-`rl_` token** in the noun if it helps scanning (optional); avoid subsystem-shaped `rl_<subsystem>_` prefixes here.
  - **Emscripten `EM_ASYNC_JS` / `EM_JS` (and similar):** do **not** rename the **C function identifier** passed into the macro. Emscripten **embeds that name** in generated JavaScript / linkage glue; renaming breaks the wasm build or runtime unless the Emscripten side is regenerated and updated in lockstep. Treat these identifiers as a **stable Emscripten-facing ABI** for that configuration, **not** as ordinary file-local helpers—even when the definition lives in a single `.c` file. They usually **do not** belong in **`src/internal/*.h`** because other `src/*.c` files do not call them; the contract is with the **toolchain**, not cross-module C.
  - **Bulk / scripted renames:** when a `static` helper’s old name is a **prefix** of a longer **`rl_*` symbol** in the same file (e.g. `rl_sprite3d_get` vs `rl_sprite3d_get_transform`), use **whole-identifier** replacement (word boundaries / AST-aware tooling), not blind substring replace, or you will corrupt the public API.
- **Promotion:** if a helper must become visible to another `src/*.c`, **drop `static`**, rename to **`rl_<subsystem>_...`**, and move the declaration into **`src/internal/*.h`** (do not rely on a `static` helper declared in a header).

## Commit Workflow

- Before any commits, update relevant documentation (`docs/*`, API notes, and binding docs) to match behavior and API changes in the commit.
- After renaming or adding JS binding methods/constants in `bindings/js/src/rl.ts` (and `types.ts` when signatures change), run `make binding-types` (or `make wasm` / `make desktop`) in the same pass and include the regenerated `bindings/js/dist/rl.d.ts` in the commit when that artifact is tracked.

## Testing

- **Desktop:** `make -C tests test_desktop` — no special Node requirement.
- **Wasm / JS bindings:** `make -C tests test_wasm` (or full `make -C tests test`) requires a Node runtime with **JSPI** support (`WebAssembly.Suspending` must be a function).
  - **Do not use `which node` or assume PATH** — Cursor and other tools may inject a non-JSPI Node. Makefiles resolve via `python3 tools/find_node_jspi.py` (nvm Node ≥ 25, e.g. `v26.1.0`).
  - Quick check: `python3 tools/find_node_jspi.py` → should print a path under `~/.nvm/versions/node/...`.
  - Override when needed: `make -C tests test_wasm NODE=/path/to/node` (only honored when that binary has JSPI).
  - Symptom of wrong Node: `Node at ... lacks JSPI` or `TypeError: WebAssembly.Suspending is not a constructor`.
