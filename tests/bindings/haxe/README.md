# Haxe Binding Tests

Tests for the librl Haxe extern bindings (`bindings/haxe/rl/RL.hx`).

## Requirements

- Haxe 4.x with hxcpp
- utest: `haxelib install utest`
- librl desktop build (run `make desktop` from project root first, or the test Makefile does this)

## Run

From this directory:

```bash
make test
```

Or from the project root:

```bash
make -C tests test_haxe_bindings
```

## Test Coverage

- **testConstants**: Window flag constants (FLAG_WINDOW_RESIZABLE, etc.)
- **testInitDeinit**: rl_init / rl_deinit lifecycle
- **testTimeFunctions**: getTime, getDeltaTime, setTargetFps
- **testAssetHost**: setAssetHost, getAssetHost
- **testLighting**: enableLighting, disableLighting, isLightingEnabled, setLightDirection, setLightAmbient
- **testWindowGetScreenSize**: windowGetScreenSize (vec2_t return)
- **testWindowGetMonitorCount**: windowGetMonitorCount
