# Maintainer Handbook

Internal reference for building, navigating, and changing librl.

**Work tracking:** [ROADMAP.md](ROADMAP.md) is the single source for tasks (now / next / backlog / research / parked / done). This file is reference only — do not add task lists here.

**Related docs:** [API.md](API.md) (C API), [BINDINGS.md](BINDINGS.md) (binding conventions), [docs/README.md](README.md) (doc index), [AGENTS.md](../AGENTS.md) (agent/editor contract).

## Fast Start

From repo root:

```bash
make deps
make desktop
make wasm
make -C examples/c-lua desktop
make test
```

Web dev (Vite testbed + rebuild watchers + cppia script compile + script watcher):

```bash
npm install
npm run dev
```

Vite serves `examples/www/` on port **4444** (HTTPS by default when certs are found under `~/keys/$HOSTNAME/`; set `ENABLE_SSL=0` to disable). Example URLs: `https://127.0.0.1:4444/?example=haxe-wasm-simple`.

Useful variants:

```bash
make DEV=1 desktop
make DEV=1 wasm
make -C tests test_desktop
make -C tests test_wasm
make -C examples desktop    # all desktop examples
make -C examples wasm       # wasm examples (see Examples matrix — cppia wasm is npm-only today)
make clean
cd examples/nim-simple && nim clean
python3 tools/find_node_jspi.py   # Node with JSPI for wasm tests
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
- Stock Lua binding (desktop `require("rl")`):
  - `make rl_lua` -> `lib/rl.so` (links against `lib/librl.so`)
  - default lua headers path: `deps/liblua/include` (override with `LIBLUA_INC=/path/to/lua/include`)
  - sources: `bindings/lua/*.c`
- Lua in examples:
  - `examples/c-lua/` — statically links `deps/liblua` + `bindings/lua/*.c` into the host binary (desktop and wasm)
  - `examples/lua/` — stock Lua/LuaJIT loads `lib/rl.so` at runtime
- WASM note:
  - Desktop-style dynamic `rl.so` loading does not apply to wasm; use the `c-lua` wasm host instead.

### Examples Matrix

Aggregate from `examples/Makefile`:

| Example | Desktop | WASM | JS | Notes |
|---------|---------|------|-----|-------|
| `c-simple` | yes | yes | — | Minimal C host, no Lua VM |
| `c-lua` | yes | yes | — | Thin C host (static liblua + bindings); shared scripts under `examples/www/public/assets/scripts/lua/` |
| `lua` | yes | — | — | Stock desktop Lua via `boot.lua`; needs Vite/asset host on `:4444` for script fetch |
| `remote` | yes | yes | — | Isolated server/client experiment; not core API |
| `haxe-simple` | — | yes | yes | Source in `examples/haxe-simple/src/`; reloadable JS artifact at `public/assets/scripts/haxe/main.js` |
| `nim-simple` | yes | yes | yes | Source in `examples/nim-simple/src/`; reloadable JS artifact at `public/assets/scripts/nim/main.js` (`nim build script`) |
| `cppia` | yes | npm | — | Scriptable Haxe host; wasm via `npm run build:cppia:wasm` (included in deploy, not `make -C examples wasm`) |

Web testbed: `examples/www/index.html` with `?example=<key>`. Registry: `examples/www/public/js/example_catalog.js`; launcher: `run_example.js` → `example_runner.js` → `runtime_host.js`.

Registry keys: `remote`, `js`, `c-lua`, `c-simple`, `nim-wasm-simple`, `nim-js-simple`, `haxe-wasm-simple`, `haxe-js-simple`, `cppia`.

Reloadable JS examples (`nim-js-simple`, `haxe-js-simple`):

- Module paths: `assets/scripts/nim/main.js` (nim: `npm run build:nim-simple:js`); `assets/scripts/haxe/main.js` (haxe: `npm run build:haxe-simple:js`).
- `runtime_host.js` connects to `script_watcher` when the catalog entry defines `watchedPaths` (same `{ dir, ext, recursive? }` objects as the watcher's `watch` message). Any matching `file_changed` triggers reload of the catalog **`module`** (`_rt_unload` → re-import via `example_runner.instantiateRuntimeModule` → `_rt_boot` → `_rt_load(stash)`; Emscripten modules need factory reinstantiation, plain ESM modules do not). Cppia forwards `_rt_load`/`_rt_unload` to the script internally. Optional `&watcher=wss://127.0.0.1:9001/ws`. When the page is served from script_watcher on port 9001, the default watcher URL is same-origin `/ws`; Vite on 4444 still targets `:9001`.
- Watch protocol: `{ dir, ext, recursive? }` — directory relative to `public/` (e.g. `assets/scripts/haxe`), extension filter. Host filters `file_changed` by full file path.
- Runtime ABI: `_rt_boot` / `_rt_init` / `_rt_load` / `_rt_tick` / `_rt_unload` / `_rt_shutdown`. Author hooks: `onLoad` / `onUnload` on `Script` (Haxe) or `onLoad` / `onUnload` procs (Nim) — default no-ops when not reloadable.

## Nested Repo Note (`deps/libraylib`)

- `deps/libraylib` is its own git repo.
- Main repo commits do not include nested repo history changes.
- If `git status` in the main repo shows `deps/libraylib` changed, that means nested repo HEAD/working tree differs from the commit currently referenced by the parent checkout.
- Handle nested repo updates explicitly in that repo.

## Logging and Output Notes

- Raylib logs are rerouted centrally in `src/rl_logger.c` via `rl_logger_init()` (called from `rl_init()`).
- `SetTraceLogCallback(rl_logger_reroute_raylib_log)` maps raylib levels into wgutils logger levels and emits via:
  - `log_message(level, "raylib", 0, "%s", msg);`
- App/bindings code should use the public logger API (`rl_logger_message`, `rl_logger_message_source`, `rl_logger_set_level`) rather than wiring raylib callbacks in examples.
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
  - `rl_asset_ensure`
  - `rl_fs_init`
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
- Binding implementation files use the `rl_lua_*` prefix (e.g. `bindings/lua/rl_lua_model.c`); there is no separate embedded Lua VM module tree anymore.
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

- `rl_music` and `rl_sound` subsystems are available in C/JS/Nim/Haxe/Lua bindings.
- Examples commonly use:
  - background music: `assets/music/ethernight_club.mp3` (Haxe/cppia also reference `dancing_on_the_edge.mp3`)
  - click SFX: `assets/sounds/click_004.ogg`
- Cleanup order in native examples is explicit: destroy handles, then `rl_deinit()`, then `CloseWindow()` where applicable.

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

Regenerate the full comparison tables with:

```bash
make wasm
make -C examples wasm js cppia
npm run build:cppia:script
python3 tools/measure_web_sizes.py
```

Output: [`docs/WEB_SIZES.md`](WEB_SIZES.md) — web offerings, per-file breakdowns, JS app-layer sizes, desktop reference, gzip/brotli columns.

Approximate ballpark (release/optimized, no debug symbols; see generated doc for current numbers):

| Build | Desktop | WASM |
|-------|---------|------|
| C (no Lua VM) | ~2.8 MB | ~0.58 MB |
| Nim example | ~2.1 MB | ~0.59 MB |
| Haxe example | ~3.6 MB | ~1.8 MB |
| Haxe cppia host | ~13 MB | ~2 MB+ (built; larger than plain Haxe wasm) |

- C without Lua: use `examples/c-simple` (`make -C examples/c-simple desktop` / `wasm`).
- C and Nim WASM are comparable (~0.58–0.59 MB); Haxe WASM is ~3× larger for similar example scope.
- Haxe cppia adds ~3.5× over the plain Haxe host on desktop; wasm cppia is built for the testbed but is not a tight-size target.

## Web/Vite Workflow Notes

### Dev server (`npm run dev`)

Runs in parallel (see root `package.json`):

- `vite` — dev helper on port **4444** (`vite-plugin-restart` when wasm **host** artifacts change; `vite build` for deploy). Serves the testbed shell; proxies `/examples`, `/bindings`, and `/lib` to **script_watcher** (must be running — see `examples/script_watcher/.env`). Or browse **script_watcher** directly on **9001**.
- `onchange` watchers — rebuild C/Nim/Haxe/cppia wasm or js outputs when sources change
- `examples/script_watcher` — Bun server (default port **9001**, TLS via `RL_REMOTE_ENABLE_TLS=1` and `KEYS_DIR` in `examples/script_watcher/.env`; copy from `.env.example`): WebSocket at `/ws` for file-watch notifications, static HTTP(S) on the same port for the testbed shell (`RL_REMOTE_HTTP_ROOT`, default `examples/www/`), public assets (`RL_REMOTE_PUBLIC_ROOT`), and optional path mounts (`RL_REMOTE_HTTP_MOUNTS`, semicolon-separated `/prefix=path` entries — see `.env.example` for the librl testbed). Server listen env: `RL_REMOTE_ENABLE_TLS`, `RL_REMOTE_HOST`, `RL_REMOTE_PORT` (the `examples/remote` client still uses `RL_REMOTE_WS_*` for its WebSocket URL only).

Cppia host (`examples/cppia/src/ScriptableMain.hx`) loads `assets/scripts/cppia/MainScript.cppia`. With `ENABLE_SCRIPT_WATCHER` (desktop + wasm builds), the host connects an internal script_watcher WebSocket and reloads `.cppia` in-process (`onUnload` → fetch → `onLoad`); the catalog entry does not use `runtime_host` `watchedPaths`. Recompile gameplay with `npm run build:cppia:script` (or `watch:cppia:script`). Adjust `ASSET_HOST` / `SCRIPT_WATCHER_URL` for your LAN.

`npm install` runs `tools/generate_devtools_workspace.py` (Chrome DevTools workspace mapping).

### Runtime resolution and recovery

- Web examples resolve `bindings/js/dist/rl.js` relative to `document.baseURI` (works under subpath deploys like `/testbed/librl/`). Override via `bindingsPath` in boot config if needed. The wrapper instantiates the raw `lib/librl.js` runtime.
- If `make clean` removes generated outputs while Vite is running, browser requests can fail until rebuild completes.
- Vite may not always recover automatically from a missing generated entry file (`main.js`/bundled artifacts) without a new file-change trigger.
- Practical flow:
  1. Rebuild wasm/js outputs (`make wasm`, `npm run build:*`, or let `npm run dev` watchers rebuild).
  2. Touch or re-save relevant entry file if HMR does not recover (`vite-plugin-restart` handles many `out/` wasm artifacts).
  3. **Reloadable JS** (`haxe-js-simple`, `nim-js-simple`): bundles under `assets/scripts/{haxe,nim}/` are ignored by Vite; `runtime_host.js` swaps modules in-page via `script_watcher`.

### Tests and deploy

- **Manual wasm smoke (optional):** with Vite running on port 4444, `node tests/smoke/haxe_wasm_smoke.mjs` loads the Haxe wasm example in headless Chromium and prints console/page errors. Not wired into `make test` yet. See `tests/README.md`.
- **Testbed deploy:** `npm run deploy` runs `build:all:release` then rsyncs `examples/www/dist/` to the remote testbed host.
  - `build:librl:release` — `make wasm` + `npm run build:js-binding` (`lib/` + `bindings/js/dist/`)
  - `build:librl` — debug build (`make DEV=1 wasm` + JS binding)
  - `build:examples:release` — all listed www examples (wasm + js targets, including cppia host + script)
  - `vite build` — static shell from `examples/www/`
  - `npm run stage:www:dist` — copies built example artifacts into `examples/www/dist/`

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
- Host calls script tick/update once per frame (`rt_tick`, cppia `onTick`, or direct `RL.tick()` in compiled examples).
- Script calls `rl_*` directly (via bindings) for draw, audio, and resource work — immediate-mode; **no frame-command buffer in core librl** (see `docs/BINDINGS.md`).
- Current status:
  - `examples/c-lua/` — thin C host; pumps `runtime_wrapper` (`rt_boot` / `rt_init` / `rt_tick` / `rt_shutdown`)
  - `examples/lua/` — stock desktop Lua host via `boot.lua`; same shared scripts as c-lua/web
  - `examples/cppia/` — Haxe scriptable host; loads `assets/scripts/cppia/MainScript.cppia`; script watcher for hot reload
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

- In the ideal workflow, a thin native or wasm host runs once while gameplay is authored in plain-text scripts with a basic editor.
- Current script layers share these needs:
  - init/tick/shutdown lifecycle (or equivalent)
  - `rl.init({...})` (Lua/Haxe) or host-side init (C) for window and asset host
  - input access via bindings
  - resource creation returning handles
  - handle-based draw/audio via direct bindings
  - predictable hot reload (cppia script watcher today; Lua HCR sketched in `lua_demo.lua` only)
  - good source-aware logging/errors

## Current Lua Runtime Shape

Shared gameplay scripts live under `examples/www/public/assets/scripts/lua/`. Hosts differ only in how they bootstrap Lua and pump the frame loop.

### Runtime wrapper contract

`runtime_wrapper.lua` is the stable host↔script boundary:

| Host calls | Lua module provides |
|------------|---------------------|
| `rt_boot(module_name?)` | loads app module (default `main`); validates callbacks |
| `rt_init(host_context?)` | forwards to app `on_init()` |
| `rt_tick(delta_time)` | forwards to app `on_tick(delta_time)` |
| `rt_shutdown()` | forwards to app `on_shutdown()` |

App modules (e.g. `main.lua`) return a table with required callbacks:

- `on_init()` — calls `rl.init({ window_width, window_height, window_title, window_flags, asset_host, ... })`, sets up scene
- `on_tick(delta_time)` — input, update, draw; returns `ResultCode` (`OK`, `ERROR`, `QUIT`)
- `on_shutdown()` — destroy handles, `rl.deinit()`

Window/config is owned by the script via `rl.init(...)`, not by a separate `get_config()` host hook.

### Host flows

**`examples/c-lua/` (desktop + wasm thin C host)**

1. C host creates Lua VM and temporary `rl_fs_init` to fetch `runtime_wrapper.lua` from the asset host
2. C caches `rt_*` refs and calls `rt_boot("main")` (module name from `LUA_RUNTIME_MODULE`)
3. C calls `rl_fs_deinit()` so the script owns full librl lifecycle via `rl.init` / `rl.deinit`
4. C pumps `rt_init` → loop `rt_tick(dt)` → `rt_shutdown`

**`examples/lua/` (stock desktop Lua)**

1. `boot.lua` prepends `libs/` to `package.cpath`, `require("rl")`, `rl.fs_init()` + `rl.asset_set_host("https://localhost:4444")`
2. Adds `assets/scripts/lua` to `package.path`, `require("assets/scripts/lua/runtime_wrapper")`
3. Simulates the same `rt_*` pump as the C host (see `examples/lua/README.md`)

Run: `make -C examples/lua run` (builds `rl.so` + `librl.so`, copies into `examples/lua/libs/`). **Requires Vite** (or another asset server) on `:4444` so scripts and assets resolve.

**Wasm c-lua** uses the same script tree; assets load through the configured `asset_host`.

### HCR / reload (experimental)

- `lua_demo.lua` sketches optional `serialize` / `unserialize` / `load` / `unload` hooks for hot code reload.
- Standard `runtime_wrapper` + `main.lua` do **not** wire HCR yet; see [ROADMAP.md](ROADMAP.md) for follow-up.

### Lua scripts

Gameplay scripts call the flat `rl.*` binding API directly (see `main.lua`). `runtime_wrapper.lua` is the only shared lifecycle shim. Other files under `examples/www/public/assets/scripts/lua/` (e.g. `lua_demo.lua` and its helper requires) are experiments — not part of the default runtime path.

## Assets and Credits

- Credits file is at `examples/www/public/assets/CREDITS.md`.
- Current credits include:
  - Kevin MacLeod track attribution (CC BY 3.0)
  - `click_004.ogg` attribution to Kenney (CC0/public domain)

## Common Gotchas

- Seeing `GLSL ES 1.00` at startup means you are effectively on WebGL1 path.
- Seeing NPOT warning (`limited NPOT support`) usually indicates WebGL1 constraints or non-mipmap/non-repeat constraints for NPOT textures.
- Duplicate/buried wasm flags can happen between root, examples, tests, and deps makefiles; prefer a single shared variable per makefile where possible.
- **Tests:** root `make test` delegates to `tests/Makefile` (same as `make -C tests test`). Wasm tests require Node **≥25 with JSPI**; Makefiles resolve via `python3 tools/find_node_jspi.py` when `NODE` is unset or lacks JSPI.
- **Web dev:** example `asset_host` / script-watcher URLs are often LAN-specific; mismatch with your Vite host causes fetch/reload failures.
- Binding changes should be reflected in all four bindings plus:
  - `bindings/js/dist/rl.js` and `bindings/js/dist/rl.d.ts` (via `make binding-types`, not by hand)
  - `bindings/nim/rl.nim`, `bindings/haxe/rl/`, `bindings/lua/`
  - `docs/API.md`
- After C API or binding surface changes, run `python3 tools/audit_binding_parity.py` and update `docs/ROADMAP.md` gap table if needed. See also [AGENTS.md](../AGENTS.md) for the full agent contract.

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
| `tools/measure_web_sizes.py` | — | Measure example web/desktop artifact sizes (raw/gzip/brotli); writes `docs/WEB_SIZES.md`. |

**Agent workflow:** see [AGENTS.md](../AGENTS.md). Short form: C header change → update `docs/API.md` + all four bindings → `make binding-types` (if JS changed) → `python3 tools/audit_binding_parity.py` → fix gaps or document intentional omissions in `docs/BINDINGS.md`.

One-off migration scripts (`migrate_fileio_to_fs_asset.py`, `rename_fileio_public_api.py`) are historical; do not run unless explicitly reviving a migration.

Other dev scripts (not binding parity): `show_wasm_sources.py`, `generate_devtools_workspace.py`.

