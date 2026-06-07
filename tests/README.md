# Tests

Test orchestration for this project lives in `tests/Makefile`.

## Prerequisites

- `make`
- Desktop C toolchain (`gcc`)
- Emscripten (`emcc`) for wasm tests
- Node.js **≥25 with JSPI** (`WebAssembly.Suspending`) for wasm unit tests and `tests/bindings/js`
- Chrome/Chromium for headless IDBFS probe
- Python `websocket-client` module (`import websocket`)

## Common Commands

Run full suite from repo root:

```bash
make test
```

Run full suite directly from `tests/`:

```bash
make -C tests test
```

Run desktop-only suite:

```bash
make -C tests test_desktop
```

Run wasm-only suite:

```bash
make -C tests test_wasm
```

## Individual Targets

- `unit_test_desktop`: runs librl desktop unit tests.
- `shape_pick_regression_desktop`: retained-shape scaled-pick regression against the real desktop archive.
- `unit_test_wasm`: runs librl wasm unit tests under Node.
- `tests/bindings/js`: boot/namespace/init smoke + version stamp tests (`make -C tests/bindings/js test`).
- `probe_idbfs_build`: builds headless IDBFS probe wasm/js.
- `probe_idbfs`: executes headless browser IDBFS persistence probe.

## Manual smoke tests (`tests/smoke/`)

Optional, not part of `make test` yet:

- `tests/smoke/haxe_wasm_smoke.mjs` — Puppeteer load of the Haxe wasm web example via Vite (`https://127.0.0.1:4444/?example=haxe` by default). Start Vite first; then:

```bash
node tests/smoke/haxe_wasm_smoke.mjs
```

Env: `SMOKE_URL`, `CHROMIUM`, `SMOKE_SETTLE_MS`. Requires `puppeteer-core`.
