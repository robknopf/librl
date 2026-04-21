# Lua Example

This example loads `rl.so` from a local `libs/` folder.

## Run

```bash
make -C examples/lua run
```

What this does:

- builds `lib/librl.so` and `lib/rl.so` via `make rl_lua`
- copies `rl.so` and `librl.so` into `examples/lua/libs/`
- runs `boot.lua` which sets up the cpaths, then requires `main.lua`

`boot.lua` computes its own directory using `debug.getinfo(...)` and prepends `./libs` to `package.cpath` before calling `require("main")`.

