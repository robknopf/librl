# Tests

Test orchestration for this project lives in `tests/Makefile`.

## Prerequisites

- `make`
- Desktop C toolchain (`gcc`)
- Emscripten (`emcc`) for wasm tests
- Node.js for wasm unit tests
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
- `unit_test_wasm`: runs librl wasm unit tests under Node.
- `probe_idbfs_build`: builds headless IDBFS probe wasm/js.
- `probe_idbfs`: executes headless browser IDBFS persistence probe.
