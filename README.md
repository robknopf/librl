# librl

`librl` is a small C wrapper layer around raylib, with build targets for:

- Desktop static library (`.a`)
- WebAssembly module (`lib/librl.js` + `lib/librl.wasm`)
- WebAssembly static archive (`.wasm.a`)

## Purpose

`librl` was created to be a wrapper for RayLib to help accelerate my prototype development efforts.  It is a binding-oriented runtime layer that provides stable handles, cross-platform asset loading, and shared-state plumbing for non-C hosts (currently JS/Nim/Haxe).  Note that it is not complete and very much a work in progress.

Key goals:

- Handle-based APIs for resources:
  - Colors, fonts, and models are exposed as `rl_handle_t` IDs instead of raw raylib structs.
  - This keeps bindings simpler and safer by avoiding direct pointer/struct lifetime management in host languages.
- Cached asset systems:
  - Loader and resource subsystems are designed for reuse/caching instead of one-shot loads.
  - Model/font/color systems keep runtime-owned instances keyed by handles.
- Cross-platform file I/O abstraction:
  - Unified loading path across desktop and web builds.
  - Web can fetch/store assets in browser-backed storage (IndexedDB).
  - Desktop can read/write local files through the same higher-level loader path.
- LRU-backed loader behavior:
  - `rl_loader` uses LRU cache infrastructure to reduce repeated decode/fetch work.
  - This is especially useful for wasm/browser workflows where fetch/decode churn can be costly.

## Repository Layout

- `src/` implementation
- `include/` public headers
- `bindings/` JS/Nim binding helpers
- `test/` desktop and web test harnesses

## Prerequisites

- `make`
- Desktop C toolchain (`gcc`, `ar`)
- Emscripten SDK on `PATH` (`emcc`, `emar`) for wasm builds
- Access to raylib-builder repo: `git@github.com:robknopf/raylib-builder.git`

## Build

Build raylib dependency first:

```bash
make deps
```

Build desktop static library:

```bash
make desktop
```

Build wasm JS module:

```bash
make wasm
```

Build wasm static archive:

```bash
make wasm_archive
```

Build all targets:

```bash
make
```

Debug mode:

```bash
make DEV=1 desktop
make DEV=1 wasm
```

Clean outputs:

```bash
make clean
```

## Build Outputs

- Desktop archive: `lib/librl.a` (or `lib/librl_d.a` with `DEV=1`)
- Wasm JS loader: `lib/librl.js`
- Wasm archive: `lib/librl.wasm.a` (or `lib/librl_d.wasm.a` with `DEV=1`)

## Notes

- `rl_model_create()` requires a ready window/graphics context. If model loading fails, it substitutes a visible placeholder cube.
- `deps/`, `obj/`, `lib/`, and `.vscode/` are ignored by git via `.gitignore`.
- API surface documentation: see [API.md](docs/API.md).
- Binding documentation: see [BINDINGS.md](docs/BINDINGS.md).

## TODO

- So, so many things.  See the TODO document for the list of things I'm playing around with.

## License

See [LICENSE](LICENSE).
