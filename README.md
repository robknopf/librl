# librl

Handle-based **C library** around [raylib](https://www.raylib.com/), with desktop/wasm builds and bindings for **JS, Haxe, Nim, and Lua**.

Work in progress — [roadmap](docs/ROADMAP.md).

## Quick start

```bash
make deps
make desktop   # lib/librl.a
make wasm      # lib/librl.js + lib/librl.wasm
make test
```

Example: `make -C examples/c-lua desktop && make -C examples/c-lua run`

Debug: `make DEV=1 desktop` / `make DEV=1 wasm`

## Docs

Start at **[docs/README.md](docs/README.md)** — API, bindings, maintainer handbook, roadmap.

## License

[LICENSE](LICENSE)
