# Maintainer Handbook

Internal reference for building, navigating, and changing librl.

**Work tracking:** [ROADMAP.md](ROADMAP.md) is the single source for tasks (now / next / backlog / research / parked / done). This file is reference only — do not add task lists here.

## Fast Start

From repo root:

```bash
make deps
make desktop
make wasm
make -C examples/c-lua desktop
make test
```

Useful variants:

```bash
make DEV=1 desktop
make DEV=1 wasm
make -C tests test_desktop
make -C tests test_wasm
make clean
cd examples/nim-simple && nim clean
```

## Build and Flag Conventions

- WebGL2 is the default target in project wasm builds:
  - `-s MIN_WEBGL_VERSION=2`
  - `-s MAX_WEBGL_VERSION=2`
- `MIN/MAX_WEBGL_VERSION` are linker settings and should be passed in LDFLAGS (not compile-only CFLAGS), otherwise emcc warns they are ignored.
- `deps/libraylib/Makefile` controls raylib wasm graphics API for `libraylib.wasm.a`.
- Default raylib wasm graphics is ES3 (`GRAPHICS_API_OPENGL_ES3`), but builders can override:

```bash
make -C deps/libraylib wasm_release RAYLIB_WASM_GRAPHICS=GRAPHICS_API_OPENGL_ES2
```

### Top-Level Target Matrix

- Core librl artifacts:
  - `make desktop` -> `lib/librl.a`
  - `make shared` -> `lib/librl.so` (core C API shared library; no Lua module entrypoint)
  - `make wasm_archive` -> `lib/librl.wasm.a`
  - `make wasm` -> `lib/librl.wasm` + JS loader
- Stock Lua module (desktop `require("rl")`):
  - `make rl_lua` -> `lib/rl.so`
  - default lua headers path: `deps/liblua/include` (override with `LIBLUA_INC=/path/to/lua/include`)
  - `lib/rl.so` is linked against `lib/librl.so`
- Embedded Lua VM module (`modules/lua`):
  - `make librl_lua_desktop` -> `modules/lua/lib/librl_lua.a`
  - `make librl_lua_wasm` -> `modules/lua/lib/librl_lua.wasm.a`
  - `make librl_lua` -> builds both
- WASM note:
  - Desktop-style Lua dynamic module loading (`rl.so`) does not apply to wasm.
  - For wasm Lua scripting, use the embedded Lua VM module path (`modules/lua`) and its require/searcher + fetch/fs/asset flow.

## Nested Repo Note (`deps/libraylib`)

- `deps/libraylib` is its own git repo.
- Main repo commits do not include nested repo history changes.
- If `git status` in the main repo shows `deps/libraylib` changed, that means nested repo HEAD/working tree differs from the commit currently referenced by the parent checkout.
- Handle nested repo updates explicitly in that repo.

## Logging and Output Notes

- raylib logs are rerouted via `SetTraceLogCallback(...)` in `examples/c-lua/main.c`.
- We map raylib levels into wgutils logger levels and currently emit via:
  - `log_message(level, "raylib", 0, "%s", msg);`
- `log_message` supports optional source metadata:
  - file present + line > 0: emits file and line
  - file present + line <= 0: emits file only
  - file null: emits no source suffix
- Keep redirected raylib logs source-light unless source info is reliable.

## Repo Policy

- Do not preserve backward compatibility by default in this repo.
- Prefer the cleaner API/architecture change unless compatibility is explicitly requested.
- Do not add compatibility aliases, fallback names, or dual old/new code paths "just in case".
- If a rename or contract change is the right fix, make the breaking change and update callers/docs/bindings in the same pass.
- When adding new systems or changing public API, add/update tests in the same pass:
  - C: unit/integration tests under `tests/`, or example updates that exercise the new surface.
  - Bindings: update `tests/bindings/*` and the corresponding language example(s).

## Naming Conventions

- Prefer subsystem-first public API names:
  - `rl_window_init`
  - `rl_text_draw`
  - `rl_frame_runner_run`
  - `rl_module_lua_get_api`
- For async starters that return a pollable task, make that explicit with `_async`:
  - `rl_asset_ensure_async`
  - `rl_fs_restore_async`
  - `fetch_url_async`
- Keep async task lifecycle verbs readable and non-suffixed:
  - `*_poll_task`
  - `*_finish_task`
  - `*_free_task`
- Callback entry points should use `on_<name>` when they are invoked by another system:
  - `on_init`
  - `on_tick`
  - `on_shutdown`
- Internal processing helpers should use `handle_<name>`:
  - `handle_boot_restore`
  - `handle_boot_prepare`
- Avoid `<name>_handler` naming unless there is a strong reason.
- Module implementation naming should follow `rl_module_<backend>_*`:
  - file/header: `rl_module_lua.c`, `rl_module_lua.h`
  - getter: `rl_module_lua_get_api()`
- Module identity strings like `"lua"` are runtime identifiers, not a reason to use older `rl_lua_*` symbol naming.
- Scratch helpers should be explicitly suffixed:
  - `*_to_scratch` when C writes into the shared scratch area for JS/host to read.
  - `*_from_scratch` when C reads data provided by the host through scratch.
  - JS (and other bindings) should expose normalized APIs and hide the `*_to_scratch`/`*_from_scratch` details.


## Platform/WASM Conventions

- WASM builds must **not** rely on Asyncify. The runtime is single-threaded and cannot block:
  - Do not add new `_sync` convenience wrappers that spin on async tasks.
  - Prefer async starter + poll/finish/free lifecycle (`*_async`, `*_poll_task`, `*_finish_task`, `*_free_task`).
- Platform-specific C implementations should use split files instead of pervasive `#ifdef`:
  - Prefer `<system>.c` + `<system>_wasm.c` when Emscripten behavior diverges.
  - Keep headers and call sites platform-agnostic; select the right object files at build time.
- Avoid embedding platform conditionals in user/host code:
  - No `#ifdef __EMSCRIPTEN__` (or similar) in examples, bindings, or public headers.
  - Caller code should be agnostic of desktop vs wasm; `librl` and `wgutils` hide those details.

## Audio API State

- `rl_music` and `rl_sound` subsystems are available in C/JS/Nim bindings.
- C example currently uses:
  - background music stream: `assets/music/ethernight_club.mp3`
  - click SFX on left mouse press: `assets/sounds/click_004.ogg`
- Cleanup order in example is explicit: destroy handles, then `rl_deinit()`, then `CloseWindow()`.

## Raylib Loader Split

- Not all raylib resource loaders honor `SetLoadFileDataCallback(...)` the same way.
- In this repo, callback-aware resource paths are:
  - textures:
    - `rl_texture_create()` -> `LoadTexture()`
    - raylib texture loading uses `LoadFileData()` through the callback-aware core path
  - models:
    - `rl_model_create()` -> `LoadModel()` / `LoadModelAnimations()`
    - raylib model loading uses callback-aware `LoadFileData()` internally
  - fonts:
    - `rl_font_create()` -> `LoadFileData()` -> `LoadFontFromMemory()`
    - this goes through the callback-aware core file loader before font decode
  - music:
    - `rl_music_create()` -> `LoadFileData()` -> `LoadMusicStreamFromMemory()`
    - this also goes through the callback-aware core file loader first
- Non-callback / bespoke path:
  - sounds:
    - `rl_sound_create()` -> `LoadSound()`
    - in the vendored raylib, `raudio.c` uses its own private `LoadFileData()` helper that falls back to `fopen()` directly
    - because of that, sound creation still assumes the file is already local before `LoadSound()` runs
- Practical implication:
  - if a file-backed resource mysteriously ignores the loader callback path, check whether raylib is using a subsystem-local loader instead of the callback-aware `rcore` path
  - sound loading is the known case today

## Binary size (reference)

Approximate sizes for the example builds (release/optimized, no debug symbols). Use for relative comparison only; exact numbers depend on toolchain and options.

| Build | Desktop | WASM |
|-------|---------|------|
| C (no Lua VM) | ~2.8 MB | ~0.58 MB |
| Nim example | ~2.1 MB | ~0.59 MB |
| Haxe example | ~3.6 MB | ~1.8 MB |
| Haxe cppia host | ~13 MB | not built |

- C without Lua: desktop `make -C examples/c-lua desktop USES_MODULE_LUA=0`, WASM `make -C examples/c-lua wasm USES_MODULE_LUA=0`.
- C and Nim WASM are comparable (~0.58–0.59 MB); Haxe WASM is ~3× larger for similar example scope.
- Haxe cppia adds ~3.5× over the plain Haxe host on desktop; a hypothetical cppia WASM would be proportionally larger and not suited to tight size budgets.

## Web/Vite Workflow Notes

- Web examples use `/bindings/js/dist/rl.js` as the JS binding entrypoint, which instantiates the raw `/lib/librl.js` runtime. If `make clean` removes generated outputs while Vite is running, browser requests can fail until rebuild completes.
- Vite may not always recover automatically from a missing generated entry file (`main.js`/bundled artifacts) without a new file-change trigger.
- Practical flow:
  1. Rebuild wasm/js outputs (`make wasm` or target-specific make).
  2. Touch or re-save relevant entry file if HMR does not recover.
  3. Restart Vite only if file watching still does not pick up rebuilt outputs.
- **Manual wasm smoke (optional):** with Vite running on port 4444, `node tests/smoke/haxe_wasm_smoke.mjs` loads the Haxe wasm example in headless Chromium and prints console/page errors. Not wired into `make test` yet. See `tests/README.md`.
- **Testbed deploy:** `npm run deploy` runs `build:all:release` then rsyncs `examples/www/dist/` to the remote testbed host.
  - `build:librl:release` — `make wasm` + `npm run build:js-binding` (`lib/` + `bindings/js/dist/`)
  - `build:librl` — debug build (`make DEV=1 wasm` + JS binding)
  - `build:examples:release` — all listed www examples (wasm + js targets, including cppia)
  - `vite build` — static shell from `examples/www/`
  - `npm run stage:www:dist` — copies built example artifacts into `examples/www/dist/`
  - Example keys in `examples/www/index.html`: remote, js, c-lua, c-simple, nim-wasm-simple, nim-js-simple, haxe-wasm-simple, haxe-js-simple, cppia

## Scripting Runtime Direction

- Current module/handle architecture is intentionally pointed at a "scripts own gameplay, host owns resources" model.
- Long-term target:
  - build the native or wasm host once
  - edit plain text scripts for gameplay iteration
  - let scripts drive per-frame logic and generate the visual/audio frame
  - keep the option to ship without a permanent interpreter if a future backend supports native/AOT output
- Lua is currently a useful reference/runtime bootstrap, not necessarily the final scripting backend.
- TinyCC and/or daslang remain plausible follow-up experiments behind the same module boundary.

### Scripting Language Criteria

- The "right" scripting language is the one that best matches these goals:
  - very fast iteration with plain text editing and hot reload
  - natural fit for immediate-mode per-frame logic
  - easy embedding behind a narrow C/module host API
  - low friction when issuing handle-based draw/audio/resource commands
  - acceptable debugging and error reporting during iteration
  - viable wasm story for web builds
  - viable native production story without forcing a permanent interpreter into shipping builds
- Lua is strong on embedding speed, maturity, and iteration, but weak on the "no interpreter in production" goal.
- TinyCC is attractive for fast C-like iteration and a more direct path to native execution, but has tradeoffs in safety, tooling, and portability.
- daslang is attractive if the priority is "script fast, ship native-ish later," but it carries more integration complexity.
- Keep the module boundary stable enough that backend experiments can be compared honestly without redesigning the host each time.

### Intended Per-Frame Contract

- Host gathers frame inputs and timing:
  - `dt`
  - keyboard snapshot
  - mouse snapshot
  - window/screen info as needed
- Host calls script `update(...)` once per tick.
- Script calls `rl_*` directly (via bindings) for draw, audio, and resource work — immediate-mode; **no frame-command buffer in core librl** (see `docs/BINDINGS.md`).
- Current status:
  - `examples/c-lua/` — Lua lifecycle host; scripts use wrapper modules that call the flat C API
  - `examples/cppia/` — Haxe cppia scripting host
  - `examples/haxe-simple/`, `examples/nim-simple/` — direct binding usage from game code
  - `examples/remote/` — **isolated experiment**: server streams a private command protocol to a thin client (`examples/remote/include/rl_frame_command.h`); not part of core `include/` or binding parity

### API Shape We Want

- Keep handles as the main bridge between script-side logic and host-owned assets/resources.
- Prefer explicit host API calls for resource lifecycle:
  - create/load resource
  - destroy resource
  - query lightweight state if needed
- Per-frame draw/audio/input work uses direct `rl_*` calls from script update code (same as C hosts).
- Events are acceptable for orchestration and notifications, but should not replace direct render/audio APIs for hot-path work.

### Practical Goal

- In the ideal workflow, the existing C example should be usable as a thin host shell where gameplay can be authored in scripts with a basic text editor.
- To make that real, the script layer still needs a coherent contract for:
  - `init/update`-style lifecycle (or equivalent)
  - input access
  - resource creation returning handles
  - handle-based draw/audio via direct bindings
  - predictable hot reload behavior
  - good source-aware logging/errors

## Current Lua Runtime Shape

- Current Lua entrypoints:
  - `get_config()`
  - `init()`
  - `load()`
  - `update(frame)`
  - `unload()`
  - `serialize()`
  - `unserialize(state)`
  - `shutdown()`
- Ordering in the C example:
  1. host initializes librl and Lua module
  2. host emits `lua.add_path("assets/scripts/lua")`
  3. host emits `lua.do_file("boot.lua")`
  4. host asks the module for config through `api->get_config`
  5. host creates window / sets target FPS
  6. host calls module `start`
  7. Lua runs one-time `init()` if present
  8. Lua runs `load()` if present
  9. host calls Lua `update(frame)` every tick
  10. on reload, Lua runs `serialize()` -> `unload()` -> new chunk -> `load()` -> `unserialize(state)`
  11. on module teardown, Lua runs `unload()` and then `shutdown()`
- `get_config()` currently supports:
  - `width`
  - `height`
  - `title`
  - `target_fps`
  - `flags`
- Lua module currently exposes common window flag constants for `get_config()`.
- Lifecycle intent:
  - `init()` is one-time constructor-style runtime setup
  - `load()` / `unload()` are reloadable code-lifetime hooks
  - `serialize()` / `unserialize(state)` are optional state transfer hooks for HCR
  - `shutdown()` is one-time destructor-style teardown

## Current Lua Support Modules

- Lua modules now exist under `examples/www/public/assets/scripts/lua/`:
  - `color.lua`
  - `model.lua`
  - `texture.lua`
  - `sprite3d.lua`
  - `sound.lua`
  - `music.lua`
  - `camera3d.lua`
  - `font.lua`
- These are intended to be the first layer of a Lua-side standard library:
  - C stays flat and handle-based
  - Lua gets object-like helpers with state and methods
- Current pattern:
  - `Color.create(r, g, b, a)` returns a wrapper around a runtime-created color handle with `:destroy()`
  - `Model.load(path)` returns a table with transform/animation fields and `:draw()`, `:pick()`, `:destroy()`
  - similar shape for texture/sprite/sound/music/font/camera wrappers

## Assets and Credits

- Credits file is at `examples/www/public/assets/CREDITS.md`.
- Current credits include:
  - Kevin MacLeod track attribution (CC BY 3.0)
  - `click_004.ogg` attribution to Kenney (CC0/public domain)

## Common Gotchas

- Seeing `GLSL ES 1.00` at startup means you are effectively on WebGL1 path.
- Seeing NPOT warning (`limited NPOT support`) usually indicates WebGL1 constraints or non-mipmap/non-repeat constraints for NPOT textures.
- Duplicate/buried wasm flags can happen between root, examples, tests, and deps makefiles; prefer a single shared variable per makefile where possible.
- Binding changes should be reflected in:
  - `bindings/js/dist/rl.js`
  - `bindings/nim/rl.nim`
  - `docs/API.md`
- After C API or binding surface changes, run `python3 tools/audit_binding_parity.py` and update `docs/ROADMAP.md` gap table if needed.

## Tools

### Platform policy

Prefer **Python 3** for repo tooling under `tools/` (and new maintainer scripts invoked from Makefiles). Python runs on Linux, macOS, and Windows without bash-specific behavior.

- **Do:** new generators, audits, probes, and Makefile helpers as `tools/*.py` with `#!/usr/bin/env python3`
- **Avoid:** new `tools/*.sh` unless there is a strong reason (document it in the script header)
- **Invoke:** `python3 tools/foo.py` from Makefiles — use `python3` explicitly, not `python`
- **Existing shell:** `tests/bindings/lua/test_version_mismatch.sh` and example scripts (`examples/remote/start_server.sh`) remain; migrate when those tests are next touched. JS version mismatch is `tests/bindings/js/test_version_mismatch.mjs` only.

### Binding tooling

Python helpers under `tools/` — use these instead of hand-editing generated binding artifacts.

| Script | Make target | Purpose |
|--------|-------------|---------|
| `tools/audit_binding_parity.py` | — | Compare `docs/API.md` C functions to JS/Haxe/Nim/Lua public surfaces; prints gap table and ROADMAP-ready markdown. **Run after binding or API changes.** |
| `tools/gen_binding_versions.py` | `make binding-version` | Regenerate version stamps in `bindings/*/gen/` from `include/rl_version.h`. Runs automatically with `make desktop` / `wasm` / `shared`. |
| `npm run build --prefix bindings/js` | `make binding-types` | esbuild bundle of `src/rl.ts` → `dist/rl.js`; `tsc` emits `dist/rl.d.ts` from `src/types.ts`. |
| `tools/gen_haxe_public_sections.py` | — | Regenerate Haxe section façade files (`bindings/haxe/rl/Fs.hx`, `Asset.hx`, …) from the `SECTIONS` map. Run after adding RLImpl methods; then review/commit generated output. |
| `tools/find_node_jspi.py` | — | Locate Node ≥25 with JSPI for wasm tests; used by `tests/Makefile` when `NODE` is unset. |

**Agent workflow:** C header change → update `docs/API.md` + all four bindings → `make binding-types` (if JS changed) → `python3 tools/audit_binding_parity.py` → fix gaps or document intentional omissions in `docs/BINDINGS.md`.

One-off migration scripts (`migrate_fileio_to_fs_asset.py`, `rename_fileio_public_api.py`) are historical; do not run unless explicitly reviving a migration.

Other dev scripts (not binding parity): `show_wasm_sources.py`, `generate_devtools_workspace.py`.

