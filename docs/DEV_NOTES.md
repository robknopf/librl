# Development Notes

Internal maintainer notes for quick session handoff. Keep this practical and current.

## Fast Start

From repo root:

```bash
make deps
make desktop
make wasm
make -C examples/c desktop
make test
```

Useful variants:

```bash
make DEV=1 desktop
make DEV=1 wasm
make -C tests test_desktop
make -C tests test_wasm
make clean
cd examples/nim && nim clean
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

## Nested Repo Note (`deps/libraylib`)

- `deps/libraylib` is its own git repo.
- Main repo commits do not include nested repo history changes.
- If `git status` in the main repo shows `deps/libraylib` changed, that means nested repo HEAD/working tree differs from the commit currently referenced by the parent checkout.
- Handle nested repo updates explicitly in that repo.

## Logging and Output Notes

- raylib logs are rerouted via `SetTraceLogCallback(...)` in `examples/c/main.c`.
- We map raylib levels into wgutils logger levels and currently emit via:
  - `log_message(level, "raylib", 0, "%s", msg);`
- `log_message` supports optional source metadata:
  - file present + line > 0: emits file and line
  - file present + line <= 0: emits file only
  - file null: emits no source suffix
- Keep redirected raylib logs source-light unless source info is reliable.

## Audio API State

- `rl_music` and `rl_sound` subsystems are available in C/JS/Nim bindings.
- C example currently uses:
  - background music stream: `assets/music/ethernight_club.mp3`
  - click SFX on left mouse press: `assets/sounds/click_004.ogg`
- Cleanup order in example is explicit: destroy handles, then `rl_deinit()`, then `CloseWindow()`.

## Web/Vite Workflow Notes

- Web examples import from `/lib/librl.js`; if `make clean` removes generated outputs while Vite is running, browser requests can fail until rebuild completes.
- Vite may not always recover automatically from a missing generated entry file (`main.js`/bundled artifacts) without a new file-change trigger.
- Practical flow:
  1. Rebuild wasm/js outputs (`make wasm` or target-specific make).
  2. Touch or re-save relevant entry file if HMR does not recover.
  3. Restart Vite only if file watching still does not pick up rebuilt outputs.

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
  - `bindings/js/rl.js`
  - `bindings/nim/rl.nim`
  - `docs/API.md`
