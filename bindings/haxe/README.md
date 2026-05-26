# Haxe bindings (source)

Haxe façade over the librl C API. Maintained in this directory; consumed by in-repo examples/tests and by the separate [librl-hx](https://github.com/robknopf/librl-hx) haxelib (which vendors this tree as a submodule).

For installing and using librl from Haxe, see the **librl-hx** README — not this file.

## Layout

```
bindings/haxe/
├── rl/
│   ├── RL.hx              # lifecycle, timing, shared constants
│   ├── Types.hx           # RLHandle, config structs, input/pick types
│   ├── Fs.hx, Asset.hx, Window.hx, Render.hx, …  # one class per C section
│   ├── helpers/           # TaskGroup, Wait, Log (not C API)
│   └── impl/
│       ├── RLImpl.hx      # unsupported-target stub
│       ├── RLImpl.cpp.hx  # hxcpp backend
│       └── RLImpl.js.hx   # JS backend
└── README.md
```

Public API uses native Haxe types. C FFI stays inside `impl/`.

## Backends

| Target | Implementation |
|--------|----------------|
| Desktop | `RLImpl.cpp.hx` — hxcpp externs to the C API |
| Wasm (in-repo examples) | Same cpp backend; links pre-built `lib/librl.wasm.a` |
| JS | `RLImpl.js.hx` — thin adapter over `bindings/js/dist/rl.js` |

## In this repo

Examples and tests add these sources directly and link a **pre-built** librl:

```hxml
-cp ../../bindings/haxe
-D LIBRL_ROOT=../../../..
-lib hxasync
-lib hxcpp
```

Run `make desktop` / `make wasm` first. In-repo `rl/InjectLibRL.hx` uses `LIBRL_ROOT` to find headers and `lib/librl.a` / `lib/librl.wasm.a`.

The **librl-hx** haxelib vendors this tree as a submodule. Stock `InjectLibRL.hx` uses `if="librl_hx"` / `unless="librl_hx"` in its buildXml to include `project/Build.xml` when `-lib librl-hx` is used; in-repo builds use `-D LIBRL_ROOT=...` instead.

Canonical example: `examples/haxe-simple/`. Binding tests: `tests/bindings/haxe/`.

## Maintainers

- Regenerate section façades: `python3 tools/gen_haxe_public_sections.py`
- After C API changes: update bindings, `docs/API.md`, run `python3 tools/audit_binding_parity.py`
- Version stamps: `make binding-version`

Details: `docs/BINDINGS.md` (Haxe section), `docs/MAINTAINER.md`.
