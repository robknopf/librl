# JavaScript binding

High-level `rl` module for browser/wasm hosts. Loads the raw Emscripten runtime from `lib/librl.js` and exposes the ergonomic binding API (`rl.init`, `rl.window`, `rl.fs`, …).

## Layout

```
bindings/js/
  src/
    rl.ts          Implementation — Emscripten calls, boot, namespaces
    types.ts       Public API contract — interfaces for rl.d.ts
    emscripten.ts  Internal Emscripten module types
    scratch.ts     Internal scratch-buffer layout types
  gen/
    rl_version.ts  Generated version stamp (`make binding-version`)
  dist/
    rl.js          Bundled runtime (gitignored; esbuild output)
    rl.d.ts        Generated declarations (tracked; pairs with rl.js)
  tsconfig.json       Typecheck all sources (`noEmit`)
  tsconfig.decl.json  Emit declarations from types.ts only
  finalize-rl-dts.mjs Rename tsc output types.d.ts → rl.d.ts
  package.json        npm scripts + local devDependencies
```

## Runtime vs types (don't mix these up)

| Artifact | What it is |
|----------|------------|
| `lib/librl.js` + `lib/librl.wasm` | **Emscripten output** — raw wasm module, `ccall`/`cwrap` to C |
| `dist/rl.js` | **JS binding** — imports `lib/librl.js`, exports the `rl` object |
| `dist/rl.d.ts` | **Types for the binding** — describes `rl`, not the Emscripten module |

Import the binding, not the wasm loader:

```js
import { rl } from "/bindings/js/dist/rl.js";
await rl.boot({ modulePath: "/lib/librl.js" });
```

## Build

From repo root:

```bash
make binding-types    # binding-version + npm run build --prefix bindings/js
```

From this directory:

```bash
npm install           # esbuild + typescript (or use hoisted root node_modules)
npm run build         # check + bundle + types
```

| Script | What it does |
|--------|--------------|
| `npm run check` | `tsc --noEmit` — strict typecheck of all `src/` + `gen/` |
| `npm run bundle` | esbuild `src/rl.ts` → `dist/rl.js` (single file, inlines `gen/rl_version.ts`) |
| `npm run bundle:min` | Same with `--minify` |
| `npm run types` | `tsc` on `src/types.ts` only → `dist/rl.d.ts` |
| `npm run build` | All three |

### Why two tsconfigs?

- **`tsconfig.json`** — check the full implementation (`rl.ts` is ~1800 lines). No emit; esbuild produces JS.
- **`tsconfig.decl.json`** — emit `.d.ts` from **`types.ts` only**. The public surface is intentionally separate from implementation internals.

esbuild bundles JS but cannot emit declarations; tsc handles `.d.ts`.

### Why finalize-rl-dts.mjs?

tsc names output after the source file (`types.ts` → `types.d.ts`). The script renames to `rl.d.ts` so declarations sit beside `rl.js`.

## Maintainers

When changing binding methods or signatures:

1. Edit `src/rl.ts` (implementation).
2. Update `src/types.ts` when the public signature changes.
3. Run `make binding-types` (or `make wasm` / `make desktop`).
4. Commit regenerated `dist/rl.d.ts` when API shape changed (`dist/rl.js` is gitignored).

`src/rl.ts` uses `satisfies RLApi` (and per-namespace `satisfies`) to keep implementation aligned with `types.ts`.

Version stamps: `make binding-version` writes `gen/rl_version.ts` from `include/rl_version.h`.
